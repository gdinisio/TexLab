//
//  EditorController.swift
//  TexLab
//

import AppKit

/// The interface menu commands, the sidebar and the preview use to work with a window's
/// source editor.
final class EditorController {
    private(set) weak var textView: SourceTextView?

    func attach(_ textView: SourceTextView) {
        self.textView = textView
    }

    var isAvailable: Bool { textView != nil }

    /// The 1-based line and column of the insertion point.
    var caretPosition: (line: Int, column: Int) {
        textView?.caretPosition ?? (1, 1)
    }

    var selectedRange: NSRange {
        textView?.selectedRange() ?? NSRange(location: 0, length: 0)
    }

    /// Makes the editor the focus of its window.
    func focus() {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
    }

    // MARK: - Editing

    func insert(_ snippet: Snippet) {
        focus()
        textView?.insert(snippet)
    }

    func toggleWrap(prefix: String, suffix: String, actionName: String) {
        focus()
        textView?.toggleWrap(prefix: prefix, suffix: suffix, actionName: actionName)
    }

    func insertText(_ text: String, actionName: String) {
        focus()
        textView?.insertAtSelection(text, actionName: actionName)
    }

    /// Replaces `range` as one undoable step, keeping the insertion point where it was.
    func replace(_ range: NSRange, with text: String, actionName: String) {
        guard let textView else { return }
        let selection = textView.selectedRange()
        let delta = (text as NSString).length - range.length
        let caret = selection.location >= NSMaxRange(range) ? selection.location + delta : selection.location
        textView.replaceCharacters(in: range, with: text, selecting: NSRange(location: max(caret, 0), length: 0), actionName: actionName)
    }

    func toggleComment() {
        focus()
        textView?.toggleComment()
    }

    func shiftRight() {
        focus()
        textView?.shiftSelectedLines(right: true)
    }

    func shiftLeft() {
        focus()
        textView?.shiftSelectedLines(right: false)
    }

    // MARK: - Navigation

    func revealLine(_ line: Int, highlight: Bool = true) {
        textView?.revealLine(line, highlight: highlight)
    }

    func reveal(location: Int, length: Int = 0) {
        let range = NSRange(location: location, length: length)
        textView?.reveal(range, selecting: NSRange(location: location, length: 0))
    }

    var lineCount: Int {
        textView?.lineIndex.lineCount ?? 1
    }

    // MARK: - Issues

    func setIssueMarkers(_ markers: [Int: IssueMarker]) {
        textView?.lineNumberRuler?.issueMarkers = markers
    }
}
