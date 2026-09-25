//
//  MathScanner.swift
//  TexLab
//

import Foundation

/// A piece of math in the source that the editor can show rendered.
nonisolated struct MathRegion: Sendable, Equatable {
    /// The whole construct, including `$…$`, `\[…\]` or `\begin{…}…\end{…}`.
    var range: NSRange
    /// The math between the delimiters.
    var contentRange: NSRange
    var isDisplay: Bool
    /// Display math alone on its lines, drawn centred like the typeset output.
    var standsAlone: Bool
    /// The LaTeX TexLab typesets to draw the region.
    var snippet: String

    /// Identifies the rendering of this math, so identical formulas share one image.
    var key: String { (isDisplay ? "D:" : "I:") + snippet }

    func shifted(by delta: Int) -> MathRegion {
        var copy = self
        copy.range.location += delta
        copy.contentRange.location += delta
        return copy
    }
}

/// Finds the math in a document's body.
nonisolated enum MathScanner {
    private static let alignedEnvironments: Set<String> = [
        "align", "align*", "flalign", "flalign*", "alignat", "alignat*", "eqnarray", "eqnarray*",
    ]
    private static let gatheredEnvironments: Set<String> = ["gather", "gather*", "multline", "multline*"]

    private static let strippedCommands = try! NSRegularExpression(
        pattern: #"\\label\{[^{}]*\}|\\tag\*?\{[^{}]*\}|\\nonumber\b|\\notag\b"#
    )
    private static let alignatArgument = try! NSRegularExpression(pattern: #"^\s*\{\d+\}"#)

    static func scan(_ text: String) -> [MathRegion] {
        let string = text as NSString
        var bodyStart = 0
        let beginDocument = string.range(of: "\\begin{document}")
        if beginDocument.location != NSNotFound {
            bodyStart = NSMaxRange(beginDocument)
        }
        let body = NSRange(location: bodyStart, length: string.length - bodyStart)
        guard body.length > 0 else { return [] }

        return LaTeXTokenizer.scan(string, range: body).regions.compactMap { span in
            Self.region(for: span.range, in: string)
        }
    }

    private static func region(for range: NSRange, in string: NSString) -> MathRegion? {
        let source = string.substring(with: range)
        let content: NSRange
        let isDisplay: Bool
        var whole = range
        var environment: String?

        if source.hasPrefix("$$") {
            guard range.length >= 4, source.hasSuffix("$$") else { return nil }
            content = NSRange(location: range.location + 2, length: range.length - 4)
            isDisplay = true
        } else if source.hasPrefix("$") {
            guard range.length >= 2, source.hasSuffix("$"), !source.hasSuffix("\\$") else { return nil }
            content = NSRange(location: range.location + 1, length: range.length - 2)
            isDisplay = false
        } else if source.hasPrefix("\\[") || source.hasPrefix("\\(") {
            let closing = source.hasPrefix("\\[") ? "\\]" : "\\)"
            guard range.length >= 4, source.hasSuffix(closing) else { return nil }
            content = NSRange(location: range.location + 2, length: range.length - 4)
            isDisplay = source.hasPrefix("\\[")
        } else {
            // A math environment: the tokenizer's region is the body; find its \begin and \end.
            let searchStart = max(range.location - 60, 0)
            let before = string.range(of: "\\begin{", options: .backwards, range: NSRange(location: searchStart, length: range.location - searchStart))
            guard before.location != NSNotFound else { return nil }
            let nameStart = NSMaxRange(before)
            guard range.location - 1 > nameStart, string.character(at: range.location - 1) == Char.closeBrace else { return nil }
            let name = string.substring(with: NSRange(location: nameStart, length: range.location - 1 - nameStart))
            let end = "\\end{\(name)}"
            let endLength = (end as NSString).length
            guard NSMaxRange(range) + endLength <= string.length,
                  string.substring(with: NSRange(location: NSMaxRange(range), length: endLength)) == end else { return nil }
            content = range
            whole = NSRange(location: before.location, length: NSMaxRange(range) + endLength - before.location)
            isDisplay = name != "math"
            environment = name
        }

        var math = string.substring(with: content)
        math = strippedCommands.stringByReplacingMatches(in: math, range: NSRange(location: 0, length: (math as NSString).length), withTemplate: "")
        if let environment {
            if alignedEnvironments.contains(environment) {
                if environment.hasPrefix("alignat") {
                    math = alignatArgument.stringByReplacingMatches(in: math, range: NSRange(location: 0, length: (math as NSString).length), withTemplate: "")
                }
                math = "\\begin{aligned}\(math)\\end{aligned}"
            } else if gatheredEnvironments.contains(environment) {
                math = "\\begin{gathered}\(math)\\end{gathered}"
            }
        }
        let trimmed = math.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        return MathRegion(
            range: whole,
            contentRange: content,
            isDisplay: isDisplay,
            standsAlone: isDisplay && isAloneOnItsLines(whole, in: string),
            snippet: trimmed
        )
    }

    /// Whether only whitespace shares the lines of `range`.
    private static func isAloneOnItsLines(_ range: NSRange, in string: NSString) -> Bool {
        let lineStart = string.lineRange(for: NSRange(location: range.location, length: 0)).location
        let before = string.substring(with: NSRange(location: lineStart, length: range.location - lineStart))
        guard before.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        let endLine = string.lineRange(for: NSRange(location: max(NSMaxRange(range) - 1, range.location), length: 0))
        let afterLength = NSMaxRange(endLine) - NSMaxRange(range)
        guard afterLength >= 0 else { return true }
        // A trailing comment would be drawn over the centred formula, so it counts as text.
        let after = string.substring(with: NSRange(location: NSMaxRange(range), length: afterLength))
        return after.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
