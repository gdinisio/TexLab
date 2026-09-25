//
//  SourceTextView+Editing.swift
//  TexLab
//

import AppKit

/// Text inserted by the Insert and Format menus.
///
/// `before` and `after` surround the selection (or the insertion point). In both, a tab
/// stands for one level of indentation and a line break continues the current line's
/// indentation, so snippets fit wherever they are inserted.
nonisolated struct Snippet: Identifiable, Sendable {
    var id: String { title }
    let title: String
    let systemImage: String?
    let before: String
    let after: String

    init(_ title: String, systemImage: String? = nil, before: String, after: String = "") {
        self.title = title
        self.systemImage = systemImage
        self.before = before
        self.after = after
    }
}

extension SourceTextView {
    // MARK: - Insertion

    /// Inserts a snippet around the selection as one undoable step, named "Insert …" in
    /// the Edit menu unless `actionName` says otherwise.
    func insert(_ snippet: Snippet, actionName: String? = nil) {
        guard let text = textStorage?.mutableString else { return }
        let selection = selectedRange()
        let selected = text.substring(with: selection)
        let lineStart = text.lineRange(for: NSRange(location: selection.location, length: 0)).location
        let indent = Self.leadingWhitespace(of: text.substring(with: NSRange(location: lineStart, length: selection.location - lineStart)))
        let before = expandSnippetText(snippet.before, indent: indent)
        let after = expandSnippetText(snippet.after, indent: indent)
        let innerStart = selection.location + (before as NSString).length
        replaceCharacters(
            in: selection,
            with: before + selected + after,
            selecting: NSRange(location: innerStart, length: (selected as NSString).length),
            actionName: actionName ?? String(localized: "Insert \(snippet.title)")
        )
    }

    /// Wraps the selection in a command such as `\textbf{…}`, or unwraps it if it is
    /// already wrapped in that command — so Format ▸ Bold toggles, as in any Mac editor.
    func toggleWrap(prefix: String, suffix: String, actionName: String) {
        guard let text = textStorage?.mutableString else { return }
        let selection = selectedRange()
        let prefixLength = (prefix as NSString).length
        let suffixLength = (suffix as NSString).length
        let outerStart = selection.location - prefixLength
        let outerEnd = NSMaxRange(selection) + suffixLength
        if outerStart >= 0, outerEnd <= text.length,
           text.substring(with: NSRange(location: outerStart, length: prefixLength)) == prefix,
           text.substring(with: NSRange(location: NSMaxRange(selection), length: suffixLength)) == suffix {
            let selected = text.substring(with: selection)
            replaceCharacters(
                in: NSRange(location: outerStart, length: outerEnd - outerStart),
                with: selected,
                selecting: NSRange(location: outerStart, length: selection.length),
                actionName: actionName
            )
            return
        }
        insert(Snippet(actionName, before: prefix, after: suffix), actionName: actionName)
    }

    /// Inserts text at the insertion point, replacing the selection.
    func insertAtSelection(_ string: String, actionName: String) {
        let selection = selectedRange()
        let caret = NSRange(location: selection.location + (string as NSString).length, length: 0)
        replaceCharacters(in: selection, with: string, selecting: caret, actionName: actionName)
    }

    private func expandSnippetText(_ template: String, indent: String) -> String {
        template
            .replacingOccurrences(of: "\t", with: configuration.indentUnit)
            .replacingOccurrences(of: "\n", with: "\n" + indent)
    }

    // MARK: - Lines

    /// Comments out the selected lines with `%`, or uncomments them if they all are.
    func toggleComment() {
        editSelectedLines(actionName: { $0 ? String(localized: "Uncomment") : String(localized: "Comment") }) { lines in
            let contentLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard !contentLines.isEmpty else { return nil }
            let allCommented = contentLines.allSatisfy { $0.trimmingCharacters(in: .whitespaces).hasPrefix("%") }
            if allCommented {
                let uncommented = lines.map { line -> String in
                    guard let percent = line.firstIndex(of: "%"),
                          line[..<percent].allSatisfy({ $0 == " " || $0 == "\t" }) else { return line }
                    var result = line
                    let afterPercent = line.index(after: percent)
                    let end = afterPercent < line.endIndex && line[afterPercent] == " " ? line.index(after: afterPercent) : afterPercent
                    result.removeSubrange(percent..<end)
                    return result
                }
                return (uncommented, true)
            }
            let indent = contentLines.map { Self.leadingWhitespace(of: $0).count }.min() ?? 0
            let commented = lines.map { line -> String in
                guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return line }
                let split = line.index(line.startIndex, offsetBy: indent)
                return String(line[..<split]) + "% " + String(line[split...])
            }
            return (commented, false)
        }
    }

    /// Indents or outdents the selected lines by one level.
    func shiftSelectedLines(right: Bool) {
        let unit = configuration.indentUnit
        let width = max(configuration.indentWidth, 1)
        editSelectedLines(actionName: { _ in right ? String(localized: "Shift Right") : String(localized: "Shift Left") }) { lines in
            let shifted = lines.map { line -> String in
                if right {
                    return line.isEmpty ? line : unit + line
                }
                if line.hasPrefix("\t") {
                    return String(line.dropFirst())
                }
                let spaces = line.prefix { $0 == " " }.count
                return String(line.dropFirst(min(spaces, width)))
            }
            return shifted == lines ? nil : (shifted, false)
        }
    }

    /// Replaces the lines touched by the selection with the result of `transform`, keeping
    /// them selected afterwards. `transform` returns the new lines and a flag passed to
    /// `actionName`, or nil to leave the text unchanged.
    private func editSelectedLines(actionName: (Bool) -> String, transform: ([String]) -> ([String], Bool)?) {
        guard let text = textStorage?.mutableString else { return }
        let selection = selectedRange()
        let block = text.lineRange(for: selection)
        let original = text.substring(with: block)
        let endsWithNewline = original.hasSuffix("\n")
        var lines = original.components(separatedBy: "\n")
        if endsWithNewline {
            lines.removeLast()
        }
        guard let result = transform(lines) else { return }
        let (newLines, flag) = result
        var replacement = newLines.joined(separator: "\n")
        if endsWithNewline {
            replacement += "\n"
        }
        let replacementLength = (replacement as NSString).length
        let newSelection: NSRange
        if selection.length == 0 {
            let caret = selection.location + replacementLength - block.length
            newSelection = NSRange(location: max(block.location, caret), length: 0)
        } else {
            newSelection = NSRange(location: block.location, length: replacementLength - (endsWithNewline ? 1 : 0))
        }
        replaceCharacters(in: block, with: replacement, selecting: newSelection, actionName: actionName(flag))
    }

    // MARK: - Navigation

    /// The 1-based line and column of the insertion point.
    var caretPosition: (line: Int, column: Int) {
        let location = selectedRange().location
        let line = lineIndex.lineNumber(at: location)
        return (line, location - lineIndex.startOfLine(line) + 1)
    }

    /// Moves the insertion point to `column` of `line`, scrolls the line into the middle of
    /// the editor and briefly highlights it so it's easy to spot.
    func revealLine(_ line: Int, column: Int = 1, highlight: Bool = true) {
        guard let text = textStorage?.mutableString else { return }
        let start = min(lineIndex.startOfLine(line), text.length)
        let paragraph = text.lineRange(for: NSRange(location: start, length: 0))
        let content = NSRange(location: paragraph.location, length: Self.contentLength(ofLine: paragraph, in: text))
        let caret = content.location + min(max(column - 1, 0), content.length)
        reveal(content, selecting: NSRange(location: caret, length: 0), highlight: highlight)
    }

    /// Selects `selection`, centres `range` in the editor and optionally highlights it.
    func reveal(_ range: NSRange, selecting selection: NSRange, highlight: Bool = true) {
        guard let text = textStorage?.mutableString else { return }
        let length = text.length
        let clamped = NSRange(location: min(range.location, length), length: min(range.length, length - min(range.location, length)))
        setSelectedRange(NSRange(location: min(selection.location, length), length: min(selection.length, length - min(selection.location, length))))
        scrollRangeToVisible(clamped)
        centerSelectionInVisibleArea(nil)
        window?.makeFirstResponder(self)
        guard highlight, clamped.length > 0 else { return }
        DispatchQueue.main.async { [weak self] in
            self?.showFindIndicator(for: clamped)
        }
    }

    // MARK: - Helpers

    static func leadingWhitespace(of line: String) -> String {
        String(line.prefix { $0 == " " || $0 == "\t" })
    }

    /// The length of a line without its line terminator.
    static func contentLength(ofLine line: NSRange, in text: NSString) -> Int {
        var length = line.length
        while length > 0 {
            let character = text.character(at: line.location + length - 1)
            guard character == Char.newline || character == Char.carriageReturn else { break }
            length -= 1
        }
        return length
    }

    private static let environmentOpeningPattern = try! NSRegularExpression(
        pattern: #"\\begin\{([^{}]+)\}(?:\[[^\]]*\]|\{[^{}]*\})*\s*$"#
    )

    /// The environment opened by `\begin{…}` at the end of `line`, if any.
    static func environmentOpened(atEndOf line: String) -> String? {
        let string = line as NSString
        let beforeComment = LaTeXText.stripComment(line)
        guard (beforeComment as NSString).length == string.length,
              let match = environmentOpeningPattern.firstMatch(in: line, range: NSRange(location: 0, length: string.length)) else {
            return nil
        }
        return string.substring(with: match.range(at: 1))
    }

    static func occurrences(of needle: String, in text: NSString) -> Int {
        var count = 0
        var searchRange = NSRange(location: 0, length: text.length)
        while searchRange.length > 0 {
            let found = text.range(of: needle, options: .literal, range: searchRange)
            guard found.location != NSNotFound else { break }
            count += 1
            let next = NSMaxRange(found)
            searchRange = NSRange(location: next, length: text.length - next)
        }
        return count
    }

    /// Whether an odd number of unescaped dollar signs precede `location` on its line.
    static func isInsideInlineMath(_ text: NSString, at location: Int) -> Bool {
        let lineStart = text.lineRange(for: NSRange(location: location, length: 0)).location
        var dollars = 0
        var index = lineStart
        while index < location {
            let character = text.character(at: index)
            if character == Char.backslash {
                index += 2
                continue
            }
            if character == Char.percent {
                return false
            }
            if character == Char.dollar {
                dollars += 1
            }
            index += 1
        }
        return dollars % 2 == 1
    }
}

/// Small helpers for LaTeX text.
nonisolated enum LaTeXText {
    /// `line` without its comment, if it has one. Escaped percent signs (`\%`) are kept.
    static func stripComment(_ line: String) -> String {
        var previousWasBackslash = false
        var index = line.startIndex
        while index < line.endIndex {
            let character = line[index]
            if character == "%" && !previousWasBackslash {
                return String(line[..<index])
            }
            previousWasBackslash = character == "\\" && !previousWasBackslash
            index = line.index(after: index)
        }
        return line
    }
}
