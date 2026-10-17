//
//  CompletionEngine.swift
//  TexLab
//

import Foundation

/// One suggestion in the completion list.
nonisolated struct CompletionItem: Identifiable, Hashable, Sendable {
    nonisolated enum Kind: Sendable, Hashable {
        case command, environment, label, citation, file, package, documentClass
    }

    var kind: Kind
    /// What replaces the text being completed.
    var insertion: String
    /// The name shown, in the code font.
    var title: String
    /// More about it: a caption or heading, an author, year and title, what a command does.
    var detail: String?
    /// Where it comes from, when that's not the file on screen: a chapter, a package.
    var source: String?
    var systemImage: String
    /// The braced arguments a command takes, which completing it adds.
    var argumentCount = 0

    var id: String { "\(kind)|\(insertion)|\(source ?? "")" }
}

/// What is being completed: a command after `\`, or an argument such as the key in
/// `\cite{knu`.
nonisolated struct CompletionQuery: Equatable, Sendable {
    nonisolated enum Mode: Equatable, Sendable {
        case command
        /// The argument of `command`, such as `ref` or `includegraphics`.
        case argument(String)
    }

    var mode: Mode
    /// The text the chosen item replaces, from the start of the word to the insertion point.
    var range: NSRange
    /// That text: what has been typed so far.
    var partial: String
}

/// What the project offers to complete, gathered when the list opens.
nonisolated struct CompletionSources: Sendable {
    nonisolated struct Label: Sendable {
        var key: String
        var context: String?
        /// The file it's defined in, when it isn't the one on screen.
        var fileName: String?
        var kind: LabelDefinition.Kind
    }

    nonisolated struct File: Sendable {
        /// The path from the main file's folder, as TeX wants it.
        var path: String
        var pathExtension: String
    }

    nonisolated struct Command: Sendable {
        var name: String
        var argumentCount: Int
        var fileName: String?
    }

    var labels: [Label] = []
    var citations: [BibEntry] = []
    var files: [File] = []
    var commands: [Command] = []
    var environments: Set<String> = []
}

/// Works out what to complete at the insertion point and ranks the candidates: exact-case
/// prefixes first, then other prefixes, word starts inside keys (`fig:` → `results`),
/// and letters in order. Citations also match their authors, title and year, and labels
/// their caption.
nonisolated enum CompletionEngine {
    static let maximumItems = 200

    /// Commands whose argument lists several items separated by commas.
    private static let listCommands: Set<String> = LaTeXLanguage.citationCommands.union([
        "cref", "Cref", "bibliography", "addbibresource", "usepackage", "RequirePackage", "includeonly",
    ])

    /// Commands whose argument TexLab completes.
    static let argumentCommands: Set<String> = LaTeXLanguage.labelReferenceCommands
        .union(LaTeXLanguage.citationCommands)
        .union([
            "begin", "end", "input", "include", "subfile", "includeonly", "includegraphics", "includepdf",
            "bibliography", "addbibresource", "usepackage", "RequirePackage", "documentclass", "LoadClass",
            "lstinputlisting",
        ])

    // MARK: - What to complete

    /// What is being completed at `location`, or nil if it isn't a command or a completable
    /// argument. Comments aren't completed.
    static func query(at location: Int, in text: NSString) -> CompletionQuery? {
        guard location <= text.length, !DefinitionFinder.isInComment(location, in: text) else { return nil }
        if let command = CompletionContext.argumentCommand(at: location, in: text), argumentCommands.contains(command) {
            var start = location
            while start > 0 {
                let character = text.character(at: start - 1)
                if character == Char.openBrace || (character == Char.comma && listCommands.contains(command)) {
                    break
                }
                start -= 1
            }
            // Spaces after a comma in a list belong to no key.
            while start < location && text.character(at: start) == Char.space {
                start += 1
            }
            let range = NSRange(location: start, length: location - start)
            return CompletionQuery(mode: .argument(command), range: range, partial: text.substring(with: range))
        }
        var start = location
        while start > 0 && Char.isCommandLetter(text.character(at: start - 1)) {
            start -= 1
        }
        guard start > 0, text.character(at: start - 1) == Char.backslash else { return nil }
        // `\\` is a line break, not the start of a command.
        if start >= 2 && text.character(at: start - 2) == Char.backslash {
            return nil
        }
        let range = NSRange(location: start - 1, length: location - start + 1)
        return CompletionQuery(mode: .command, range: range, partial: text.substring(with: NSRange(location: start, length: location - start)))
    }

    // MARK: - Candidates

    /// The candidates for `query`, best first.
    static func items(for query: CompletionQuery, in text: NSString, sources: CompletionSources) -> [CompletionItem] {
        switch query.mode {
        case .command:
            return rank(commandItems(sources), partial: query.partial) { [$0.title.dropFirst().description] }
        case .argument(let command):
            return argumentItems(for: command, query: query, in: text, sources: sources)
        }
    }

    private static func argumentItems(for command: String, query: CompletionQuery, in text: NSString, sources: CompletionSources) -> [CompletionItem] {
        let partial = query.partial
        switch command {
        case "begin", "end":
            var names = Set(LaTeXCatalog.environments).union(sources.environments)
            var preferred: String?
            if command == "end" {
                // The environment to close comes first.
                preferred = innermostOpenEnvironment(before: query.range.location, in: text)
                if let preferred {
                    names.insert(preferred)
                }
            }
            let items = names.map { name in
                CompletionItem(
                    kind: .environment,
                    insertion: name,
                    title: name,
                    detail: name == preferred ? String(localized: "Closes the open environment") : (sources.environments.contains(name) ? String(localized: "Defined in the project") : nil),
                    systemImage: "chevron.left.forwardslash.chevron.right"
                )
            }
            var ranked = rank(items, partial: partial) { [$0.title] }
            if let preferred, let index = ranked.firstIndex(where: { $0.insertion == preferred }) {
                ranked.insert(ranked.remove(at: index), at: 0)
            }
            return ranked
        case let name where LaTeXLanguage.labelReferenceCommands.contains(name):
            // Labels in the file on screen first.
            let labels = sources.labels.sorted { ($0.fileName == nil ? 0 : 1, $0.key) < ($1.fileName == nil ? 0 : 1, $1.key) }
            let items = labels.map { label in
                CompletionItem(kind: .label, insertion: label.key, title: label.key, detail: label.context, source: label.fileName, systemImage: label.kind.systemImage)
            }
            return rank(unique(items), partial: partial) { item in
                [item.title, item.detail ?? ""]
            }
        case let name where LaTeXLanguage.citationCommands.contains(name):
            let items = sources.citations.map { entry in
                CompletionItem(
                    kind: .citation,
                    insertion: entry.key,
                    title: entry.key,
                    detail: citationDetail(entry),
                    source: entry.file?.lastPathComponent,
                    systemImage: entry.systemImage
                )
            }
            let entries = Dictionary(sources.citations.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
            return rank(unique(items), partial: partial) { item in
                let entry = entries[item.insertion]
                return [item.title, entry?.authors ?? "", entry?.title ?? "", entry?.year ?? ""]
            }
        case "input", "include", "subfile", "includeonly":
            return fileItems(sources, extensions: ["tex"], keepsExtension: false, partial: partial)
        case "includegraphics":
            return fileItems(sources, extensions: ["pdf", "png", "jpg", "jpeg", "eps", "svg"], keepsExtension: true, partial: partial)
        case "includepdf":
            return fileItems(sources, extensions: ["pdf"], keepsExtension: true, partial: partial)
        case "bibliography":
            return fileItems(sources, extensions: ["bib"], keepsExtension: false, partial: partial)
        case "addbibresource":
            return fileItems(sources, extensions: ["bib"], keepsExtension: true, partial: partial)
        case "lstinputlisting":
            return fileItems(sources, extensions: ["py", "m", "c", "cpp", "h", "swift", "java", "js", "r", "jl", "sh", "txt"], keepsExtension: true, partial: partial)
        case "usepackage", "RequirePackage":
            let local = sources.files.filter { $0.pathExtension == "sty" }.map { file in
                CompletionItem(kind: .package, insertion: String(file.path.dropLast(4)), title: String(file.path.dropLast(4)), detail: String(localized: "In the project"), systemImage: "shippingbox")
            }
            let installed = LaTeXCatalog.packages.map { name in
                CompletionItem(kind: .package, insertion: name, title: name, detail: LaTeXCatalog.packageDescriptions[name], systemImage: "shippingbox")
            }
            return rank(unique(local + installed), partial: partial) { [$0.title] }
        case "documentclass", "LoadClass":
            let local = sources.files.filter { $0.pathExtension == "cls" }.map { file in
                CompletionItem(kind: .documentClass, insertion: String(file.path.dropLast(4)), title: String(file.path.dropLast(4)), detail: String(localized: "In the project"), systemImage: "doc.badge.gearshape")
            }
            let installed = LaTeXCatalog.documentClasses.map { name in
                CompletionItem(kind: .documentClass, insertion: name, title: name, systemImage: "doc.badge.gearshape")
            }
            return rank(unique(local + installed), partial: partial) { [$0.title] }
        default:
            return []
        }
    }

    private static func commandItems(_ sources: CompletionSources) -> [CompletionItem] {
        var items = LaTeXCatalog.allCommands.map { name in
            let count = LaTeXCatalog.argumentCount(of: name)
            return CompletionItem(
                kind: .command,
                insertion: "\\" + name,
                title: "\\" + name,
                detail: LaTeXCatalog.commandDescriptions[name] ?? signature(count),
                systemImage: "function",
                argumentCount: count
            )
        }
        let known = Set(LaTeXCatalog.allCommands)
        for command in sources.commands where !known.contains(command.name) {
            items.append(CompletionItem(
                kind: .command,
                insertion: "\\" + command.name,
                title: "\\" + command.name,
                detail: command.argumentCount > 0 ? signature(command.argumentCount) : String(localized: "Defined in the project"),
                source: command.fileName,
                systemImage: "function",
                argumentCount: command.argumentCount
            ))
        }
        return unique(items)
    }

    private static func fileItems(_ sources: CompletionSources, extensions: Set<String>, keepsExtension: Bool, partial: String) -> [CompletionItem] {
        let items = sources.files.filter { extensions.contains($0.pathExtension) }.map { file in
            let insertion = keepsExtension ? file.path : String(file.path.dropLast(file.pathExtension.count + 1))
            return CompletionItem(
                kind: .file,
                insertion: insertion,
                title: insertion,
                systemImage: ProjectFileKind(url: URL(filePath: file.path), isDirectory: false).systemImage
            )
        }
        return rank(unique(items), partial: partial) { item in
            [item.title, (item.title as NSString).lastPathComponent]
        }
    }

    /// "{…}{…}" for a command's arguments.
    private static func signature(_ count: Int) -> String? {
        count > 0 ? String(repeating: "{…}", count: count) : nil
    }

    /// "Knuth 1984 · The TeXbook".
    private static func citationDetail(_ entry: BibEntry) -> String? {
        let parts = [entry.shortCitation, entry.title].filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func unique(_ items: [CompletionItem]) -> [CompletionItem] {
        var seen: Set<String> = []
        return items.filter { seen.insert($0.id).inserted }
    }

    // MARK: - Environments

    private static let environmentPattern = try! NSRegularExpression(pattern: #"\\(begin|end)\s*\{([^{}\n]*)\}"#)

    /// The innermost environment begun before `location` and not yet ended.
    static func innermostOpenEnvironment(before location: Int, in text: NSString) -> String? {
        var open: [String] = []
        for match in environmentPattern.matches(in: text as String, range: NSRange(location: 0, length: min(location, text.length))) {
            guard !DefinitionFinder.isInComment(match.range.location, in: text) else { continue }
            let name = text.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)
            if text.substring(with: match.range(at: 1)) == "begin" {
                open.append(name)
            } else if let index = open.lastIndex(of: name) {
                open.removeSubrange(index...)
            }
        }
        return open.last
    }

    // MARK: - Ranking

    /// The items that match `partial`, best first. `fields` gives the texts an item can
    /// match: its name first, then anything else that describes it.
    static func rank(_ items: [CompletionItem], partial: String, fields: (CompletionItem) -> [String]) -> [CompletionItem] {
        guard !partial.isEmpty else {
            return Array(items.prefix(maximumItems))
        }
        var scored: [(item: CompletionItem, score: Int)] = []
        for item in items {
            let texts = fields(item)
            var best: Int?
            for (index, text) in texts.enumerated() {
                guard let score = score(text, partial: partial, isName: index == 0) else { continue }
                best = max(best ?? Int.min, score)
            }
            if let best {
                scored.append((item, best))
            }
        }
        scored.sort { lhs, rhs in
            lhs.score != rhs.score ? lhs.score > rhs.score : lhs.item.title.localizedStandardCompare(rhs.item.title) == .orderedAscending
        }
        return scored.prefix(maximumItems).map(\.item)
    }

    /// How well `text` matches what was typed, or nil if it doesn't. A name can match its
    /// letters in order; descriptions only at the start of a word.
    static func score(_ text: String, partial: String, isName: Bool) -> Int? {
        guard !text.isEmpty else { return nil }
        let length = text.count
        if isName && text.hasPrefix(partial) {
            return 10_000 - length
        }
        let lowercasedText = text.lowercased()
        let lowercasedPartial = partial.lowercased()
        if isName && lowercasedText.hasPrefix(lowercasedPartial) {
            return 9_000 - length
        }
        // The start of a word: after a space, punctuation or a separator in a key.
        let separators = CharacterSet.alphanumerics.inverted
        let words = lowercasedText.components(separatedBy: separators).filter { !$0.isEmpty }
        if words.contains(where: { $0.hasPrefix(lowercasedPartial) }) {
            return (isName ? 7_000 : 5_000) - length
        }
        guard isName else { return nil }
        if lowercasedText.contains(lowercasedPartial) {
            return 4_000 - length
        }
        // The letters in order, closer together scoring higher.
        var gaps = 0
        var index = lowercasedText.startIndex
        for character in lowercasedPartial {
            guard let found = lowercasedText[index...].firstIndex(of: character) else { return nil }
            gaps += lowercasedText.distance(from: index, to: found)
            index = lowercasedText.index(after: found)
        }
        return 2_000 - gaps * 10 - length
    }
}
