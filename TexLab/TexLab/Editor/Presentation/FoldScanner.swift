//
//  FoldScanner.swift
//  TexLab
//

import Foundation

/// A part of the source that can be collapsed in the editor: a multi-line environment,
/// the body of a section, the preamble or a block of comments.
nonisolated struct FoldableRegion: Sendable, Equatable {
    nonisolated enum Kind: Sendable, Equatable {
        /// `range` runs from `\begin{…}` to the end of the matching `\end{…}`.
        case environment
        /// `range` is the body after the heading line, which stays visible.
        case section(level: Int, command: String, title: String)
        /// `range` runs from the start of the file to the line before `\begin{document}`.
        case preamble
        /// Consecutive comment lines.
        case comments(firstLine: String)
    }

    var range: NSRange
    var kind: Kind = .environment
    /// The environment name, for environments.
    var environment: String
    /// The caption of a figure or table, as plain text.
    var caption: String?
    /// The first `\includegraphics` path in the environment, as written.
    var imagePath: String?
    var lineCount: Int

    var isFloat: Bool {
        kind == .environment && FoldScanner.floatEnvironments.contains(environment)
    }

    var isSection: Bool {
        if case .section = kind { return true }
        return false
    }

    /// What a collapsed region shows.
    var summary: String {
        switch kind {
        case .section:
            return "…"
        case .preamble:
            return String(localized: "Preamble")
        case .comments(let firstLine):
            return firstLine
        case .environment:
            return environmentSummary
        }
    }

    private var environmentSummary: String {
        switch environment {
        case "figure", "figure*", "wrapfigure", "subfigure":
            caption.map { String(localized: "Figure: \($0)") } ?? String(localized: "Figure")
        case "table", "table*":
            caption.map { String(localized: "Table: \($0)") } ?? String(localized: "Table")
        default:
            "\\begin{\(environment)} … \\end{\(environment)}"
        }
    }

    var systemImage: String {
        switch kind {
        case .section: return "text.alignleft"
        case .preamble: return "gearshape"
        case .comments: return "text.bubble"
        case .environment: return environmentSystemImage
        }
    }

    private var environmentSystemImage: String {
        switch environment {
        case "figure", "figure*", "wrapfigure", "subfigure": "photo"
        case "table", "table*", "tabular", "tabularx", "longtable": "tablecells"
        case "itemize", "enumerate", "description": "list.bullet"
        case "frame": "rectangle.on.rectangle"
        case "verbatim", "lstlisting", "minted": "chevron.left.forwardslash.chevron.right"
        default: LaTeXLanguage.mathEnvironments.contains(environment) ? "function" : "curlybraces"
        }
    }

    func shifted(by delta: Int) -> FoldableRegion {
        var copy = self
        copy.range.location += delta
        return copy
    }
}

/// Finds the environments that can be folded.
nonisolated enum FoldScanner {
    static let floatEnvironments: Set<String> = ["figure", "figure*", "table", "table*", "wrapfigure"]

    private static let environmentPattern = try! NSRegularExpression(pattern: #"\\(begin|end)\{([^{}\n]+)\}"#)
    private static let captionPattern = try! NSRegularExpression(pattern: #"\\caption(?:\[[^\]\n]*\])?\{"#)
    private static let graphicsPattern = try! NSRegularExpression(pattern: #"\\includegraphics\*?(?:\[[^\]]*\])?\{([^{}]+)\}"#)

    static func scan(_ text: String) -> [FoldableRegion] {
        let string = text as NSString
        var open: [(name: String, location: Int)] = []
        var regions: [FoldableRegion] = []

        for match in environmentPattern.matches(in: text, range: NSRange(location: 0, length: string.length)) {
            guard !isCommentedOut(match.range.location, in: string) else { continue }
            let isBegin = string.substring(with: match.range(at: 1)) == "begin"
            let name = string.substring(with: match.range(at: 2))
            guard name != "document" else { continue }
            if isBegin {
                open.append((name, match.range.location))
                continue
            }
            // Close the innermost environment with this name, discarding unclosed ones inside it.
            guard let index = open.lastIndex(where: { $0.name == name }) else { continue }
            let start = open[index].location
            open.removeSubrange(index...)
            let range = NSRange(location: start, length: NSMaxRange(match.range) - start)
            let body = string.substring(with: range)
            let lineCount = body.reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
            guard lineCount >= 2 else { continue }
            regions.append(FoldableRegion(
                range: range,
                environment: name,
                caption: firstBraceArgument(of: captionPattern, in: string, range: range).map(OutlineParser.cleanTitle),
                imagePath: firstCapture(of: graphicsPattern, in: string, range: range),
                lineCount: lineCount
            ))
        }
        regions += preambleRegion(in: string)
        regions += sectionRegions(in: string)
        regions += commentRegions(in: string)
        return regions.sorted { $0.range.location < $1.range.location }
    }

    // MARK: - Preamble

    /// Everything before `\begin{document}`, when it spans at least two lines.
    private static func preambleRegion(in string: NSString) -> [FoldableRegion] {
        let begin = string.range(of: "\\begin{document}")
        guard begin.location != NSNotFound else { return [] }
        var start = 0
        // Keep magic comments at the top visible; they choose the engine and root file.
        while start < begin.location {
            let line = string.lineRange(for: NSRange(location: start, length: 0))
            let text = string.substring(with: line).trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.hasPrefix("%") && text.lowercased().contains("!tex") || text.isEmpty else { break }
            start = NSMaxRange(line)
        }
        let end = trimmedEnd(before: begin.location, from: start, in: string)
        guard end > start else { return [] }
        let range = NSRange(location: start, length: end - start)
        let lineCount = lines(in: range, of: string)
        guard lineCount >= 2 else { return [] }
        return [FoldableRegion(range: range, kind: .preamble, environment: "", lineCount: lineCount)]
    }

    // MARK: - Sections

    static let sectionLevels: [String: Int] = [
        "part": 0, "chapter": 1, "section": 2, "subsection": 3, "subsubsection": 4, "paragraph": 5, "subparagraph": 6,
    ]
    private static let headingPattern = try! NSRegularExpression(
        pattern: #"^[ \t]*\\(part|chapter|section|subsection|subsubsection|paragraph|subparagraph)\*?\s*(?:\[[^\]\n]*\])?\{"#,
        options: [.anchorsMatchLines]
    )
    /// Lines that end every section: the end of the document and the bibliography.
    private static let sectionEndPattern = try! NSRegularExpression(
        pattern: #"^[ \t]*\\(?:end\{document\}|appendix\b|bibliography\{|printbibliography\b|begin\{thebibliography\})"#,
        options: [.anchorsMatchLines]
    )

    /// The body of each heading, from the end of its line to the next heading of the same or
    /// a higher level. The heading itself stays visible when collapsed.
    private static func sectionRegions(in string: NSString) -> [FoldableRegion] {
        let whole = NSRange(location: 0, length: string.length)
        let bodyStart = FormattingScanner.bodyStart(in: string)
        var headings: [(level: Int, command: String, title: String, lineEnd: Int, lineStart: Int)] = []
        for match in headingPattern.matches(in: string as String, range: whole) where match.range.location >= bodyStart {
            let command = string.substring(with: match.range(at: 1))
            guard let level = sectionLevels[command] else { continue }
            let line = string.lineRange(for: NSRange(location: match.range.location, length: 0))
            let title = firstBraceArgument(from: NSMaxRange(match.range), in: string, limit: string.length).map(OutlineParser.cleanTitle) ?? ""
            headings.append((level, command, title, line.location + contentLength(of: line, in: string), line.location))
        }
        guard !headings.isEmpty else { return [] }
        let ends = sectionEndPattern.matches(in: string as String, range: whole).map(\.range.location)

        var regions: [FoldableRegion] = []
        for (index, heading) in headings.enumerated() {
            var limit = string.length
            if let next = headings[(index + 1)...].first(where: { $0.level <= heading.level }) {
                limit = next.lineStart
            }
            if let end = ends.first(where: { $0 > heading.lineEnd && $0 < limit }) {
                limit = string.lineRange(for: NSRange(location: end, length: 0)).location
            }
            let end = trimmedEnd(before: limit, from: heading.lineEnd, in: string)
            guard end > heading.lineEnd else { continue }
            let range = NSRange(location: heading.lineEnd, length: end - heading.lineEnd)
            // The range starts with the heading's line break, so count the lines after it.
            let lineCount = lines(in: range, of: string) - 1
            guard lineCount >= 1 else { continue }
            regions.append(FoldableRegion(
                range: range,
                kind: .section(level: heading.level, command: heading.command, title: heading.title),
                environment: "",
                lineCount: lineCount
            ))
        }
        return regions
    }

    // MARK: - Comments

    /// Three or more consecutive lines that are only comments.
    private static func commentRegions(in string: NSString) -> [FoldableRegion] {
        var regions: [FoldableRegion] = []
        var blockStart: Int?
        var blockEnd = 0
        var count = 0
        var firstLine = ""
        var location = 0

        func finish() {
            if let start = blockStart, count >= 3 {
                regions.append(FoldableRegion(
                    range: NSRange(location: start, length: blockEnd - start),
                    kind: .comments(firstLine: firstLine),
                    environment: "",
                    lineCount: count
                ))
            }
            blockStart = nil
            count = 0
        }

        while location < string.length {
            let line = string.lineRange(for: NSRange(location: location, length: 0))
            let content = string.substring(with: NSRange(location: line.location, length: contentLength(of: line, in: string)))
            let trimmed = content.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("%") && !trimmed.lowercased().hasPrefix("% !tex") && !trimmed.lowercased().hasPrefix("%!tex") {
                if blockStart == nil {
                    blockStart = line.location
                    let text = trimmed.drop { $0 == "%" || $0 == " " }
                    firstLine = text.isEmpty ? "%" : "% " + text
                }
                blockEnd = line.location + contentLength(of: line, in: string)
                count += 1
            } else {
                finish()
            }
            location = NSMaxRange(line)
        }
        finish()
        return regions
    }

    // MARK: - Helpers

    /// The end of the last non-blank line before `limit`, and not before `start`.
    private static func trimmedEnd(before limit: Int, from start: Int, in string: NSString) -> Int {
        var end = limit
        while end > start, Char.isWhitespace(string.character(at: end - 1)) {
            end -= 1
        }
        return end
    }

    private static func lines(in range: NSRange, of string: NSString) -> Int {
        string.substring(with: range).reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
    }

    private static func contentLength(of line: NSRange, in string: NSString) -> Int {
        var length = line.length
        while length > 0 {
            let character = string.character(at: line.location + length - 1)
            guard character == Char.newline || character == Char.carriageReturn else { break }
            length -= 1
        }
        return length
    }

    /// The balanced brace argument starting at `location`, just after its `{`.
    private static func firstBraceArgument(from location: Int, in string: NSString, limit: Int) -> String? {
        var depth = 1
        var index = location
        while index < limit {
            let character = string.character(at: index)
            if character == Char.backslash {
                index += 2
                continue
            }
            if character == Char.openBrace {
                depth += 1
            } else if character == Char.closeBrace {
                depth -= 1
                if depth == 0 {
                    return string.substring(with: NSRange(location: location, length: index - location))
                }
            } else if character == Char.newline && index > location && string.character(at: index - 1) == Char.newline {
                return nil
            }
            index += 1
        }
        return nil
    }

    private static func firstCapture(of pattern: NSRegularExpression, in string: NSString, range: NSRange) -> String? {
        guard let match = pattern.firstMatch(in: string as String, range: range) else { return nil }
        return string.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
    }

    /// The balanced brace argument following a match of `pattern`, which ends with `{`.
    private static func firstBraceArgument(of pattern: NSRegularExpression, in string: NSString, range: NSRange) -> String? {
        guard let match = pattern.firstMatch(in: string as String, range: range) else { return nil }
        var depth = 1
        var index = NSMaxRange(match.range)
        let start = index
        while index < NSMaxRange(range) {
            let character = string.character(at: index)
            if character == Char.backslash {
                index += 2
                continue
            }
            if character == Char.openBrace {
                depth += 1
            } else if character == Char.closeBrace {
                depth -= 1
                if depth == 0 {
                    let caption = string.substring(with: NSRange(location: start, length: index - start))
                    return caption.isEmpty ? nil : caption
                }
            }
            index += 1
        }
        return nil
    }

    private static func isCommentedOut(_ location: Int, in string: NSString) -> Bool {
        let lineStart = string.lineRange(for: NSRange(location: location, length: 0)).location
        guard location > lineStart else { return false }
        let prefix = string.substring(with: NSRange(location: lineStart, length: location - lineStart))
        return LaTeXText.stripComment(prefix) != prefix
    }
}
