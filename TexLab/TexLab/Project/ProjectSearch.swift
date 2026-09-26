//
//  ProjectSearch.swift
//  TexLab
//

import Foundation

/// A line that matches a project search.
nonisolated struct SearchMatch: Identifiable, Hashable, Sendable {
    /// Where the match is: the file (nil for the document being edited) and its offset.
    var file: URL?
    var location: Int
    var length: Int
    /// 1-based.
    var line: Int
    /// The line, trimmed, and the match's range within it.
    var preview: String
    var previewMatch: Range<String.Index>

    var id: String { "\(file?.path(percentEncoded: false) ?? "")#\(location)" }
}

/// The matches in one file.
nonisolated struct SearchFileResult: Identifiable, Hashable, Sendable {
    var file: URL?
    var name: String
    var matches: [SearchMatch]

    var id: String { file?.path(percentEncoded: false) ?? "" }
}

/// Options for a project search.
nonisolated struct SearchOptions: Equatable, Sendable {
    var matchesCase = false
    var wholeWords = false
}

/// Searches the text files of a project: LaTeX, bibliographies, packages and plain text.
nonisolated enum ProjectSearch {
    static let maximumMatches = 2000

    /// Searches `sources` — each a file and, for open documents, its current text.
    static func run(_ query: String, options: SearchOptions, sources: [(file: URL?, name: String, text: String?)]) -> [SearchFileResult] {
        guard !query.isEmpty else { return [] }
        var pattern = NSRegularExpression.escapedPattern(for: query)
        if options.wholeWords {
            pattern = "(?<![\\p{L}\\p{N}_])" + pattern + "(?![\\p{L}\\p{N}_])"
        }
        guard let expression = try? NSRegularExpression(pattern: pattern, options: options.matchesCase ? [] : [.caseInsensitive]) else { return [] }

        var results: [SearchFileResult] = []
        var total = 0
        for source in sources {
            guard total < maximumMatches, let text = source.text ?? source.file.flatMap(ProjectIndex.contents(of:)) else { continue }
            let string = text as NSString
            var matches: [SearchMatch] = []
            var line = 1
            var scanned = 0
            for match in expression.matches(in: text, range: NSRange(location: 0, length: string.length)) {
                guard total < maximumMatches else { break }
                line += LineIndex.lineBreaks(in: string, range: NSRange(location: scanned, length: match.range.location - scanned)).count
                scanned = match.range.location
                let lineRange = string.lineRange(for: match.range)
                let rawLine = string.substring(with: lineRange)
                let leading = rawLine.prefix { $0 == " " || $0 == "\t" }.utf16.count
                let content = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                let offset = match.range.location - lineRange.location - leading
                let preview = content as NSString
                guard offset >= 0, offset + match.range.length <= preview.length,
                      let range = Range(NSRange(location: offset, length: match.range.length), in: content) else { continue }
                matches.append(SearchMatch(
                    file: source.file,
                    location: match.range.location,
                    length: match.range.length,
                    line: line,
                    preview: content,
                    previewMatch: range
                ))
                total += 1
            }
            if !matches.isEmpty {
                results.append(SearchFileResult(file: source.file, name: source.name, matches: matches))
            }
        }
        return results
    }
}
