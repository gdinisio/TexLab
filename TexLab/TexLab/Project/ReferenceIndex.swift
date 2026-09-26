//
//  ReferenceIndex.swift
//  TexLab
//

import Foundation

/// A `\label` and where it is defined.
nonisolated struct LabelDefinition: Identifiable, Hashable, Sendable {
    nonisolated enum Kind: Sendable {
        case figure, table, equation, section, chapter, listing, item, theorem, other

        var systemImage: String {
            switch self {
            case .figure: "photo"
            case .table: "tablecells"
            case .equation: "function"
            case .section: "number"
            case .chapter: "book.closed"
            case .listing: "curlybraces"
            case .item: "list.number"
            case .theorem: "checkmark.seal"
            case .other: "tag"
            }
        }

        var title: String {
            switch self {
            case .figure: String(localized: "Figures")
            case .table: String(localized: "Tables")
            case .equation: String(localized: "Equations")
            case .section: String(localized: "Sections")
            case .chapter: String(localized: "Chapters")
            case .listing: String(localized: "Listings")
            case .item: String(localized: "Items")
            case .theorem: String(localized: "Theorems")
            case .other: String(localized: "Other Labels")
            }
        }
    }

    var key: String
    /// The file that defines it, or nil for the document being edited.
    var file: URL?
    /// 1-based.
    var line: Int

    var id: String { "\(key)@\(file?.path(percentEncoded: false) ?? ""):\(line)" }

    /// What the label names, from the usual prefixes: fig:, tab:, eq:, sec:, …
    var kind: Kind {
        let prefix = key.split(separator: ":", maxSplits: 1).first.map { $0.lowercased() } ?? ""
        guard key.contains(":") else { return .other }
        switch prefix {
        case "fig", "figure", "subfig": return .figure
        case "tab", "table", "tbl": return .table
        case "eq", "eqn", "equation", "align": return .equation
        case "sec", "section", "subsec", "ssec", "par": return .section
        case "ch", "chap", "chapter", "part": return .chapter
        case "lst", "listing", "code", "alg", "algorithm": return .listing
        case "item", "it", "enum": return .item
        case "thm", "theorem", "lem", "lemma", "def", "definition", "cor", "prop", "rem", "ex", "example": return .theorem
        default: return .other
        }
    }

    /// The command that refers to it best: `\eqref` for equations, `\ref` otherwise.
    var preferredReferenceCommand: String {
        kind == .equation ? "eqref" : "ref"
    }
}

/// An entry of a BibTeX or BibLaTeX database, or a `\bibitem`.
nonisolated struct BibEntry: Identifiable, Hashable, Sendable {
    var key: String
    /// article, book, inproceedings, …; "bibitem" for `\bibitem`.
    var type: String
    var title: String
    var authors: String
    var year: String
    var file: URL?

    var id: String { key + "@" + (file?.path(percentEncoded: false) ?? "") }

    /// "Lamport 1994", "Knuth & Lamport 1986", "Smith et al. 2020".
    var shortCitation: String {
        let names = authors
            .components(separatedBy: " and ")
            .map { name -> String in
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                if let comma = trimmed.firstIndex(of: ",") {
                    return String(trimmed[..<comma])
                }
                return trimmed.split(separator: " ").last.map(String.init) ?? trimmed
            }
            .filter { !$0.isEmpty }
        let who: String
        switch names.count {
        case 0: who = ""
        case 1: who = names[0]
        case 2: who = "\(names[0]) & \(names[1])"
        default: who = String(localized: "\(names[0]) et al.")
        }
        return [who, year].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var systemImage: String {
        switch type {
        case "book", "inbook", "booklet", "collection": "book.closed"
        case "article", "periodical": "doc.text"
        case "inproceedings", "proceedings", "conference": "person.3"
        case "thesis", "phdthesis", "mastersthesis": "graduationcap"
        case "online", "misc", "electronic", "www": "globe"
        case "techreport", "report", "manual": "doc.plaintext"
        case "bibitem": "list.bullet"
        default: "quote.opening"
        }
    }
}

/// Finds labels and bibliography entries in LaTeX and BibTeX sources.
nonisolated enum ReferenceScanner {
    private static let labelPattern = try! NSRegularExpression(pattern: #"\\label\s*\{([^{}]+)\}"#)
    private static let bibItemPattern = try! NSRegularExpression(pattern: #"\\bibitem\s*(?:\[[^\]]*\])?\s*\{([^{}]+)\}"#)
    private static let entryStartPattern = try! NSRegularExpression(pattern: #"@\s*([A-Za-z]+)\s*[{(]\s*([^,\s{}()]+)\s*,"#)
    private static let fieldPattern = try! NSRegularExpression(pattern: #"([A-Za-z]+)\s*=\s*"#)

    /// The `\label`s in `text`, outside comments.
    static func labels(in text: String, file: URL?) -> [LabelDefinition] {
        let string = text as NSString
        var results: [LabelDefinition] = []
        var line = 1
        var scanned = 0
        for match in labelPattern.matches(in: text, range: NSRange(location: 0, length: string.length)) {
            line += LineIndex.lineBreaks(in: string, range: NSRange(location: scanned, length: match.range.location - scanned)).count
            scanned = match.range.location
            let lineStart = string.lineRange(for: NSRange(location: match.range.location, length: 0)).location
            let prefix = string.substring(with: NSRange(location: lineStart, length: match.range.location - lineStart))
            guard LaTeXText.stripComment(prefix) == prefix else { continue }
            let key = string.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !key.contains("#") else { continue }
            results.append(LabelDefinition(key: key, file: file, line: line))
        }
        return results
    }

    /// The `\bibitem`s of a document's own bibliography.
    static func bibItems(in text: String) -> [BibEntry] {
        let string = text as NSString
        return bibItemPattern.matches(in: text, range: NSRange(location: 0, length: string.length)).map { match in
            // The text after the item, up to the next one, describes it.
            let start = NSMaxRange(match.range)
            let rest = string.substring(from: start)
            let description = rest.components(separatedBy: "\\bibitem").first ?? ""
            let clean = OutlineParser.cleanTitle(description.replacingOccurrences(of: "\n", with: " "))
            return BibEntry(
                key: string.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces),
                type: "bibitem",
                title: String(clean.prefix(160)),
                authors: "",
                year: "",
                file: nil
            )
        }
    }

    /// The entries of a BibTeX or BibLaTeX database.
    static func bibEntries(in text: String, file: URL?) -> [BibEntry] {
        let string = text as NSString
        var entries: [BibEntry] = []
        for match in entryStartPattern.matches(in: text, range: NSRange(location: 0, length: string.length)) {
            let type = string.substring(with: match.range(at: 1)).lowercased()
            guard type != "comment", type != "string", type != "preamble" else { continue }
            let key = string.substring(with: match.range(at: 2))
            let body = entryBody(after: NSMaxRange(match.range), in: string)
            let fields = self.fields(in: body)
            entries.append(BibEntry(
                key: key,
                type: type,
                title: fields["title"] ?? fields["booktitle"] ?? "",
                authors: fields["author"] ?? fields["editor"] ?? "",
                year: fields["year"] ?? fields["date"].map { String($0.prefix(4)) } ?? "",
                file: file
            ))
        }
        return entries
    }

    /// The text of an entry from its first field to its closing brace.
    private static func entryBody(after location: Int, in string: NSString) -> String {
        var depth = 1
        var index = location
        while index < string.length {
            let character = string.character(at: index)
            if character == Char.openBrace || character == Char.openParen {
                depth += 1
            } else if character == Char.closeBrace || character == Char.closeParen {
                depth -= 1
                if depth == 0 { break }
            }
            index += 1
        }
        return string.substring(with: NSRange(location: location, length: index - location))
    }

    /// `name = {value}`, `name = "value"` and `name = 2020` pairs, cleaned for display.
    private static func fields(in body: String) -> [String: String] {
        let string = body as NSString
        var fields: [String: String] = [:]
        for match in fieldPattern.matches(in: body, range: NSRange(location: 0, length: string.length)) {
            let name = string.substring(with: match.range(at: 1)).lowercased()
            var index = NSMaxRange(match.range)
            guard index < string.length else { continue }
            let opening = string.character(at: index)
            var value = ""
            if opening == Char.openBrace || opening == 0x22 {
                let closing: unichar = opening == Char.openBrace ? Char.closeBrace : 0x22
                var depth = 0
                let start = index + 1
                index += 1
                while index < string.length {
                    let character = string.character(at: index)
                    if character == Char.openBrace {
                        depth += 1
                    } else if character == closing && depth == 0 {
                        break
                    } else if character == Char.closeBrace {
                        depth -= 1
                    }
                    index += 1
                }
                value = string.substring(with: NSRange(location: start, length: min(index, string.length) - start))
            } else {
                let start = index
                while index < string.length, string.character(at: index) != Char.comma, string.character(at: index) != Char.newline {
                    index += 1
                }
                value = string.substring(with: NSRange(location: start, length: index - start))
            }
            if fields[name] == nil {
                fields[name] = clean(value)
            }
        }
        return fields
    }

    private static func clean(_ value: String) -> String {
        OutlineParser.cleanTitle(value.replacingOccurrences(of: "\n", with: " "))
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
