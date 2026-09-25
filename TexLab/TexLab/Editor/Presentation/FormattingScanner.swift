//
//  FormattingScanner.swift
//  TexLab
//

import Foundation

/// How a text-style command shows its argument in the live preview.
nonisolated struct TextStyle: OptionSet, Sendable, Hashable {
    let rawValue: Int

    static let bold = TextStyle(rawValue: 1 << 0)
    static let italic = TextStyle(rawValue: 1 << 1)
    static let monospace = TextStyle(rawValue: 1 << 2)
    static let smallCaps = TextStyle(rawValue: 1 << 3)
    static let sansSerif = TextStyle(rawValue: 1 << 4)
    static let serif = TextStyle(rawValue: 1 << 5)
    static let underline = TextStyle(rawValue: 1 << 6)
    static let strikethrough = TextStyle(rawValue: 1 << 7)
    /// Clears italic, bold or a family, as `\textup`, `\textmd` and `\textnormal` do.
    static let upright = TextStyle(rawValue: 1 << 8)
    static let medium = TextStyle(rawValue: 1 << 9)
}

/// A text-style command such as `\emph{…}`: the preview hides `\emph{` and `}` and shows
/// the argument emphasised.
nonisolated struct FormattedSpan: Sendable, Equatable {
    /// From the backslash to the closing brace.
    var range: NSRange
    /// The argument, between the braces.
    var contentRange: NSRange
    var style: TextStyle

    /// `\emph{`
    var openingRange: NSRange {
        NSRange(location: range.location, length: contentRange.location - range.location)
    }

    /// `}`
    var closingRange: NSRange {
        NSRange(location: NSMaxRange(contentRange), length: NSMaxRange(range) - NSMaxRange(contentRange))
    }

    func shifted(by delta: Int) -> FormattedSpan {
        var copy = self
        copy.range.location += delta
        copy.contentRange.location += delta
        return copy
    }
}

/// Finds text-style commands in the body of a document.
nonisolated enum FormattingScanner {
    static let styles: [String: TextStyle] = [
        "emph": .italic,
        "textit": .italic,
        "textsl": .italic,
        "textbf": .bold,
        "texttt": .monospace,
        "textsc": .smallCaps,
        "textsf": .sansSerif,
        "textrm": .serif,
        "textup": .upright,
        "textmd": .medium,
        "textnormal": [.upright, .medium],
        "underline": .underline,
        "uline": .underline,
        "sout": .strikethrough,
    ]

    private static let commandPattern = try! NSRegularExpression(
        pattern: #"\\(emph|textit|textsl|textbf|texttt|textsc|textsf|textrm|textup|textmd|textnormal|underline|uline|sout)\s*\{"#
    )

    /// Where the document body starts: after `\begin{document}`, or at the start of a file
    /// without one (a chapter included into a larger project).
    static func bodyStart(in string: NSString) -> Int {
        let begin = string.range(of: "\\begin{document}")
        return begin.location == NSNotFound ? 0 : NSMaxRange(begin)
    }

    /// The styled spans in `range`, skipping comments and anything overlapping `excluded`
    /// (math and verbatim text). Arguments may not contain a blank line, as in TeX.
    static func scan(_ string: NSString, range: NSRange, excluding excluded: [NSRange] = []) -> [FormattedSpan] {
        var spans: [FormattedSpan] = []
        for match in commandPattern.matches(in: string as String, range: range) {
            let start = match.range.location
            guard start == 0 || string.character(at: start - 1) != Char.backslash,
                  !isCommentedOut(start, in: string),
                  let style = styles[string.substring(with: match.range(at: 1))],
                  let close = closingBrace(from: NSMaxRange(match.range), in: string, limit: NSMaxRange(range)) else { continue }
            let content = NSRange(location: NSMaxRange(match.range), length: close - NSMaxRange(match.range))
            guard content.length > 0 else { continue }
            let whole = NSRange(location: start, length: close + 1 - start)
            guard !excluded.contains(where: { NSIntersectionRange($0, whole).length > 0 }) else { continue }
            spans.append(FormattedSpan(range: whole, contentRange: content, style: style))
        }
        return spans
    }

    /// The brace closing the one opened just before `location`.
    private static func closingBrace(from location: Int, in string: NSString, limit: Int) -> Int? {
        var depth = 1
        var index = location
        var previousWasNewline = false
        while index < limit {
            let character = string.character(at: index)
            switch character {
            case Char.backslash:
                index += 2
                previousWasNewline = false
                continue
            case Char.percent:
                // Skip the comment to the end of its line.
                while index < limit && string.character(at: index) != Char.newline {
                    index += 1
                }
                continue
            case Char.newline:
                if previousWasNewline { return nil }
                previousWasNewline = true
            case Char.openBrace:
                depth += 1
                previousWasNewline = false
            case Char.closeBrace:
                depth -= 1
                if depth == 0 { return index }
                previousWasNewline = false
            case Char.space, Char.tab:
                break
            default:
                previousWasNewline = false
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
