//
//  LiveChecker.swift
//  TexLab
//

import Foundation

/// A problem found while typing, before typesetting.
nonisolated struct LiveIssue: Hashable, Sendable {
    var severity: LogEntry.Severity
    var message: String
    /// 1-based.
    var line: Int
}

/// What the live checks need to know about the rest of the project.
nonisolated struct LiveCheckContext: Sendable {
    /// Whether every label the document can refer to is known: the project has been
    /// scanned, or the document is untitled and on its own.
    var knowsAllLabels = false
    /// Labels defined in the project's other files.
    var otherLabels: Set<String> = []
    /// Keys of the entries in the project's bibliographies.
    var bibliographyKeys: Set<String> = []
    /// The project's bibliography files, as canonical paths.
    var bibliographyFiles: Set<String> = []
    /// The folder `\bibliography` paths are relative to: the main file's folder.
    var folder: URL?
    /// Verbatim environments the project's other files and packages define, such as one
    /// made with `\lstnewenvironment`.
    var verbatimEnvironments: Set<String> = []
}

/// Finds the problems TeX would stop or warn at, while you type — like Xcode's live
/// issues. Each check is careful to stay quiet when it can't be sure:
///
/// - Environments that aren't closed, are closed twice or are closed in the wrong order.
///   Only environments at the top level count, so `\newenvironment{name}{\begin{center}}
///   {\end{center}}` and other definitions don't look unbalanced.
/// - Braces without a partner. `\{`, comments, `\verb`, `\url` and verbatim environments are
///   read the way TeX reads them.
/// - References to labels nothing defines, once the whole project is known; documents that
///   use `xr` to refer to other documents are left alone.
/// - Citations missing from the bibliography, when every bibliography the document uses
///   is in the project (a database installed with TeX can't be checked).
/// - Labels defined more than once in the file.
nonisolated enum LiveChecker {
    static let maximumIssues = 100

    static func check(_ text: String, context: LiveCheckContext) -> [LiveIssue] {
        var scan = LiveScan(units: Array(text.utf16))
        scan.verbatimEnvironments.formUnion(verbatimEnvironmentDefinitions(in: text))
        scan.verbatimEnvironments.formUnion(context.verbatimEnvironments)
        scan.run()
        var issues = scan.issues

        // Labels defined twice.
        var labelLines: [String: Int] = [:]
        for label in scan.labels {
            if let first = labelLines[label.key] {
                issues.append(LiveIssue(
                    severity: .warning,
                    message: String(localized: "The label ‘\(label.key)’ is also defined on line \(first)"),
                    line: label.line
                ))
            } else {
                // Only within the file: a folder can hold several documents that each use
                // the same labels, and the project doesn't know which files belong together.
                labelLines[label.key] = label.line
            }
        }

        // References to labels nothing defines.
        if context.knowsAllLabels && !scan.usesExternalDocuments {
            for reference in scan.references where labelLines[reference.key] == nil && !context.otherLabels.contains(reference.key) {
                issues.append(LiveIssue(
                    severity: .warning,
                    message: String(localized: "No \\label{\(reference.key)} for this reference"),
                    line: reference.line
                ))
            }
        }

        // Citations missing from the bibliography.
        if let keys = knownCitationKeys(scan: scan, context: context) {
            for citation in scan.citations where !keys.contains(citation.key) {
                issues.append(LiveIssue(
                    severity: .warning,
                    message: String(localized: "No bibliography entry for ‘\(citation.key)’"),
                    line: citation.line
                ))
            }
        }

        let sorted = issues.sorted { lhs, rhs in
            lhs.line != rhs.line ? lhs.line < rhs.line : lhs.message < rhs.message
        }
        return Array(sorted.prefix(maximumIssues))
    }

    private static let verbatimDefinitionPattern = try! NSRegularExpression(
        pattern: #"\\(?:lstnewenvironment|DefineVerbatimEnvironment|specialcomment|excludecomment|includecomment|newtcblisting|DeclareTCBListing|NewTCBListing|RenewTCBListing|ProvideTCBListing|newtcbinputlisting)\*?\s*\{([^{}]+)\}"#
    )
    private static let mintedDefinitionPattern = try! NSRegularExpression(pattern: #"\\newminted\s*(?:\[([^\]]*)\])?\s*\{([^{}]+)\}"#)
    private static let verbatimWrapperPattern = try! NSRegularExpression(
        pattern: #"\\(?:re)?newenvironment\*?\s*\{([^{}]+)\}[^\n]*?\{\s*\\(?:verbatim|Verbatim|comment)\b"#
    )

    /// Environments `text` defines whose contents TeX reads as they are: listings,
    /// verbatim variants and comments.
    static func verbatimEnvironmentDefinitions(in text: String) -> Set<String> {
        let string = text as NSString
        let whole = NSRange(location: 0, length: string.length)
        var names: Set<String> = []
        for match in verbatimDefinitionPattern.matches(in: text, range: whole) {
            names.insert(string.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces))
        }
        for match in mintedDefinitionPattern.matches(in: text, range: whole) {
            // \newminted{python}{…} defines pythoncode, unless it names the environment.
            if match.range(at: 1).location != NSNotFound {
                names.insert(string.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces))
            } else {
                names.insert(string.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces) + "code")
            }
        }
        for match in verbatimWrapperPattern.matches(in: text, range: whole) {
            names.insert(string.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces))
        }
        return names
    }

    /// Every key the document can cite, or nil if some could come from somewhere TexLab
    /// can't see.
    private static func knownCitationKeys(scan: LiveScan, context: LiveCheckContext) -> Set<String>? {
        if scan.bibliographies.isEmpty {
            // Without a bibliography of its own, a document cites what the project has,
            // through its main file.
            guard !scan.bibItems.isEmpty || !context.bibliographyKeys.isEmpty else { return nil }
        } else {
            guard let folder = context.folder else { return nil }
            for resource in scan.bibliographies {
                let path = resource.lowercased().hasSuffix(".bib") ? resource : resource + ".bib"
                let url = path.hasPrefix("/") ? URL(filePath: path) : folder.appending(path: path)
                guard context.bibliographyFiles.contains(SourceMap.canonicalPath(url)) else { return nil }
            }
        }
        return scan.bibItems.union(context.bibliographyKeys)
    }
}

/// One pass over the text, the way TeX reads it: comments, control sequences, braces and
/// environments, collecting what the checks need.
private nonisolated struct LiveScan {
    let units: [UInt16]
    var index = 0
    var line = 1
    /// How many braces are open.
    var depth = 0
    /// The lines of the braces that are open.
    var openBraces: [Int] = []
    /// Environments begun and not yet ended, with the brace depth and the number of open
    /// conditionals they were begun at.
    var environments: [(name: String, depth: Int, conditional: Int, line: Int)] = []
    /// The brace depths of the `\if…` conditionals that are open.
    var conditionals: [Int] = []
    /// Whether the next control sequence is being defined, as in `\def\foo`, rather than
    /// used.
    var skipsNextControlSequence = false
    var issues: [LiveIssue] = []
    var labels: [(key: String, line: Int)] = []
    var references: [(key: String, line: Int)] = []
    var citations: [(key: String, line: Int)] = []
    var bibItems: Set<String> = []
    var bibliographies: [String] = []
    var usesExternalDocuments = false

    /// Environments whose contents TeX doesn't read as LaTeX.
    var verbatimEnvironments = LiveScan.standardVerbatimEnvironments

    static let standardVerbatimEnvironments: Set<String> = [
        "verbatim", "verbatim*", "Verbatim", "Verbatim*", "BVerbatim", "LVerbatim", "lstlisting",
        "minted", "comment", "filecontents", "filecontents*", "luacode", "luacode*", "pycode",
        "sageblock", "sagesilent", "sagecommandline", "pyconsole", "pythoncode",
    ]

    init(units: [UInt16]) {
        self.units = units
    }

    mutating func run() {
        while index < units.count {
            switch units[index] {
            case Char.newline:
                line += 1
                index += 1
            case Char.percent:
                skipToEndOfLine()
            case Char.openBrace:
                openBraces.append(line)
                depth += 1
                index += 1
            case Char.closeBrace:
                closeGroup()
                index += 1
            case Char.backslash:
                readControlSequence()
            default:
                index += 1
            }
        }
        finish()
    }

    private mutating func finish() {
        for braceLine in openBraces.prefix(3) {
            issues.append(LiveIssue(severity: .error, message: String(localized: "This { isn’t closed"), line: braceLine))
        }
        // An open brace makes everything after it look unclosed; report only the brace. A
        // conditional without its \fi (or a command that only looks like one) could hide
        // the \end, so stay quiet then too.
        guard openBraces.isEmpty, conditionals.isEmpty else { return }
        for environment in environments where environment.depth == 0 && environment.conditional == 0 {
            issues.append(LiveIssue(
                severity: .error,
                message: String(localized: "\\begin{\(environment.name)} isn’t closed"),
                line: environment.line
            ))
        }
    }

    private mutating func closeGroup() {
        guard depth > 0 else {
            issues.append(LiveIssue(severity: .error, message: String(localized: "This } has no matching {"), line: line))
            return
        }
        // Environments begun inside a group end with it, as in the arguments of
        // \newenvironment; they aren't the document's own.
        while let last = environments.last, last.depth == depth {
            environments.removeLast()
        }
        while let last = conditionals.last, last == depth {
            conditionals.removeLast()
        }
        depth -= 1
        openBraces.removeLast()
    }

    // MARK: - Control sequences

    private mutating func readControlSequence() {
        index += 1
        guard index < units.count else { return }
        guard Char.isCommandLetter(units[index]) else {
            // A control symbol such as \{, \} or \%. A backslash before a line break leaves
            // the line break for the main loop to count.
            if units[index] != Char.newline {
                index += 1
            }
            return
        }
        let start = index
        while index < units.count && Char.isCommandLetter(units[index]) {
            index += 1
        }
        let name = string(from: start, to: index)
        if skipsNextControlSequence {
            skipsNextControlSequence = false
            return
        }
        switch name {
        case "def", "gdef", "edef", "xdef", "let", "newif":
            // \newif\ifdraft defines a conditional; it doesn't start one.
            skipsNextControlSequence = true
        case "fi":
            // Environments begun inside a conditional are the conditional's, as with braces.
            if let last = conditionals.last, last == depth {
                let level = conditionals.count
                while let environment = environments.last, environment.conditional == level {
                    environments.removeLast()
                }
                conditionals.removeLast()
            }
        case let conditional where Self.isConditional(conditional) && !isFollowedByBrace:
            conditionals.append(depth)
        case "verb":
            if index < units.count && units[index] == Char.star {
                index += 1
            }
            skipDelimited()
        case "begin":
            readBegin()
        case "end":
            readEnd()
        case "label":
            skipOverlay()
            if let key = readArgument()?.trimmingCharacters(in: .whitespaces), Self.isPlainKey(key) {
                labels.append((key, line))
            }
        case "url", "path", "href":
            // The address is read as it is: % and # in it aren't special.
            skipRawGroup()
        case "lstinline":
            skipOptional()
            skipInlineCode()
        case "mintinline":
            skipOptional()
            skipRawGroup()
            skipInlineCode()
        case "iffalse":
            // Text left out with \iffalse … \fi, unless it's an argument: {\iffalse}.
            if index >= units.count || units[index] != Char.closeBrace {
                skipToFi()
            }
        case "bibitem":
            skipOptional()
            if let key = readArgument()?.trimmingCharacters(in: .whitespaces), !key.isEmpty {
                bibItems.insert(key)
            }
        case "bibliography", "addbibresource", "addglobalbib":
            skipOptional()
            if let list = readArgument() {
                bibliographies += Self.items(in: list)
            }
        case "externaldocument", "externalcitedocument":
            usesExternalDocuments = true
        case "usepackage", "RequirePackage":
            skipOptional()
            if let list = readArgument(), Self.items(in: list).contains(where: { $0 == "xr" || $0 == "xr-hyper" || $0 == "zref-xr" }) {
                usesExternalDocuments = true
            }
        case let command where LaTeXLanguage.labelReferenceCommands.contains(command):
            skipStar()
            skipOverlay()
            if let argument = readArgument() {
                // cleveref takes lists of labels; \ref takes one, which may contain commas.
                let keys = command.lowercased() == "cref" ? Self.items(in: argument) : [argument.trimmingCharacters(in: .whitespaces)]
                for key in keys where Self.isPlainKey(key) {
                    references.append((key, line))
                }
            }
        case let command where LaTeXLanguage.citationCommands.contains(command):
            skipStar()
            skipOverlay()
            skipOptional()
            skipOptional()
            if let argument = readArgument() {
                for key in Self.items(in: argument) where Self.isPlainKey(key) && key != "*" {
                    citations.append((key, line))
                }
            }
        default:
            break
        }
    }

    private mutating func readBegin() {
        let beginLine = line
        guard let name = readArgument()?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return }
        guard verbatimEnvironments.contains(name) else {
            environments.append((name, depth, conditionals.count, beginLine))
            return
        }
        // Skip a verbatim environment's contents up to its \end{name}.
        let endCommand = Array("\\end".utf16)
        let argument = Array("{\(name)}".utf16)
        var position = index
        while position + endCommand.count <= units.count {
            if units[position] == Char.backslash && Array(units[position..<(position + endCommand.count)]) == endCommand {
                var after = position + endCommand.count
                while after < units.count && (units[after] == Char.space || units[after] == Char.tab) {
                    after += 1
                }
                if after + argument.count <= units.count && Array(units[after..<(after + argument.count)]) == argument {
                    countLines(from: index, to: position)
                    index = after + argument.count
                    return
                }
            }
            position += 1
        }
        issues.append(LiveIssue(severity: .error, message: String(localized: "\\begin{\(name)} isn’t closed"), line: beginLine))
        countLines(from: index, to: units.count)
        index = units.count
    }

    private mutating func readEnd() {
        guard let name = readArgument()?.trimmingCharacters(in: .whitespaces), !name.isEmpty else { return }
        // Look for the environment among those begun at this brace depth and in the same
        // conditional, innermost first.
        let level = conditionals.count
        var position = environments.count - 1
        while position >= 0 && environments[position].depth == depth && environments[position].conditional == level
                && environments[position].name != name {
            position -= 1
        }
        if position >= 0 && environments[position].depth == depth && environments[position].conditional == level
            && environments[position].name == name {
            for skipped in environments[(position + 1)...] {
                issues.append(LiveIssue(
                    severity: .error,
                    message: String(localized: "\\begin{\(skipped.name)} isn’t closed before \\end{\(name)} on line \(line)"),
                    line: skipped.line
                ))
            }
            environments.removeSubrange(position...)
        } else if depth == 0 && level == 0 {
            issues.append(LiveIssue(
                severity: .error,
                message: String(localized: "\\end{\(name)} has no matching \\begin{\(name)}"),
                line: line
            ))
        }
    }

    // MARK: - Arguments

    /// A simple braced argument, such as a key or an environment name, after optional
    /// spaces. Nil, leaving the text unread, if the argument has braces or a line break in
    /// it — that's for the main loop to read.
    private mutating func readArgument() -> String? {
        var position = index
        while position < units.count && (units[position] == Char.space || units[position] == Char.tab) {
            position += 1
        }
        guard position < units.count, units[position] == Char.openBrace else { return nil }
        let start = position + 1
        var end = start
        while end < units.count {
            let unit = units[end]
            if unit == Char.closeBrace {
                break
            }
            if unit == Char.openBrace || unit == Char.newline || unit == Char.percent {
                return nil
            }
            end += 1
        }
        guard end < units.count else { return nil }
        index = end + 1
        return string(from: start, to: end)
    }

    /// Skips a braced group as it is, counting nested braces only.
    private mutating func skipRawGroup() {
        var position = index
        while position < units.count && (units[position] == Char.space || units[position] == Char.tab) {
            position += 1
        }
        guard position < units.count, units[position] == Char.openBrace else { return }
        var nesting = 0
        var end = position
        while end < units.count {
            let unit = units[end]
            if unit == Char.newline {
                // Addresses don't span lines; let the main loop read the rest.
                return
            }
            if unit == Char.backslash {
                end += 2
                continue
            }
            if unit == Char.openBrace {
                nesting += 1
            } else if unit == Char.closeBrace {
                nesting -= 1
                if nesting == 0 {
                    index = end + 1
                    return
                }
            }
            end += 1
        }
    }

    /// Skips `|code|` (any delimiter) as \verb reads it.
    private mutating func skipDelimited() {
        guard index < units.count else { return }
        let delimiter = units[index]
        guard delimiter != Char.newline, delimiter != Char.space, !Char.isCommandLetter(delimiter) else { return }
        var end = index + 1
        while end < units.count && units[end] != delimiter && units[end] != Char.newline {
            end += 1
        }
        index = end < units.count && units[end] == delimiter ? end + 1 : end
    }

    /// Inline code, in braces or between delimiters.
    private mutating func skipInlineCode() {
        if index < units.count && units[index] == Char.openBrace {
            skipRawGroup()
        } else {
            skipDelimited()
        }
    }

    /// Skips an optional argument in brackets.
    private mutating func skipOptional() {
        var position = index
        while position < units.count && (units[position] == Char.space || units[position] == Char.tab) {
            position += 1
        }
        guard position < units.count, units[position] == Char.openBracket else { return }
        var end = position + 1
        var newlines = 0
        while end < units.count && units[end] != Char.closeBracket && end - position < 1000 {
            if units[end] == Char.newline {
                newlines += 1
            } else if units[end] == Char.openBrace || units[end] == Char.closeBrace {
                // Braces in an optional argument are the main loop's to count.
                return
            }
            end += 1
        }
        guard end < units.count, units[end] == Char.closeBracket else { return }
        line += newlines
        index = end + 1
    }

    /// Skips a Beamer overlay specification such as `<2->`.
    private mutating func skipOverlay() {
        guard index < units.count, units[index] == 0x3C else { return }
        var end = index + 1
        while end < units.count && units[end] != 0x3E && units[end] != Char.newline && end - index < 40 {
            end += 1
        }
        if end < units.count && units[end] == 0x3E {
            index = end + 1
        }
    }

    private mutating func skipStar() {
        if index < units.count && units[index] == Char.star {
            index += 1
        }
    }

    /// Skips text left out with `\iffalse … \fi`.
    private mutating func skipToFi() {
        var position = index
        while position + 2 < units.count {
            if units[position] == Char.backslash && units[position + 1] == 0x66 && units[position + 2] == 0x69
                && (position + 3 >= units.count || !Char.isCommandLetter(units[position + 3])) {
                countLines(from: index, to: position)
                index = position + 3
                return
            }
            position += 1
        }
    }

    private mutating func skipToEndOfLine() {
        while index < units.count && units[index] != Char.newline {
            index += 1
        }
    }

    private mutating func countLines(from start: Int, to end: Int) {
        var position = start
        while position < end {
            if units[position] == Char.newline {
                line += 1
            }
            position += 1
        }
    }

    private func string(from start: Int, to end: Int) -> String {
        String(decoding: units[start..<end], as: UTF16.self)
    }

    /// Whether the next character, after spaces, opens a brace.
    private var isFollowedByBrace: Bool {
        var position = index
        while position < units.count && (units[position] == Char.space || units[position] == Char.tab) {
            position += 1
        }
        return position < units.count && units[position] == Char.openBrace
    }

    /// Whether a control word starts a TeX conditional, ended by \fi: \ifx, \ifnum,
    /// \ifdefined, a conditional made with \newif… but not \iff (⟺), nor the etoolbox and
    /// ifthen commands that take their branches as arguments.
    static func isConditional(_ name: String) -> Bool {
        guard name.hasPrefix("if"), name != "iff", name != "iffalse" else { return false }
        let commandsWithArguments = [
            "ifdef", "ifundef", "ifcs", "ifbool", "iftoggle", "ifthenelse", "ifstr", "ifnumcomp",
            "ifdimcomp", "ifnumequal", "ifblank", "ifpatchable",
        ]
        return !commandsWithArguments.contains { name.hasPrefix($0) }
    }

    /// The trimmed, non-empty items of a comma-separated list.
    static func items(in list: String) -> [String] {
        list.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Keys written out, not built by a macro from its parameters.
    static func isPlainKey(_ key: String) -> Bool {
        !key.isEmpty && !key.contains("#") && !key.contains("\\")
    }
}
