//
//  FoldScanner.swift
//  TexLab
//

import Foundation

/// A multi-line environment that can be collapsed in the editor.
nonisolated struct FoldableRegion: Sendable, Equatable {
    /// From `\begin{…}` to the end of the matching `\end{…}`.
    var range: NSRange
    var environment: String
    /// The caption of a figure or table, as plain text.
    var caption: String?
    /// The first `\includegraphics` path in the environment, as written.
    var imagePath: String?
    var lineCount: Int

    var isFloat: Bool {
        FoldScanner.floatEnvironments.contains(environment)
    }

    /// What a collapsed region shows.
    var summary: String {
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
        return regions.sorted { $0.range.location < $1.range.location }
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
