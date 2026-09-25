//
//  OutlineParser.swift
//  TexLab
//

import Foundation

/// An entry in the document outline: a heading, a Beamer frame, or a captioned float.
nonisolated struct OutlineItem: Identifiable, Hashable, Sendable {
    nonisolated enum Kind: Int, Sendable {
        case part, chapter, section, subsection, subsubsection, paragraph, subparagraph
        case frame, figure, table

        /// Depth in the outline; floats sit below any heading.
        var level: Int {
            switch self {
            case .part: 0
            case .chapter: 1
            case .section: 2
            case .subsection, .frame: 3
            case .subsubsection: 4
            case .paragraph: 5
            case .subparagraph: 6
            case .figure, .table: 7
            }
        }

        var canContainItems: Bool {
            switch self {
            case .figure, .table: false
            default: true
            }
        }

        var systemImage: String {
            switch self {
            case .part: "books.vertical"
            case .chapter: "book.closed"
            case .section, .subsection, .subsubsection: "number"
            case .paragraph, .subparagraph: "paragraphsign"
            case .frame: "rectangle.on.rectangle"
            case .figure: "photo"
            case .table: "tablecells"
            }
        }

        var accessibilityName: String {
            switch self {
            case .part: String(localized: "Part")
            case .chapter: String(localized: "Chapter")
            case .section: String(localized: "Section")
            case .subsection: String(localized: "Subsection")
            case .subsubsection: String(localized: "Subsubsection")
            case .paragraph, .subparagraph: String(localized: "Paragraph")
            case .frame: String(localized: "Frame")
            case .figure: String(localized: "Figure")
            case .table: String(localized: "Table")
            }
        }
    }

    /// The UTF-16 offset of the command, which also identifies the item.
    var id: Int { location }
    var kind: Kind
    var title: String
    /// The 1-based line of the command.
    var line: Int
    var location: Int
    /// Nested items, or nil for items without any (so lists show no disclosure triangle).
    var children: [OutlineItem]?
}

/// Builds the document outline from LaTeX source.
nonisolated enum OutlineParser {
    private static let headingPattern = try! NSRegularExpression(
        pattern: #"\\(part|chapter|section|subsection|subsubsection|paragraph|subparagraph)\*?[ \t]*(?:\[[^\]\n]*\])?[ \t]*\{"#
    )
    private static let framePattern = try! NSRegularExpression(
        pattern: #"\\begin\{frame\}(?:<[^>\n]*>)?(?:\[[^\]\n]*\])?"#
    )
    private static let frameTitlePattern = try! NSRegularExpression(pattern: #"^[ \t]*(?:\{|\n[ \t]*\\frametitle\{)"#)
    private static let floatPattern = try! NSRegularExpression(pattern: #"\\begin\{(figure|table)\*?\}"#)
    private static let captionPattern = try! NSRegularExpression(pattern: #"\\caption(?:\[[^\]\n]*\])?\{"#)

    static func parse(_ text: String) -> [OutlineItem] {
        let string = text as NSString
        let fullRange = NSRange(location: 0, length: string.length)
        let lineIndex = LineStarts(string)
        var items: [OutlineItem] = []

        for match in headingPattern.matches(in: text, range: fullRange) where !isCommentedOut(match.range.location, in: string) {
            let name = string.substring(with: match.range(at: 1))
            guard let kind = headingKind(name) else { continue }
            let title = braceGroup(in: string, openingAt: NSMaxRange(match.range) - 1)
            items.append(item(kind, title: title, at: match.range.location, lineIndex: lineIndex))
        }

        for match in framePattern.matches(in: text, range: fullRange) where !isCommentedOut(match.range.location, in: string) {
            var title = ""
            let after = NSRange(location: NSMaxRange(match.range), length: min(400, string.length - NSMaxRange(match.range)))
            if let titleMatch = frameTitlePattern.firstMatch(in: text, options: .anchored, range: after) {
                title = braceGroup(in: string, openingAt: NSMaxRange(titleMatch.range) - 1)
            }
            items.append(item(.frame, title: title, at: match.range.location, lineIndex: lineIndex))
        }

        for match in floatPattern.matches(in: text, range: fullRange) where !isCommentedOut(match.range.location, in: string) {
            let name = string.substring(with: match.range(at: 1))
            let environmentEnd = string.range(of: "\\end{\(name)", options: .literal, range: NSRange(location: NSMaxRange(match.range), length: string.length - NSMaxRange(match.range)))
            let bodyEnd = environmentEnd.location == NSNotFound ? string.length : environmentEnd.location
            let body = NSRange(location: NSMaxRange(match.range), length: bodyEnd - NSMaxRange(match.range))
            var title = ""
            if let caption = captionPattern.firstMatch(in: text, range: body) {
                title = braceGroup(in: string, openingAt: NSMaxRange(caption.range) - 1)
            }
            items.append(item(name == "figure" ? .figure : .table, title: title, at: match.range.location, lineIndex: lineIndex))
        }

        items.sort { $0.location < $1.location }
        return buildTree(items)
    }

    /// Every item in document order, including nested ones.
    static func flatten(_ items: [OutlineItem]) -> [OutlineItem] {
        items.flatMap { [$0] + flatten($0.children ?? []) }
    }

    // MARK: - Helpers

    private static func headingKind(_ name: String) -> OutlineItem.Kind? {
        switch name {
        case "part": .part
        case "chapter": .chapter
        case "section": .section
        case "subsection": .subsection
        case "subsubsection": .subsubsection
        case "paragraph": .paragraph
        case "subparagraph": .subparagraph
        default: nil
        }
    }

    private static func item(_ kind: OutlineItem.Kind, title: String, at location: Int, lineIndex: LineStarts) -> OutlineItem {
        let cleaned = cleanTitle(title)
        let fallback: String
        switch kind {
        case .frame: fallback = String(localized: "Untitled Frame")
        case .figure: fallback = String(localized: "Figure")
        case .table: fallback = String(localized: "Table")
        default: fallback = String(localized: "Untitled")
        }
        return OutlineItem(kind: kind, title: cleaned.isEmpty ? fallback : cleaned, line: lineIndex.line(at: location), location: location, children: nil)
    }

    /// Nests items under the nearest preceding item of a shallower level.
    private static func buildTree(_ items: [OutlineItem]) -> [OutlineItem] {
        var parents: [Int?] = []
        var stack: [Int] = []
        for (index, item) in items.enumerated() {
            while let last = stack.last, items[last].kind.level >= item.kind.level {
                stack.removeLast()
            }
            parents.append(stack.last)
            if item.kind.canContainItems {
                stack.append(index)
            }
        }
        var childIndices: [Int: [Int]] = [:]
        var rootIndices: [Int] = []
        for (index, parent) in parents.enumerated() {
            if let parent {
                childIndices[parent, default: []].append(index)
            } else {
                rootIndices.append(index)
            }
        }
        func build(_ index: Int) -> OutlineItem {
            var item = items[index]
            let children = (childIndices[index] ?? []).map(build)
            item.children = children.isEmpty ? nil : children
            return item
        }
        return rootIndices.map(build)
    }

    /// The text of the brace group opening at `openBrace`, without the braces.
    private static func braceGroup(in string: NSString, openingAt openBrace: Int) -> String {
        guard openBrace >= 0, openBrace < string.length, string.character(at: openBrace) == Char.openBrace else { return "" }
        var depth = 0
        var index = openBrace
        let limit = min(string.length, openBrace + 1000)
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
                    return string.substring(with: NSRange(location: openBrace + 1, length: index - openBrace - 1))
                }
            }
            index += 1
        }
        return ""
    }

    private static let labelPattern = try! NSRegularExpression(pattern: #"\\(?:label|index|footnote|protect)(?:\{[^{}]*\})?"#)
    private static let commandPattern = try! NSRegularExpression(pattern: #"\\[A-Za-z@]+\*?"#)

    /// Turns LaTeX markup in a title into plain text for display.
    static func cleanTitle(_ title: String) -> String {
        var result = title as NSString
        result = labelPattern.stringByReplacingMatches(in: result as String, range: NSRange(location: 0, length: result.length), withTemplate: "") as NSString
        result = commandPattern.stringByReplacingMatches(in: result as String, range: NSRange(location: 0, length: result.length), withTemplate: "") as NSString
        let plain = (result as String)
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
            .replacingOccurrences(of: "~", with: " ")
            .replacingOccurrences(of: "\\", with: "")
        return plain.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// Whether the line containing `location` comments it out.
    private static func isCommentedOut(_ location: Int, in string: NSString) -> Bool {
        let lineStart = string.lineRange(for: NSRange(location: location, length: 0)).location
        guard location > lineStart else { return false }
        let prefix = string.substring(with: NSRange(location: lineStart, length: location - lineStart))
        return LaTeXText.stripComment(prefix) != prefix
    }
}

/// Line numbers for offsets in a string, built once per parse.
nonisolated private struct LineStarts {
    private let starts: [Int]

    init(_ string: NSString) {
        starts = [0] + LineIndex.lineBreaks(in: string, range: NSRange(location: 0, length: string.length))
    }

    func line(at location: Int) -> Int {
        var low = 0
        var high = starts.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if starts[middle] <= location {
                low = middle
            } else {
                high = middle - 1
            }
        }
        return low + 1
    }
}
