//
//  MathScanner.swift
//  TexLab
//

import Foundation

/// A piece of the source that the editor can show rendered: math, or a TikZ drawing, a
/// table or a whole figure or table float, which is typeset as it is and drawn on a piece
/// of paper.
nonisolated struct MathRegion: Sendable, Equatable {
    /// The whole construct, including `$…$`, `\[…\]` or `\begin{…}…\end{…}`.
    var range: NSRange
    /// The math between the delimiters, or the body of a drawing, table or float.
    var contentRange: NSRange
    var isDisplay: Bool
    /// Display math alone on its lines, drawn centred like the typeset output.
    var standsAlone: Bool
    /// The LaTeX TexLab typesets to draw the region.
    var snippet: String
    /// A drawing, a table or a float rather than math: typeset outside math mode, in colour.
    var isBlock = false
    /// A figure or table float, typeset with its caption.
    var isFloat = false

    /// Identifies the rendering of this region, so identical formulas share one image.
    var key: String { (isBlock ? "B:" : isDisplay ? "D:" : "I:") + snippet }

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

        let scan = LaTeXTokenizer.scan(string, range: body)
        let math = scan.regions.compactMap { span in
            Self.region(for: span.range, in: string)
        }
        // Drawings and tables can't start in a comment or verbatim text, or inside math.
        let excluded = scan.regions.map(\.range) + scan.tokens.filter { $0.kind == .comment || $0.kind == .verbatim }.map(\.range)
        return blocks(in: string, range: body, excluding: excluded) + math
    }

    // MARK: - Drawings, tables and floats

    /// The environments shown typeset, as they are, outside math: TikZ drawings and tables.
    private static let blockPattern = try! NSRegularExpression(
        pattern: #"\\(begin|end)\s*\{(tikzpicture|circuitikz|forest|tabular\*?|tabularx|tabulary)\}"#
    )
    /// Figure and table floats, shown typeset whole, with their captions.
    private static let floatPattern = try! NSRegularExpression(pattern: #"\\(begin|end)\s*\{(figure\*?|table\*?)\}"#)

    /// The figure and table floats in `range`, and the outermost TikZ drawings and tables,
    /// in source order, each from its `\begin` to the matching `\end`. A table in a
    /// drawing, or one table in another, is part of the outer one. A float is shown whole,
    /// caption and all; the drawing or table in it is shown instead if the float can't be
    /// typeset.
    static func blocks(in string: NSString, range: NSRange, excluding excluded: [NSRange]) -> [MathRegion] {
        var blocks: [MathRegion] = []
        for float in environments(floatPattern, in: string, range: range, excluding: excluded) {
            // The float's placement, such as [htbp] or [H], doesn't matter on its own.
            var bodyStart = float.contentStart
            while bodyStart < float.contentEnd, Char.isWhitespace(string.character(at: bodyStart)) {
                bodyStart += 1
            }
            if bodyStart < float.contentEnd, string.character(at: bodyStart) == Char.openBracket {
                let close = string.range(of: "]", range: NSRange(location: bodyStart, length: float.contentEnd - bodyStart))
                if close.location != NSNotFound {
                    bodyStart = NSMaxRange(close)
                }
            }
            let body = string.substring(with: NSRange(location: bodyStart, length: float.contentEnd - bodyStart))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !body.isEmpty else { continue }
            // A float can't go in the box each preview is; a page-wide minipage that
            // captions like the float does, with \caption working as in it, can.
            let kind = float.name.hasPrefix("table") ? "table" : "figure"
            blocks.append(MathRegion(
                range: float.whole,
                contentRange: NSRange(location: bodyStart, length: float.contentEnd - bodyStart),
                isDisplay: true,
                standsAlone: isAloneOnItsLines(float.whole, in: string),
                snippet: "\\begin{minipage}{\\linewidth}\\TexLabFloat{\(kind)}\n" + body + "\n\\end{minipage}",
                isBlock: true,
                isFloat: true
            ))
        }
        for block in environments(blockPattern, in: string, range: range, excluding: excluded) {
            blocks.append(MathRegion(
                range: block.whole,
                contentRange: NSRange(location: block.contentStart, length: block.contentEnd - block.contentStart),
                isDisplay: true,
                standsAlone: isAloneOnItsLines(block.whole, in: string),
                snippet: string.substring(with: block.whole).trimmingCharacters(in: .whitespacesAndNewlines),
                isBlock: true
            ))
        }
        return blocks.sorted {
            $0.range.location != $1.range.location ? $0.range.location < $1.range.location : $0.range.length > $1.range.length
        }
    }

    /// The outermost environments `pattern` matches the `\begin` and `\end` of, with the
    /// same name nested inside counted, so each ends at its own `\end`.
    private static func environments(
        _ pattern: NSRegularExpression,
        in string: NSString,
        range: NSRange,
        excluding excluded: [NSRange]
    ) -> [(name: String, whole: NSRange, contentStart: Int, contentEnd: Int)] {
        var found: [(name: String, whole: NSRange, contentStart: Int, contentEnd: Int)] = []
        var open: (name: String, start: Int, contentStart: Int, depth: Int)?
        for match in pattern.matches(in: string as String, range: range) {
            let command = match.range
            guard !excluded.contains(where: { NSIntersectionRange($0, command).length > 0 }),
                  !isEscaped(command.location, in: string) else { continue }
            let isBegin = string.substring(with: match.range(at: 1)) == "begin"
            let name = string.substring(with: match.range(at: 2))
            if var current = open {
                guard name == current.name else { continue }
                current.depth += isBegin ? 1 : -1
                open = current
                guard current.depth == 0 else { continue }
                let whole = NSRange(location: current.start, length: NSMaxRange(command) - current.start)
                found.append((name, whole, current.contentStart, command.location))
                open = nil
            } else if isBegin {
                open = (name, command.location, NSMaxRange(command), 1)
            }
        }
        return found
    }

    /// Whether the backslash at `location` is itself escaped, as in `\\begin`.
    private static func isEscaped(_ location: Int, in string: NSString) -> Bool {
        var count = 0
        var index = location - 1
        while index >= 0 && string.character(at: index) == Char.backslash {
            count += 1
            index -= 1
        }
        return count % 2 == 1
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
