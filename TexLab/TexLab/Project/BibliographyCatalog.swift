//
//  BibliographyCatalog.swift
//  TexLab
//

import Foundation

/// What the Visual bibliography editor knows about BibTeX and biblatex: each kind of entry
/// with a name to read and the fields it needs, and a readable name for each field — the
/// way Xcode shows "Bundle display name" for `CFBundleDisplayName`.
nonisolated enum BibliographyCatalog {
    struct EntryType: Identifiable, Sendable {
        /// As BibTeX writes it, such as `inproceedings`.
        let name: String
        let title: String
        let systemImage: String
        /// The fields the entry needs; each group is met by any one of its fields — an
        /// author or an editor, say.
        let required: [[String]]
        /// Fields it often has.
        let optional: [String]

        var id: String { name }
    }

    static let types: [EntryType] = [
        EntryType(name: "article", title: String(localized: "Journal Article"), systemImage: "doc.text",
                  required: [["author"], ["title"], ["journal", "journaltitle"], ["year", "date"]],
                  optional: ["volume", "number", "pages", "month", "doi", "url", "note"]),
        EntryType(name: "book", title: String(localized: "Book"), systemImage: "book.closed",
                  required: [["author", "editor"], ["title"], ["publisher"], ["year", "date"]],
                  optional: ["edition", "volume", "series", "address", "month", "isbn", "doi", "url", "note"]),
        EntryType(name: "inproceedings", title: String(localized: "Conference Paper"), systemImage: "person.3",
                  required: [["author"], ["title"], ["booktitle"], ["year", "date"]],
                  optional: ["editor", "pages", "organization", "publisher", "address", "month", "volume", "series", "doi", "url", "note"]),
        EntryType(name: "incollection", title: String(localized: "Chapter in an Edited Book"), systemImage: "books.vertical",
                  required: [["author"], ["title"], ["booktitle"], ["publisher"], ["year", "date"]],
                  optional: ["editor", "chapter", "pages", "edition", "volume", "series", "address", "month", "doi", "url", "note"]),
        EntryType(name: "inbook", title: String(localized: "Part of a Book"), systemImage: "book",
                  required: [["author", "editor"], ["title"], ["chapter", "pages"], ["publisher"], ["year", "date"]],
                  optional: ["edition", "volume", "series", "address", "month", "url", "note"]),
        EntryType(name: "online", title: String(localized: "Website"), systemImage: "globe",
                  required: [["title"], ["url"]],
                  optional: ["author", "organization", "year", "urldate", "note"]),
        EntryType(name: "phdthesis", title: String(localized: "PhD Thesis"), systemImage: "graduationcap",
                  required: [["author"], ["title"], ["school", "institution"], ["year", "date"]],
                  optional: ["type", "address", "month", "url", "note"]),
        EntryType(name: "mastersthesis", title: String(localized: "Master’s Thesis"), systemImage: "graduationcap",
                  required: [["author"], ["title"], ["school", "institution"], ["year", "date"]],
                  optional: ["type", "address", "month", "url", "note"]),
        EntryType(name: "techreport", title: String(localized: "Technical Report"), systemImage: "doc.plaintext",
                  required: [["author"], ["title"], ["institution"], ["year", "date"]],
                  optional: ["type", "number", "address", "month", "url", "note"]),
        EntryType(name: "manual", title: String(localized: "Manual"), systemImage: "wrench.and.screwdriver",
                  required: [["title"]],
                  optional: ["author", "organization", "edition", "address", "month", "year", "url", "note"]),
        EntryType(name: "proceedings", title: String(localized: "Conference Proceedings"), systemImage: "books.vertical",
                  required: [["title"], ["year", "date"]],
                  optional: ["editor", "publisher", "organization", "volume", "series", "address", "month", "note"]),
        EntryType(name: "booklet", title: String(localized: "Booklet"), systemImage: "book.pages",
                  required: [["title"]],
                  optional: ["author", "howpublished", "address", "month", "year", "note"]),
        EntryType(name: "unpublished", title: String(localized: "Unpublished Work"), systemImage: "doc.badge.clock",
                  required: [["author"], ["title"], ["note"]],
                  optional: ["month", "year", "url"]),
        EntryType(name: "software", title: String(localized: "Software"), systemImage: "chevron.left.forwardslash.chevron.right",
                  required: [["title"]],
                  optional: ["author", "version", "publisher", "year", "url", "doi", "note"]),
        EntryType(name: "dataset", title: String(localized: "Dataset"), systemImage: "tablecells",
                  required: [["title"]],
                  optional: ["author", "version", "publisher", "year", "doi", "url", "note"]),
        EntryType(name: "misc", title: String(localized: "Other"), systemImage: "doc",
                  required: [],
                  optional: ["author", "title", "howpublished", "month", "year", "url", "note"]),
    ]

    /// Other names for the same kinds of entry.
    private static let aliases = [
        "conference": "inproceedings", "electronic": "online", "www": "online", "thesis": "phdthesis",
        "report": "techreport", "collection": "proceedings", "periodical": "article",
    ]

    static func type(_ name: String) -> EntryType? {
        let name = name.lowercased()
        let canonical = aliases[name] ?? name
        return types.first { $0.name == canonical }
    }

    static func title(ofType name: String) -> String {
        type(name)?.title ?? name.capitalized
    }

    static func systemImage(ofType name: String) -> String {
        type(name)?.systemImage ?? "doc"
    }

    /// The required fields `entry` doesn't have yet: the first of each group none of whose
    /// fields it has.
    static func missingFields(of entry: BibliographyEntry) -> [String] {
        guard let type = type(entry.type) else { return [] }
        let present = Set(entry.fields.map(\.name))
        return type.required.compactMap { group in
            group.contains(where: present.contains) ? nil : group.first
        }
    }

    /// Whether `field` is one `type` needs.
    static func isRequired(_ field: String, inType name: String) -> Bool {
        type(name)?.required.contains { $0.contains(field) } ?? false
    }

    /// Fields to offer adding to `entry`: its type's, then others in common use.
    static func suggestedFields(for entry: BibliographyEntry) -> [String] {
        let present = Set(entry.fields.map(\.name))
        let own = (type(entry.type).map { $0.required.flatMap { $0 } + $0.optional } ?? [])
        var seen: Set<String> = []
        return (own + commonFields).filter { !present.contains($0) && seen.insert($0).inserted }
    }

    static let commonFields = [
        "author", "editor", "title", "subtitle", "year", "date", "month", "publisher", "address",
        "journal", "booktitle", "volume", "number", "pages", "edition", "series", "chapter",
        "organization", "institution", "school", "howpublished", "doi", "url", "urldate",
        "isbn", "issn", "eprint", "archiveprefix", "language", "keywords", "abstract", "note",
    ]

    // MARK: - Fields

    private static let fieldTitles: [String: String] = [
        "author": String(localized: "Authors"),
        "editor": String(localized: "Editors"),
        "translator": String(localized: "Translators"),
        "title": String(localized: "Title"),
        "subtitle": String(localized: "Subtitle"),
        "shorttitle": String(localized: "Short Title"),
        "journal": String(localized: "Journal"),
        "journaltitle": String(localized: "Journal"),
        "booktitle": String(localized: "Book Title"),
        "publisher": String(localized: "Publisher"),
        "address": String(localized: "Place"),
        "location": String(localized: "Place"),
        "year": String(localized: "Year"),
        "date": String(localized: "Date"),
        "month": String(localized: "Month"),
        "volume": String(localized: "Volume"),
        "number": String(localized: "Number"),
        "pages": String(localized: "Pages"),
        "eid": String(localized: "Article Number"),
        "edition": String(localized: "Edition"),
        "series": String(localized: "Series"),
        "chapter": String(localized: "Chapter"),
        "school": String(localized: "School"),
        "institution": String(localized: "Institution"),
        "organization": String(localized: "Organization"),
        "howpublished": String(localized: "How Published"),
        "note": String(localized: "Note"),
        "annote": String(localized: "Annotation"),
        "url": String(localized: "URL"),
        "urldate": String(localized: "Visited"),
        "doi": String(localized: "DOI"),
        "isbn": String(localized: "ISBN"),
        "issn": String(localized: "ISSN"),
        "eprint": String(localized: "e-Print"),
        "archiveprefix": String(localized: "Archive"),
        "primaryclass": String(localized: "Category"),
        "abstract": String(localized: "Abstract"),
        "keywords": String(localized: "Keywords"),
        "type": String(localized: "Kind"),
        "language": String(localized: "Language"),
        "version": String(localized: "Version"),
        "file": String(localized: "File"),
        "crossref": String(localized: "Cross-reference"),
        "key": String(localized: "Sort Key"),
    ]

    /// "Authors" for `author`, as the editor shows a field.
    static func fieldTitle(_ name: String) -> String {
        fieldTitles[name] ?? name.prefix(1).uppercased() + name.dropFirst()
    }

    /// What kind of value a field holds, for the Type column.
    static func fieldKind(_ name: String) -> String {
        switch name {
        case "author", "editor", "translator": String(localized: "Names")
        case "year", "volume", "number", "edition", "chapter", "eid": String(localized: "Number")
        case "date", "urldate", "month": String(localized: "Date")
        case "pages": String(localized: "Range")
        case "url": String(localized: "Link")
        case "doi", "isbn", "issn", "eprint": String(localized: "Identifier")
        default: String(localized: "Text")
        }
    }

    /// How to write a field's value, where it isn't obvious.
    static func fieldHelp(_ name: String) -> String? {
        switch name {
        case "author", "editor", "translator":
            String(localized: "Separate names with “and”: Knuth, Donald E. and Lamport, Leslie")
        case "pages":
            String(localized: "A page or a range, such as 12--34")
        case "date", "urldate":
            String(localized: "Year, month and day, such as 2026-10-19")
        case "doi":
            String(localized: "The DOI alone, such as 10.1000/xyz123, without https://doi.org/")
        case "title":
            String(localized: "Braces keep capitals as typed: {LaTeX} for {Apple}")
        default:
            nil
        }
    }

    /// The web address a field's value points to, if it has one.
    static func link(forField name: String, value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        switch name {
        case "url":
            return URL(string: trimmed).flatMap { $0.scheme == nil ? nil : $0 }
        case "doi":
            guard !trimmed.isEmpty else { return nil }
            let doi = trimmed.replacingOccurrences(of: "https://doi.org/", with: "")
            return URL(string: "https://doi.org/" + (doi.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? doi))
        default:
            return nil
        }
    }

    // MARK: - Reading LaTeX

    private static let accentPattern = try! NSRegularExpression(pattern: #"\{?\\([\"'`^~=.]|[cvuHkr](?=[\s{]))\s*\{?([A-Za-z]|\\i)\}?\}?"#)
    private static let accents: [String: String] = [
        "\"": "\u{0308}", "'": "\u{0301}", "`": "\u{0300}", "^": "\u{0302}", "~": "\u{0303}", "=": "\u{0304}",
        ".": "\u{0307}", "c": "\u{0327}", "v": "\u{030C}", "u": "\u{0306}", "H": "\u{030B}", "k": "\u{0328}", "r": "\u{030A}",
    ]
    private static let letters: [(String, String)] = [
        ("\\ss", "ß"), ("\\aa", "å"), ("\\AA", "Å"), ("\\ae", "æ"), ("\\AE", "Æ"), ("\\oe", "œ"), ("\\OE", "Œ"),
        ("\\o", "ø"), ("\\O", "Ø"), ("\\l", "ł"), ("\\L", "Ł"),
    ]

    /// A value with its LaTeX simplified for reading: accents as accented letters, `--` as
    /// a dash, and braces and commands gone.
    static func readable(_ value: String) -> String {
        let string = value as NSString
        var result = ""
        var location = 0
        for match in accentPattern.matches(in: value, range: NSRange(location: 0, length: string.length)) {
            result += string.substring(with: NSRange(location: location, length: match.range.location - location))
            let accent = string.substring(with: match.range(at: 1))
            var letter = string.substring(with: match.range(at: 2))
            if letter == "\\i" {
                letter = "i"
            }
            result += letter + (accents[accent] ?? "")
            location = NSMaxRange(match.range)
        }
        result += string.substring(from: location)
        for (command, letter) in letters {
            result = result.replacingOccurrences(of: "{\(command)}", with: letter)
                .replacingOccurrences(of: "\(command){}", with: letter)
                .replacingOccurrences(of: "\(command) ", with: letter)
        }
        result = result
            .replacingOccurrences(of: "\\BibTeX", with: "BibTeX")
            .replacingOccurrences(of: "\\LaTeX", with: "LaTeX")
            .replacingOccurrences(of: "\\TeX", with: "TeX")
            .replacingOccurrences(of: "---", with: "—")
            .replacingOccurrences(of: "--", with: "–")
            .replacingOccurrences(of: "\\&", with: "&")
            .replacingOccurrences(of: "\\%", with: "%")
            .replacingOccurrences(of: "\\$", with: "$")
            .replacingOccurrences(of: "\\_", with: "_")
        return OutlineParser.cleanTitle(result).precomposedStringWithCanonicalMapping
    }
}
