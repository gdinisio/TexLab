//
//  EditorController.swift
//  TexLab
//

import AppKit
import CoreGraphics
import Foundation

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

    // MARK: - Files

    /// Where the editor is in the file it shows, to come back to.
    func currentState() -> (selection: NSRange, scrollOrigin: CGPoint?, folds: [FoldableRegion]) {
        guard let textView else { return (NSRange(location: 0, length: 0), nil, []) }
        return (textView.selectedRange(), textView.enclosingScrollView?.contentView.bounds.origin, textView.folds)
    }

    /// Shows another file's text, with its own insertion point, scroll position and folds.
    /// Not undoable: each file keeps its own undo history.
    func show(text: String, selection: NSRange, scrollOrigin: CGPoint?, folds: [FoldableRegion]) {
        guard let textView else { return }
        textView.hideCompletion()
        textView.breakUndoCoalescing()
        textView.endPlaceholders()
        textView.folds = []
        textView.setText(text)
        let length = (text as NSString).length
        let location = min(selection.location, length)
        let range = NSRange(location: location, length: min(selection.length, length - location))
        textView.setSelectedRange(range)
        textView.folds = folds.filter { NSMaxRange($0.range) <= length }
        textView.updatePresentation()
        guard let scrollView = textView.enclosingScrollView else { return }
        if let scrollOrigin {
            // After the new text is laid out.
            DispatchQueue.main.async { [weak textView] in
                guard let textView, let clipView = textView.enclosingScrollView?.contentView else { return }
                clipView.scroll(to: scrollOrigin)
                scrollView.reflectScrolledClipView(clipView)
            }
        } else {
            textView.scrollRangeToVisible(range)
        }
    }

    /// Brings the editor in line with text changed outside it, keeping its place.
    func applyExternalText(_ text: String) {
        textView?.applyExternalText(text)
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

    /// Selects `range` and scrolls it into view.
    func select(_ range: NSRange) {
        textView?.reveal(range, selecting: range, highlight: false)
    }

    /// Replaces `range` as one undoable step, keeping the insertion point where it was.
    func replace(_ range: NSRange, with text: String, actionName: String) {
        guard let textView else { return }
        let selection = textView.selectedRange()
        let delta = (text as NSString).length - range.length
        let caret = selection.location >= NSMaxRange(range) ? selection.location + delta : selection.location
        textView.replaceCharacters(in: range, with: text, selecting: NSRange(location: max(caret, 0), length: 0), actionName: actionName)
    }

    /// Shows the find bar, like Edit ▸ Find ▸ Find….
    func showFind() {
        focus()
        let item = NSMenuItem()
        item.tag = NSTextFinder.Action.showFindInterface.rawValue
        textView?.performTextFinderAction(item)
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

    /// Inserts a symbol's command, wrapped in `$…$` when the insertion point isn't already
    /// in math, and separated from a following letter so the command stays intact.
    func insertSymbol(_ symbol: LaTeXSymbol) {
        guard let textView, let storage = textView.textStorage else { return }
        var text = symbol.command
        if symbol.isMath && !isInsertionPointInMath {
            text = "$\(text)$"
        } else {
            let end = NSMaxRange(textView.selectedRange())
            if end < storage.length,
               let last = text.unicodeScalars.last, CharacterSet.letters.contains(last),
               let next = Unicode.Scalar(storage.mutableString.character(at: end)), CharacterSet.letters.contains(next) {
                text += " "
            }
        }
        insertText(text, actionName: String(localized: "Insert \(symbol.name.capitalized)"))
    }

    /// Whether the insertion point is inside math, judged from the syntax colouring on
    /// both sides of it.
    var isInsertionPointInMath: Bool {
        guard let textView, let storage = textView.textStorage, storage.length > 0 else { return false }
        let location = textView.selectedRange().location
        guard location > 0, location < storage.length else { return false }
        let math = SyntaxKind.math.rawValue
        let before = storage.attribute(.texLabSyntax, at: location - 1, effectiveRange: nil) as? Int
        let after = storage.attribute(.texLabSyntax, at: location, effectiveRange: nil) as? Int
        return before == math && after == math
    }

    // MARK: - Navigation

    func revealLine(_ line: Int, column: Int = 1, highlight: Bool = true) {
        textView?.revealLine(line, column: column, highlight: highlight)
    }

    func reveal(location: Int, length: Int = 0) {
        let range = NSRange(location: location, length: length)
        textView?.reveal(range, selecting: NSRange(location: location, length: 0))
    }

    var lineCount: Int {
        textView?.lineIndex.lineCount ?? 1
    }

    // MARK: - Live preview

    func setMathRegions(_ regions: [MathRegion]) {
        textView?.setMathRegions(regions)
    }

    func setRenderedMath(_ images: [String: MathImage]) {
        textView?.setRenderedMath(images)
    }

    func setVisualElements(_ elements: [VisualElement]) {
        textView?.setVisualElements(elements)
    }

    func setFoldableRegions(_ regions: [FoldableRegion]) {
        textView?.setFoldableRegions(regions)
    }

    func setImageResolver(_ resolver: @escaping (String) -> URL?) {
        textView?.resolveImageURL = resolver
    }

    func forgetThumbnails() {
        textView?.forgetThumbnails()
    }

    // MARK: - Folding

    func foldAtSelection() {
        textView?.foldAtSelection()
    }

    func unfoldAtSelection() {
        textView?.unfoldAtSelection()
    }

    func foldFloats() {
        textView?.foldFloats()
    }

    func foldPreamble(beepsIfMissing: Bool = true) {
        textView?.foldPreamble(beepsIfMissing: beepsIfMissing)
    }

    func unfoldPreamble() {
        textView?.unfoldPreamble()
    }

    func foldSections() {
        textView?.foldSections()
    }

    func unfoldAll() {
        textView?.unfoldAll()
    }

    var hasFolds: Bool {
        !(textView?.folds.isEmpty ?? true)
    }

    var hasFoldableRegions: Bool {
        !(textView?.foldableRegions.isEmpty ?? true)
    }

    // MARK: - Issues

    func setIssueMarkers(_ markers: [Int: IssueMarker]) {
        textView?.lineNumberRuler?.issueMarkers = markers
    }
}
