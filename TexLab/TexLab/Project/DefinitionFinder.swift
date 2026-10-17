//
//  DefinitionFinder.swift
//  TexLab
//

import Foundation

/// What Jump to Definition goes to from a place in the source.
nonisolated enum DefinitionTarget: Equatable, Sendable {
    /// The `\label` a reference such as `\ref` or `\eqref` names.
    case label(String)
    /// The bibliography entry a citation names.
    case citation(String)
    /// The file an argument names. `extensions` are the ones TeX tries when the path has
    /// none of its own.
    case file(path: String, extensions: [String])
    /// The `\newcommand` (or `\def`, `\DeclareMathOperator`, …) defining a command.
    case command(String)
    /// The other end of an environment: the `\end` of a `\begin`, or the other way round.
    case environment(name: String, partner: NSRange, partnerIsEnd: Bool)

    /// The title of the editor's context menu item.
    var menuTitle: String {
        switch self {
        case .environment(let name, _, true):
            String(localized: "Jump to \\end{\(name)}")
        case .environment(let name, _, false):
            String(localized: "Jump to \\begin{\(name)}")
        case .file:
            String(localized: "Open File")
        default:
            String(localized: "Jump to Definition")
        }
    }
}

/// A command defined with `\newcommand` or a similar command, and where.
nonisolated struct CommandDefinition: Hashable, Sendable {
    var name: String
    /// The file that defines it, or nil for the document being edited.
    var file: URL?
    /// 1-based.
    var line: Int
    /// How many arguments it takes, from `[2]` in `\newcommand{\name}[2]` or `#1#2` in
    /// `\def`.
    var argumentCount = 0
}

/// Finds what the text at a location refers to, and where things are defined in a text.
nonisolated enum DefinitionFinder {
    /// What Jump to Definition at `location` goes to, or nil if it isn't on anything that
    /// has a definition: a reference, a citation, a file, a command the document defines,
    /// or a `\begin` or `\end`.
    static func target(at location: Int, in text: NSString) -> DefinitionTarget? {
        guard text.length > 0 else { return nil }
        let location = min(max(location, 0), text.length)
        guard !isInComment(location, in: text) else { return nil }
        if let partner = environmentPartner(at: location, in: text) {
            return partner
        }
        if let command = CompletionContext.argumentCommand(at: location, in: text),
           let argument = argumentRange(around: location, in: text) {
            return target(forArgumentOf: command, argument: argument, at: location, in: text)
        }
        guard let command = commandName(at: location, in: text) else { return nil }
        if let argument = firstArgument(after: NSMaxRange(command.range), in: text),
           let target = target(forArgumentOf: command.name, argument: argument, at: argument.location, in: text) {
            // On the name of a command that refers to something, such as `\ref`.
            return target
        }
        guard !builtInCommands.contains(command.name) else { return nil }
        return .command(command.name)
    }

    private static let builtInCommands = Set(LaTeXCatalog.allCommands)

    private static func target(forArgumentOf command: String, argument: NSRange, at location: Int, in text: NSString) -> DefinitionTarget? {
        let item = self.item(in: argument, at: location, of: text)
        guard !item.isEmpty else { return nil }
        switch command {
        case let name where LaTeXLanguage.labelReferenceCommands.contains(name):
            return .label(item)
        case let name where LaTeXLanguage.citationCommands.contains(name):
            return .citation(item)
        case "input", "include", "includeonly", "subfile":
            return .file(path: item, extensions: ["tex"])
        case "includegraphics":
            return .file(path: item, extensions: ["pdf", "png", "jpg", "jpeg", "eps"])
        case "includepdf":
            return .file(path: item, extensions: ["pdf"])
        case "bibliography":
            return .file(path: item, extensions: ["bib"])
        case "addbibresource", "lstinputlisting", "verbatiminput":
            return .file(path: item, extensions: [])
        case "usepackage", "RequirePackage":
            return .file(path: item, extensions: ["sty"])
        case "documentclass", "LoadClass":
            return .file(path: item, extensions: ["cls"])
        default:
            return nil
        }
    }

    // MARK: - Reading the text around a location

    /// The text of the braced argument containing `location`, as in `\ref{fig:|plot}`.
    private static func argumentRange(around location: Int, in text: NSString) -> NSRange? {
        var start = location
        while start > 0 {
            let character = text.character(at: start - 1)
            if character == Char.openBrace {
                break
            }
            if character == Char.closeBrace || character == Char.newline {
                return nil
            }
            start -= 1
        }
        guard start > 0 else { return nil }
        var end = location
        while end < text.length {
            let character = text.character(at: end)
            if character == Char.closeBrace || character == Char.openBrace || character == Char.newline {
                break
            }
            end += 1
        }
        return NSRange(location: start, length: end - start)
    }

    /// The comma-separated item of `argument` at `location`, trimmed: one key of
    /// `\cite{a,b}`.
    private static func item(in argument: NSRange, at location: Int, of text: NSString) -> String {
        let value = text.substring(with: argument)
        let offset = location - argument.location
        var start = 0
        let parts = value.components(separatedBy: ",")
        for part in parts {
            let length = (part as NSString).length
            if offset <= start + length {
                return part.trimmingCharacters(in: .whitespaces)
            }
            start += length + 1
        }
        return parts.last?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    /// The control word at `location`, from its backslash: `\foo` when the location is on
    /// the backslash, in the name or just after it.
    private static func commandName(at location: Int, in text: NSString) -> (name: String, range: NSRange)? {
        var start = location
        if start < text.length && text.character(at: start) == Char.backslash {
            start += 1
        } else {
            while start > 0 && Char.isCommandLetter(text.character(at: start - 1)) {
                start -= 1
            }
        }
        guard start > 0, text.character(at: start - 1) == Char.backslash else { return nil }
        // `\\` is a line break, and the letters after it are text.
        if start >= 2 && text.character(at: start - 2) == Char.backslash {
            return nil
        }
        var end = start
        while end < text.length && Char.isCommandLetter(text.character(at: end)) {
            end += 1
        }
        guard end > start else { return nil }
        let name = text.substring(with: NSRange(location: start, length: end - start))
        return (name, NSRange(location: start - 1, length: end - start + 1))
    }

    /// The text of the first braced argument after a command name ending at `index`,
    /// skipping a star and optional arguments.
    private static func firstArgument(after index: Int, in text: NSString) -> NSRange? {
        var cursor = index
        while cursor < text.length {
            let character = text.character(at: cursor)
            if character == Char.star || character == Char.space {
                cursor += 1
            } else if character == Char.openBracket {
                while cursor < text.length && text.character(at: cursor) != Char.closeBracket && text.character(at: cursor) != Char.newline {
                    cursor += 1
                }
                guard cursor < text.length, text.character(at: cursor) == Char.closeBracket else { return nil }
                cursor += 1
            } else {
                break
            }
        }
        guard cursor < text.length, text.character(at: cursor) == Char.openBrace else { return nil }
        let start = cursor + 1
        var end = start
        while end < text.length {
            let character = text.character(at: end)
            if character == Char.closeBrace || character == Char.openBrace || character == Char.newline {
                break
            }
            end += 1
        }
        guard end < text.length, text.character(at: end) == Char.closeBrace else { return nil }
        return NSRange(location: start, length: end - start)
    }

    /// Whether `location` is in a comment.
    static func isInComment(_ location: Int, in text: NSString) -> Bool {
        let lineStart = text.lineRange(for: NSRange(location: min(location, text.length), length: 0)).location
        let prefix = text.substring(with: NSRange(location: lineStart, length: min(location, text.length) - lineStart))
        return LaTeXText.stripComment(prefix) != prefix
    }

    // MARK: - Environments

    private static let environmentPattern = try! NSRegularExpression(pattern: #"\\(begin|end)\s*\{([^{}\n]*)\}"#)

    /// The other end of the `\begin{…}` or `\end{…}` at `location`, counting nested
    /// environments of the same name and skipping comments.
    static func environmentPartner(at location: Int, in text: NSString) -> DefinitionTarget? {
        let line = text.lineRange(for: NSRange(location: min(location, text.length), length: 0))
        let string = text as String
        guard let here = environmentPattern.matches(in: string, range: line).first(where: {
            location >= $0.range.location && location <= NSMaxRange($0.range)
        }) else { return nil }
        let isBegin = text.substring(with: here.range(at: 1)) == "begin"
        let name = text.substring(with: here.range(at: 2)).trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }

        let searchRange = isBegin
            ? NSRange(location: NSMaxRange(here.range), length: text.length - NSMaxRange(here.range))
            : NSRange(location: 0, length: here.range.location)
        var candidates = environmentPattern.matches(in: string, range: searchRange).filter { match in
            text.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces) == name
                && !isInComment(match.range.location, in: text)
        }
        if !isBegin {
            candidates.reverse()
        }
        var depth = 0
        for match in candidates {
            let matchIsBegin = text.substring(with: match.range(at: 1)) == "begin"
            if matchIsBegin == isBegin {
                depth += 1
            } else if depth == 0 {
                return .environment(name: name, partner: match.range, partnerIsEnd: isBegin)
            } else {
                depth -= 1
            }
        }
        return nil
    }

    // MARK: - Definitions in a text

    private static let labelPattern = try! NSRegularExpression(pattern: #"\\label\s*\{([^{}]+)\}"#)
    private static let bibItemPattern = try! NSRegularExpression(pattern: #"\\bibitem\s*(?:\[[^\]]*\])?\s*\{([^{}]+)\}"#)
    private static let commandDefinitionPattern = try! NSRegularExpression(
        pattern: #"\\(?:(?:re)?newcommand|providecommand|DeclareRobustCommand|DeclareMathOperator|(?:New|Renew|Provide|Declare)DocumentCommand|[gex]?def|let)\*?\s*\{?\s*\\([A-Za-z@]+)"#
    )

    /// Where `\label{key}` is in `text`: the range of the key.
    static func labelRange(for key: String, in text: NSString) -> NSRange? {
        firstArgumentRange(matching: key, pattern: labelPattern, in: text)
    }

    /// Where `\bibitem{key}` is in `text`: the range of the key.
    static func bibItemRange(for key: String, in text: NSString) -> NSRange? {
        firstArgumentRange(matching: key, pattern: bibItemPattern, in: text)
    }

    /// Where `text` defines the command `name`: the range of `\name` in the definition.
    static func commandDefinitionRange(for name: String, in text: NSString) -> NSRange? {
        for match in commandDefinitionPattern.matches(in: text as String, range: NSRange(location: 0, length: text.length)) {
            let nameRange = match.range(at: 1)
            guard text.substring(with: nameRange) == name, !isInComment(match.range.location, in: text) else { continue }
            return NSRange(location: nameRange.location - 1, length: nameRange.length + 1)
        }
        return nil
    }

    /// The commands `text` defines, outside comments.
    static func commandDefinitions(in text: String, file: URL?) -> [CommandDefinition] {
        let string = text as NSString
        var results: [CommandDefinition] = []
        var line = 1
        var scanned = 0
        for match in commandDefinitionPattern.matches(in: text, range: NSRange(location: 0, length: string.length)) {
            line += LineIndex.lineBreaks(in: string, range: NSRange(location: scanned, length: match.range.location - scanned)).count
            scanned = match.range.location
            guard !isInComment(match.range.location, in: string) else { continue }
            results.append(CommandDefinition(
                name: string.substring(with: match.range(at: 1)),
                file: file,
                line: line,
                argumentCount: argumentCount(after: NSMaxRange(match.range), in: string)
            ))
        }
        return results
    }

    /// The argument count after a defined command's name: `}[2]` or `#1#2{`.
    private static func argumentCount(after index: Int, in string: NSString) -> Int {
        var cursor = index
        func skip(_ characters: Set<unichar>) {
            while cursor < string.length && characters.contains(string.character(at: cursor)) {
                cursor += 1
            }
        }
        skip([Char.closeBrace, Char.space, Char.tab])
        guard cursor < string.length else { return 0 }
        if string.character(at: cursor) == Char.openBracket, cursor + 2 < string.length,
           string.character(at: cursor + 2) == Char.closeBracket {
            let digit = Int(string.character(at: cursor + 1)) - 0x30
            return (0...9).contains(digit) ? digit : 0
        }
        // \def\name#1#2{…}
        var count = 0
        while cursor + 1 < string.length && string.character(at: cursor) == Char.hash {
            count += 1
            cursor += 2
        }
        return count
    }

    private static let environmentDefinitionPattern = try! NSRegularExpression(
        pattern: #"\\(?:(?:re)?newenvironment|(?:New|Renew|Provide|Declare)DocumentEnvironment|newtheorem|declaretheorem|lstnewenvironment|DefineVerbatimEnvironment|newtcolorbox|newtcblisting)\*?\s*(?:\[[^\]\n]*\])?\s*\{([^{}\n]+)\}"#
    )

    /// The environments `text` defines, outside comments.
    static func environmentDefinitions(in text: String) -> Set<String> {
        let string = text as NSString
        var names: Set<String> = []
        for match in environmentDefinitionPattern.matches(in: text, range: NSRange(location: 0, length: string.length)) {
            guard !isInComment(match.range.location, in: string) else { continue }
            names.insert(string.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces))
        }
        return names
    }

    private static func firstArgumentRange(matching key: String, pattern: NSRegularExpression, in text: NSString) -> NSRange? {
        for match in pattern.matches(in: text as String, range: NSRange(location: 0, length: text.length)) {
            let argument = match.range(at: 1)
            guard text.substring(with: argument).trimmingCharacters(in: .whitespaces) == key,
                  !isInComment(match.range.location, in: text) else { continue }
            return argument
        }
        return nil
    }
}
