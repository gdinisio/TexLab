//
//  Bibliography.swift
//  TexLab
//

import Foundation

/// A BibTeX database as the Visual editor shows it: its entries in file order, with where
/// each one's type, key and fields are in the text, so an edit changes only what it must
/// and the rest of the file — comments, layout, abbreviations — stays as it was.
nonisolated struct BibliographyFile: Sendable, Equatable {
    var entries: [BibliographyEntry] = []
    /// `@string` abbreviations, which values can use bare, such as `jgr`.
    var macros: Set<String> = []
    /// How many `@string`, `@preamble` and `@comment` blocks the file has, which the Code
    /// editor edits.
    var otherBlockCount = 0
}

nonisolated struct BibliographyEntry: Sendable, Equatable, Identifiable {
    /// The entry's position among the file's entries.
    var id: Int
    /// As written, such as `article` or `Book`.
    var type: String
    var typeRange: NSRange
    var key: String
    /// Where the key is; empty, just after the opening brace, for an entry without one.
    var keyRange: NSRange
    /// From the `@` to the closing brace.
    var range: NSRange
    var fields: [BibliographyField]
    /// Whether the entry ends properly. One that doesn't is left to the Code editor.
    var isComplete: Bool

    var normalizedType: String { type.lowercased() }

    func field(_ name: String) -> BibliographyField? {
        fields.first { $0.name == name }
    }

    /// A field's value with its LaTeX simplified for reading, or nil if it isn't there.
    func display(_ name: String) -> String? {
        field(name).map { BibliographyCatalog.readable($0.value) }.flatMap { $0.isEmpty ? nil : $0 }
    }

    /// "Knuth · 1984 · The TeXbook", for the entry's row.
    var summary: String {
        let names = (display("author") ?? display("editor") ?? display("organization") ?? "")
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
        let year = display("year") ?? display("date").map { String($0.prefix(4)) } ?? ""
        let title = display("title") ?? display("booktitle") ?? ""
        return [who, year, title].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

nonisolated struct BibliographyField: Sendable, Equatable, Identifiable {
    nonisolated enum Delimiter: Sendable, Equatable {
        case braces
        case quotes
        /// A number, an abbreviation, or several parts joined with `#`.
        case bare
    }

    /// Lowercased, such as `author`.
    var name: String
    var nameRange: NSRange
    /// What the editor shows and edits: the text inside the braces or quotes, or the whole
    /// value as written when it's bare or joined from parts.
    var value: String
    /// The whole value, delimiters included.
    var valueRange: NSRange
    /// What `value` is: inside the delimiters, or the whole value.
    var contentRange: NSRange
    var delimiter: Delimiter
    /// From the name to the end of the value.
    var range: NSRange

    var id: String { name }
}

/// One change to the text of a bibliography.
nonisolated struct BibliographyEdit: Sendable, Equatable {
    var range: NSRange
    var text: String
}

// MARK: - Reading

extension BibliographyFile {
    /// Reads `text` as BibTeX: `@type{key, field = value, …}` or with parentheses, values in
    /// braces, quotes or bare, joined with `#`. Text between entries is a comment, as BibTeX
    /// has it.
    static func parse(_ text: String) -> BibliographyFile {
        var parser = BibliographyParser(string: text as NSString)
        return parser.parse()
    }
}

nonisolated private struct BibliographyParser {
    let string: NSString
    var index = 0
    var file = BibliographyFile()

    init(string: NSString) {
        self.string = string
    }

    private var length: Int { string.length }

    private func character(_ location: Int) -> unichar {
        string.character(at: location)
    }

    private static let atSign: unichar = 0x40
    private static let openParenthesis: unichar = 0x28
    private static let closeParenthesis: unichar = 0x29
    private static let comma: unichar = 0x2C
    private static let equals: unichar = 0x3D
    private static let quote: unichar = 0x22
    private static let hash: unichar = 0x23

    mutating func parse() -> BibliographyFile {
        while index < length {
            guard character(index) == Self.atSign else {
                index += 1
                continue
            }
            let start = index
            index += 1
            skipWhitespace()
            let typeStart = index
            while index < length, isIdentifier(character(index)) {
                index += 1
            }
            let typeRange = NSRange(location: typeStart, length: index - typeStart)
            guard typeRange.length > 0 else { continue }
            let type = string.substring(with: typeRange)
            skipWhitespace()
            guard index < length, character(index) == Char.openBrace || character(index) == Self.openParenthesis else { continue }
            let closing = character(index) == Char.openBrace ? Char.closeBrace : Self.closeParenthesis
            index += 1

            switch type.lowercased() {
            case "comment", "preamble", "string":
                let bodyStart = index
                let end = skipBalanced(until: closing)
                if type.lowercased() == "string" {
                    let body = string.substring(with: NSRange(location: bodyStart, length: max(end - bodyStart, 0)))
                    if let name = body.split(separator: "=").first?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                        file.macros.insert(name.lowercased())
                    }
                }
                file.otherBlockCount += 1
                continue
            default:
                break
            }

            // The key: up to the comma, or the end of an entry without fields.
            skipWhitespace()
            let keyStart = index
            while index < length, character(index) != Self.comma, character(index) != closing, !Char.isWhitespace(character(index)) {
                index += 1
            }
            let keyRange = NSRange(location: keyStart, length: index - keyStart)
            var fields: [BibliographyField] = []
            var isComplete = false

            while index < length {
                skipWhitespace()
                guard index < length else { break }
                let c = character(index)
                if c == closing {
                    index += 1
                    isComplete = true
                    break
                }
                if c == Self.comma {
                    index += 1
                    continue
                }
                if c == Self.atSign {
                    // The next entry: this one never ended.
                    break
                }
                guard let field = parseField(closing: closing) else {
                    // Not a field: give up on this entry, and look for the next one.
                    break
                }
                fields.append(field)
            }
            file.entries.append(BibliographyEntry(
                id: file.entries.count,
                type: type,
                typeRange: typeRange,
                key: string.substring(with: keyRange),
                keyRange: keyRange,
                range: NSRange(location: start, length: index - start),
                fields: fields,
                isComplete: isComplete
            ))
        }
        return file
    }

    private mutating func parseField(closing: unichar) -> BibliographyField? {
        let nameStart = index
        while index < length, isIdentifier(character(index)) || character(index) == 0x2D || character(index) == 0x2E || character(index) == 0x3A {
            index += 1
        }
        let nameRange = NSRange(location: nameStart, length: index - nameStart)
        guard nameRange.length > 0 else { return nil }
        skipWhitespace()
        guard index < length, character(index) == Self.equals else { return nil }
        index += 1
        skipWhitespace()

        // The value: one or more parts joined with #.
        let valueStart = index
        var parts: [(range: NSRange, delimiter: BibliographyField.Delimiter)] = []
        while index < length {
            let partStart = index
            let c = character(index)
            if c == Char.openBrace {
                index += 1
                // An unclosed brace runs to the end of the text, and no further.
                let end = min(skipBalanced(until: Char.closeBrace) + 1, length)
                parts.append((NSRange(location: partStart, length: end - partStart), .braces))
            } else if c == Self.quote {
                index += 1
                var depth = 0
                while index < length {
                    let d = character(index)
                    if d == Char.backslash {
                        index += 2
                        continue
                    }
                    if d == Char.openBrace { depth += 1 }
                    if d == Char.closeBrace { depth -= 1 }
                    if d == Self.quote && depth <= 0 { break }
                    index += 1
                }
                index = min(index + 1, length)
                parts.append((NSRange(location: partStart, length: index - partStart), .quotes))
            } else {
                while index < length {
                    let d = character(index)
                    if d == Self.comma || d == closing || d == Self.hash || Char.isWhitespace(d) { break }
                    index += 1
                }
                guard index > partStart else { break }
                parts.append((NSRange(location: partStart, length: index - partStart), .bare))
            }
            let afterPart = index
            skipWhitespace()
            if index < length, character(index) == Self.hash {
                index += 1
                skipWhitespace()
                continue
            }
            index = afterPart
            break
        }
        guard let first = parts.first, let last = parts.last else { return nil }
        let valueRange = NSRange(location: valueStart, length: NSMaxRange(last.range) - valueStart)
        let delimiter: BibliographyField.Delimiter = parts.count == 1 ? first.delimiter : .bare
        let contentRange = delimiter == .bare
            ? valueRange
            : NSRange(location: first.range.location + 1, length: max(first.range.length - 2, 0))
        return BibliographyField(
            name: string.substring(with: nameRange).lowercased(),
            nameRange: nameRange,
            value: string.substring(with: contentRange),
            valueRange: valueRange,
            contentRange: contentRange,
            delimiter: delimiter,
            range: NSRange(location: nameStart, length: NSMaxRange(valueRange) - nameStart)
        )
    }

    /// Skips to the `closing` character that ends the group just opened, past nested braces
    /// and escaped characters, and returns where it is (the end of the text if there's none).
    private mutating func skipBalanced(until closing: unichar) -> Int {
        var depth = 0
        while index < length {
            let c = character(index)
            if c == Char.backslash {
                index += 2
                continue
            }
            if c == closing && depth == 0 {
                let end = index
                index += 1
                return end
            }
            if c == Char.openBrace { depth += 1 }
            if c == Char.closeBrace { depth -= 1 }
            index += 1
        }
        index = length
        return length
    }

    private mutating func skipWhitespace() {
        while index < length, Char.isWhitespace(character(index)) {
            index += 1
        }
    }

    private func isIdentifier(_ c: unichar) -> Bool {
        (c >= 0x30 && c <= 0x39) || (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == 0x5F
    }
}

// MARK: - Editing

extension BibliographyFile {
    /// Gives `field` a new value, keeping its braces or quotes; a bare value stays bare if
    /// it's a number or an abbreviation, and gets braces otherwise.
    func setting(_ value: String, of field: BibliographyField) -> BibliographyEdit {
        switch field.delimiter {
        case .braces:
            return BibliographyEdit(range: field.contentRange, text: value)
        case .quotes where !Self.hasUnbracedQuote(value):
            return BibliographyEdit(range: field.contentRange, text: value)
        default:
            return BibliographyEdit(range: field.valueRange, text: formatted(value))
        }
    }

    /// A new value as BibTeX: bare for a number or an abbreviation, in braces otherwise.
    func formatted(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, trimmed.allSatisfy(\.isNumber) || macros.contains(trimmed.lowercased()) || Self.months.contains(trimmed.lowercased()) {
            return trimmed
        }
        return "{\(value)}"
    }

    /// Adds `name = {value}` as the entry's last field, on a line of its own, indented like
    /// the others.
    func adding(_ name: String, value: String, to entry: BibliographyEntry, in text: NSString) -> BibliographyEdit {
        let indent = fieldIndent(of: entry, in: text)
        // Line the = up with the other fields' if they're lined up.
        var label = name + " "
        if let column = equalsColumn(of: entry, in: text), column > name.count {
            label = name.padding(toLength: column, withPad: " ", startingAt: 0)
        }
        let field = "\(label)= \(formatted(value))"
        if let last = entry.fields.last {
            return BibliographyEdit(range: NSRange(location: NSMaxRange(last.range), length: 0), text: ",\n\(indent)\(field)")
        }
        // No fields yet: after the key's comma, or after the key.
        var location = NSMaxRange(entry.keyRange)
        while location < text.length, Char.isWhitespace(text.character(at: location)) {
            location += 1
        }
        if location < text.length, text.character(at: location) == 0x2C {
            return BibliographyEdit(range: NSRange(location: location + 1, length: 0), text: "\n\(indent)\(field),")
        }
        return BibliographyEdit(range: NSRange(location: NSMaxRange(entry.keyRange), length: 0), text: ",\n\(indent)\(field)\n")
    }

    /// Removes a field, with the comma and line break before it.
    func removing(_ field: BibliographyField, from entry: BibliographyEntry) -> BibliographyEdit {
        guard let index = entry.fields.firstIndex(of: field) else { return BibliographyEdit(range: NSRange(location: field.range.location, length: 0), text: "") }
        let start = index > 0 ? NSMaxRange(entry.fields[index - 1].range) : NSMaxRange(entry.keyRange)
        return BibliographyEdit(range: NSRange(location: start, length: NSMaxRange(field.range) - start), text: "")
    }

    func settingType(_ type: String, of entry: BibliographyEntry) -> BibliographyEdit {
        BibliographyEdit(range: entry.typeRange, text: type)
    }

    func settingKey(_ key: String, of entry: BibliographyEntry) -> BibliographyEdit {
        BibliographyEdit(range: entry.keyRange, text: key)
    }

    /// A new entry at the end of the file, with its required fields left to fill in.
    func appending(type: String, key: String, to text: NSString) -> BibliographyEdit {
        // A blank line after what's there.
        var prefix = ""
        if text.length > 0 {
            prefix = text.character(at: text.length - 1) == Char.newline ? "\n" : "\n\n"
        }
        return BibliographyEdit(range: NSRange(location: text.length, length: 0), text: "\(prefix)@\(type){\(key),\n}\n")
    }

    /// Removes an entry, with the blank line after it.
    func removing(_ entry: BibliographyEntry, in text: NSString) -> BibliographyEdit {
        var end = NSMaxRange(entry.range)
        var newlines = 0
        while end < text.length, Char.isWhitespace(text.character(at: end)), newlines < 2 {
            if text.character(at: end) == Char.newline {
                newlines += 1
            }
            end += 1
        }
        return BibliographyEdit(range: NSRange(location: entry.range.location, length: end - entry.range.location), text: "")
    }

    /// A copy of an entry just after it, with a key of its own.
    func duplicating(_ entry: BibliographyEntry, in text: NSString) -> BibliographyEdit {
        var copy = text.substring(with: entry.range)
        let key = uniqueKey(entry.key.isEmpty ? "copy" : entry.key + "-copy")
        let keyStart = entry.keyRange.location - entry.range.location
        copy = (copy as NSString).replacingCharacters(in: NSRange(location: keyStart, length: entry.keyRange.length), with: key)
        return BibliographyEdit(range: NSRange(location: NSMaxRange(entry.range), length: 0), text: "\n\n" + copy)
    }

    /// `base`, or `base-2`, `base-3`… if another entry has it.
    func uniqueKey(_ base: String) -> String {
        let keys = Set(entries.map { $0.key.lowercased() })
        guard keys.contains(base.lowercased()) else { return base }
        var number = 2
        while keys.contains("\(base)-\(number)".lowercased()) {
            number += 1
        }
        return "\(base)-\(number)"
    }

    /// Why `key` won't do as an entry's citation key, or nil if it will.
    func problem(withKey key: String, for entry: BibliographyEntry) -> String? {
        if key.isEmpty {
            return String(localized: "An entry needs a key to be cited.")
        }
        if key.contains(where: { $0.isWhitespace || ",{}()\"#%~'=\\".contains($0) }) {
            return String(localized: "A key can’t contain spaces or any of , { } ( ) \" # % ~ ' = \\")
        }
        if entries.contains(where: { $0.id != entry.id && $0.key.lowercased() == key.lowercased() }) {
            return String(localized: "Another entry already has the key “\(key)”.")
        }
        return nil
    }

    /// Why `value` can't be written as it is, or nil if it can.
    static func problem(withValue value: String) -> String? {
        var depth = 0
        var previousWasBackslash = false
        for character in value {
            if !previousWasBackslash {
                if character == "{" { depth += 1 }
                if character == "}" { depth -= 1 }
                if depth < 0 { break }
            }
            previousWasBackslash = character == "\\" && !previousWasBackslash
        }
        return depth == 0 ? nil : String(localized: "The braces { } don’t match.")
    }

    /// How far after its name each field's = is, if it's the same for every field and
    /// more than one space: the fields are lined up.
    private func equalsColumn(of entry: BibliographyEntry, in text: NSString) -> Int? {
        let columns = Set(entry.fields.map { field -> Int in
            let between = NSRange(location: NSMaxRange(field.nameRange), length: field.valueRange.location - NSMaxRange(field.nameRange))
            let equals = text.range(of: "=", range: between)
            return equals.location == NSNotFound ? -1 : equals.location - field.nameRange.location
        })
        guard entry.fields.count > 1, columns.count == 1, let column = columns.first,
              column > (entry.fields.map(\.name.count).max() ?? 0) else { return nil }
        return column
    }

    private func fieldIndent(of entry: BibliographyEntry, in text: NSString) -> String {
        guard let first = entry.fields.first else { return "  " }
        let lineStart = text.lineRange(for: NSRange(location: first.range.location, length: 0)).location
        let before = text.substring(with: NSRange(location: lineStart, length: first.range.location - lineStart))
        return before.allSatisfy({ $0 == " " || $0 == "\t" }) && !before.isEmpty ? before : "  "
    }

    private static let months: Set<String> = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]

    /// Whether a quote in `value` would end a quoted value early.
    private static func hasUnbracedQuote(_ value: String) -> Bool {
        var depth = 0
        for character in value {
            if character == "{" { depth += 1 }
            if character == "}" { depth -= 1 }
            if character == "\"" && depth == 0 { return true }
        }
        return false
    }
}
