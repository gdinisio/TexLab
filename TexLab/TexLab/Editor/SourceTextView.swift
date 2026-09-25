//
//  SourceTextView.swift
//  TexLab
//

import AppKit
import CoreGraphics
import Foundation

/// The LaTeX source editor.
///
/// A TextKit 1 `NSTextView`, so the editor gets the Mac text system for free — Find,
/// spelling, services, dictation, Look Up, undo — and adds what a LaTeX writer expects:
/// syntax colouring, line numbers, a current line highlight, smart indentation, paired
/// brackets, environment closing and context-aware completion.
final class SourceTextView: NSTextView {
    /// Editor preferences. Setting a new value restyles the text.
    var configuration = EditorConfiguration() {
        didSet {
            guard configuration != oldValue else { return }
            applyConfiguration(previous: oldValue)
        }
    }

    let lineIndex = LineIndex()
    private(set) var highlighter = SyntaxHighlighter(theme: SyntaxTheme(fontSize: AppSettings.editorFontSize, indentWidth: AppSettings.indentWidth))
    private let storageObserver = StorageObserver()
    weak var lineNumberRuler: LineNumberRulerView?

    /// Provides the text inserted when files are dropped on the editor.
    var droppedFilesFormatter: (([URL]) -> String)?
    /// Asks whether completions exist before the editor offers them automatically.
    var hasCompletions: ((NSRange) -> Bool)?

    private var currentLineRect: NSRect?

    // MARK: Presentation (rendered math and folding)

    /// Math found in the source, kept in step with edits.
    var mathRegions: [MathRegion] = []
    /// Rendered formulas by `MathRegion.key`.
    var renderedMath: [String: MathImage] = [:]
    /// Environments that can be collapsed, kept in step with edits.
    var foldableRegions: [FoldableRegion] = []
    /// Collapsed environments.
    var folds: [FoldableRegion] = []
    /// Resolves an `\includegraphics` path for figure thumbnails.
    var resolveImageURL: ((String) -> URL?)?
    var thumbnails: [String: NSImage] = [:]
    var missingThumbnails: Set<String> = []
    /// Locations of the formulas currently shown as source because the selection is in them.
    var revealedMath: Set<Int> = []
    /// Text-style commands whose markup the live preview hides, kept in step with edits.
    var formattedSpans: [FormattedSpan] = []
    /// Locations of the styled spans currently showing their markup.
    var revealedFormatting: Set<Int> = []

    // MARK: - Creation

    /// Creates an editor inside a scroll view, with line numbers.
    static func makeScrollableEditor() -> (scrollView: NSScrollView, textView: SourceTextView) {
        let storage = NSTextStorage()
        let layoutManager = PresentationLayoutManager()
        layoutManager.allowsNonContiguousLayout = true
        storage.addLayoutManager(layoutManager)

        let unbounded = CGFloat(Float.greatestFiniteMagnitude)
        let container = NSTextContainer(size: NSSize(width: 0, height: unbounded))
        container.widthTracksTextView = true
        layoutManager.addTextContainer(container)

        let textView = SourceTextView(frame: .zero, textContainer: container)
        textView.minSize = .zero
        textView.maxSize = NSSize(width: unbounded, height: unbounded)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        // EditorScrollView sizes the text view itself; autoresizing would follow the
        // transient zero widths of the first layout passes.
        textView.autoresizingMask = []

        let scrollView = EditorScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.documentView = textView

        let ruler = LineNumberRulerView(textView: textView, scrollView: scrollView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        textView.lineNumberRuler = ruler

        textView.storageObserver.textView = textView
        storage.delegate = textView.storageObserver
        textView.applyConfiguration(previous: nil)
        return (scrollView, textView)
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        configureTextSystemBehaviour()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureTextSystemBehaviour()
    }

    private func configureTextSystemBehaviour() {
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        usesFindBar = true
        isIncrementalSearchingEnabled = true
        usesFontPanel = false
        usesRuler = false
        allowsDocumentBackgroundColorChange = false
        displaysLinkToolTips = false
        smartInsertDeleteEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        isAutomaticTextCompletionEnabled = false
        isGrammarCheckingEnabled = false
        drawsBackground = true
        backgroundColor = .textBackgroundColor
        textContainerInset = NSSize(width: 6, height: 10)
        setAccessibilityLabel(String(localized: "LaTeX source"))
        updateDragTypeRegistration()
    }

    // MARK: - Configuration

    private func applyConfiguration(previous: EditorConfiguration?) {
        if previous == nil || configuration.needsNewTheme(comparedTo: previous!) {
            let theme = SyntaxTheme(fontSize: CGFloat(configuration.fontSize), indentWidth: configuration.indentWidth)
            highlighter.theme = theme
            highlighter.stylesFormatting = configuration.stylesFormatting
            font = theme.font
            defaultParagraphStyle = theme.paragraphStyle
            typingAttributes = theme.baseAttributes
            if let storage = textStorage, storage.length > 0 {
                highlighter.highlightAll(storage)
            }
            lineNumberRuler?.editorFontDidChange()
        }
        isContinuousSpellCheckingEnabled = configuration.checksSpelling
        if let previous, previous.stylesFormatting != configuration.stylesFormatting, !configuration.needsNewTheme(comparedTo: previous) {
            highlighter.stylesFormatting = configuration.stylesFormatting
            if let storage = textStorage, storage.length > 0 {
                highlighter.highlightAll(storage)
            }
        }
        if previous == nil || previous?.rendersMath != configuration.rendersMath
            || previous?.stylesFormatting != configuration.stylesFormatting
            || configuration.needsNewTheme(comparedTo: previous!) {
            updatePresentation()
        }
        applyLineWrapping()
        enclosingScrollView?.rulersVisible = configuration.showsLineNumbers
        refreshCurrentLineHighlight()
    }

    private func applyLineWrapping() {
        guard let container = textContainer, let scrollView = enclosingScrollView else { return }
        let unbounded = CGFloat(Float.greatestFiniteMagnitude)
        if configuration.wrapsLines {
            scrollView.hasHorizontalScroller = false
            isHorizontallyResizable = false
            autoresizingMask = []
            container.widthTracksTextView = true
        } else {
            scrollView.hasHorizontalScroller = true
            isHorizontallyResizable = true
            autoresizingMask = []
            container.widthTracksTextView = false
            container.size = NSSize(width: unbounded, height: unbounded)
        }
        fitToScrollView()
    }

    /// Sizes the editor to its scroll view. The text view is created before SwiftUI gives
    /// the scroll view a size, and autoresizing doesn't reliably catch up, which would leave
    /// the text laid out in a zero-width container — invisible. The scroll view calls this
    /// whenever it lays out.
    func fitToScrollView() {
        guard let scrollView = enclosingScrollView else { return }
        let visible = scrollView.contentSize
        // Ignore the momentary tiny sizes SwiftUI passes through while laying out a split
        // view: laying the text out in them wraps after every character.
        guard visible.width >= Self.minimumLayoutWidth, visible.height > 0 else { return }
        // Fill the visible area, so clicking below the last line still places the caret.
        minSize = NSSize(width: configuration.wrapsLines ? 0 : visible.width, height: visible.height)
        if configuration.wrapsLines {
            if abs(frame.width - visible.width) > 0.5 {
                setFrameSize(NSSize(width: visible.width, height: max(frame.height, visible.height)))
            }
        } else if frame.width < visible.width {
            setFrameSize(NSSize(width: visible.width, height: max(frame.height, visible.height)))
        }
        if frame.height < visible.height {
            setFrameSize(NSSize(width: frame.width, height: visible.height))
        }
        // Keep the text container exactly as wide as the text area. Tracking the text view's
        // width only happens when its frame changes, so a container that got out of step
        // (for example sized while the window was still being laid out) would stay wrong.
        if configuration.wrapsLines, let container = textContainer {
            let width = max(frame.width - 2 * textContainerInset.width, Self.minimumLayoutWidth)
            if abs(container.size.width - width) > 0.5 {
                container.size = NSSize(width: width, height: CGFloat(Float.greatestFiniteMagnitude))
            }
        }
        lineNumberRuler?.needsDisplay = true
        // Not synchronously: the scroll view can lay out while the text is being laid out,
        // and asking for line geometry then would re-enter the layout manager.
        DispatchQueue.main.async { [weak self] in
            self?.refreshCurrentLineHighlight()
        }
    }

    /// The narrowest width the editor lays text out in.
    static let minimumLayoutWidth: CGFloat = 60

    // MARK: - Text

    /// Replaces the whole text without registering undo, for loading and reverting.
    func setText(_ text: String) {
        guard let storage = textStorage else { return }
        let selection = selectedRange()
        storage.beginEditing()
        storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: text)
        storage.endEditing()
        presentationLayoutManager?.flushPendingInvalidation()
        let length = storage.length
        setSelectedRange(NSRange(location: min(selection.location, length), length: 0))
        updatePresentation()
        lineNumberRuler?.textDidChange()
    }

    /// Replaces characters as a single, named, undoable edit.
    @discardableResult
    func replaceCharacters(in range: NSRange, with string: String, selecting selection: NSRange?, actionName: String?) -> Bool {
        breakUndoCoalescing()
        guard shouldChangeText(in: range, replacementString: string) else { return false }
        textStorage?.replaceCharacters(in: range, with: string)
        didChangeText()
        if let actionName {
            undoManager?.setActionName(actionName)
        }
        if let selection {
            setSelectedRange(selection)
        }
        return true
    }

    override func didChangeText() {
        super.didChangeText()
        presentationLayoutManager?.flushPendingInvalidation()
        updatePresentation()
        lineNumberRuler?.textDidChange()
        refreshCurrentLineHighlight()
    }

    fileprivate func textStorageWillProcessEditing(_ storage: NSTextStorage, editedMask: NSTextStorageEditActions, range: NSRange, delta: Int) {
        guard editedMask.contains(.editedCharacters) else { return }
        lineIndex.update(from: storage.mutableString, editedRange: range, changeInLength: delta)
        presentationTextWillChange(editedRange: range, changeInLength: delta)
        highlighter.highlight(storage, editedRange: range)
    }

    // MARK: - Current line

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard configuration.highlightsCurrentLine, let lineRect = currentLineRect else { return }
        let area = lineRect.intersection(rect).intersection(bounds)
        guard !area.isEmpty else { return }
        SyntaxPalette.currentLine.setFill()
        area.fill()
    }

    override func setSelectedRanges(_ ranges: [NSValue], affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelectingFlag)
        selectionDidChangeForPresentation()
        refreshCurrentLineHighlight()
        lineNumberRuler?.needsDisplay = true
    }

    private func refreshCurrentLineHighlight() {
        if let storage = textStorage, !storage.editedMask.isEmpty {
            // Layout isn't available while the storage is mid-edit; update afterwards.
            DispatchQueue.main.async { [weak self] in
                self?.refreshCurrentLineHighlight()
            }
            return
        }
        let newRect = configuration.highlightsCurrentLine ? computeCurrentLineRect() : nil
        guard newRect != currentLineRect else { return }
        if let old = currentLineRect {
            setNeedsDisplay(old)
        }
        if let newRect {
            setNeedsDisplay(newRect)
        }
        currentLineRect = newRect
    }

    private func computeCurrentLineRect() -> NSRect? {
        guard let layoutManager, let textContainer, let storage = textStorage else { return nil }
        let selection = selectedRange()
        guard selection.length == 0 else { return nil }
        let text = storage.mutableString
        let location = min(selection.location, text.length)

        var lineRect = NSRect.null
        let isOnTrailingEmptyLine = location == text.length && (text.length == 0 || text.character(at: text.length - 1) == Char.newline)
        if isOnTrailingEmptyLine {
            lineRect = layoutManager.extraLineFragmentRect
        } else {
            let paragraph = text.lineRange(for: NSRange(location: location, length: 0))
            let glyphs = layoutManager.glyphRange(forCharacterRange: paragraph, actualCharacterRange: nil)
            layoutManager.enumerateLineFragments(forGlyphRange: glyphs) { fragmentRect, _, _, _, _ in
                lineRect = lineRect.union(fragmentRect)
            }
        }
        guard !lineRect.isNull, lineRect.height > 0 else { return nil }
        return NSRect(x: 0, y: lineRect.minY + textContainerOrigin.y, width: bounds.width, height: lineRect.height)
    }

    // MARK: - Keyboard

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Accept Command-= as well as Command-+ for Bigger, as other Mac editors do.
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers == .command, event.charactersIgnoringModifiers == "=", window?.firstResponder === self {
            EditorPreferences.adjustFontSize(by: 1)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    // MARK: - Drag and drop

    override var acceptableDragTypes: [NSPasteboard.PasteboardType] {
        var types = super.acceptableDragTypes
        if !types.contains(.fileURL) {
            types.insert(.fileURL, at: 0)
        }
        return types
    }

    override func dragOperation(for dragInfo: NSDraggingInfo, type: NSPasteboard.PasteboardType) -> NSDragOperation {
        if type == .fileURL {
            return .copy
        }
        return super.dragOperation(for: dragInfo, type: type)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard sender.draggingSource == nil || (sender.draggingSource as? NSTextView) !== self,
              let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
              !urls.isEmpty,
              let formatter = droppedFilesFormatter else {
            return super.performDragOperation(sender)
        }
        let point = convert(sender.draggingLocation, from: nil)
        let location = characterIndexForInsertion(at: point)
        let insertion = formatter(urls)
        let range = NSRange(location: location, length: 0)
        let inserted = NSRange(location: location, length: (insertion as NSString).length)
        replaceCharacters(in: range, with: insertion, selecting: inserted, actionName: String(localized: "Insert Files"))
        window?.makeFirstResponder(self)
        return true
    }

    // MARK: - Typing

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        guard configuration.autoPairsBrackets,
              !hasMarkedText(),
              replacementRange.location == NSNotFound,
              let typed = insertString as? String,
              typed.utf16.count == 1,
              let text = textStorage?.mutableString else {
            super.insertText(insertString, replacementRange: replacementRange)
            suggestCompletionsIfUseful(afterTyping: insertString as? String)
            return
        }

        let character = typed.utf16[typed.utf16.startIndex]
        let selection = selectedRange()
        let previous: unichar? = selection.location > 0 ? text.character(at: selection.location - 1) : nil
        let next: unichar? = NSMaxRange(selection) < text.length ? text.character(at: NSMaxRange(selection)) : nil
        let isEscaped = previous == Char.backslash

        // Typing a closing character that is already there steps over it.
        if selection.length == 0, AutoPair.isCloser(character), next == character, !isEscaped {
            setSelectedRange(NSRange(location: selection.location + 1, length: 0))
            return
        }

        guard let closer = AutoPair.closer(for: character), !isEscaped else {
            super.insertText(insertString, replacementRange: replacementRange)
            return
        }
        let closing = String(decoding: [closer], as: UTF16.self)

        if selection.length > 0 {
            // Typing an opening character with a selection wraps the selection.
            let selected = text.substring(with: selection)
            super.insertText(typed + selected + closing, replacementRange: selection)
            setSelectedRange(NSRange(location: selection.location + 1, length: selection.length))
            return
        }

        let closesInlineMath = character == Char.dollar && Self.isInsideInlineMath(text, at: selection.location)
        if next.map(AutoPair.allowsPairing(before:)) ?? true, !closesInlineMath {
            super.insertText(typed + closing, replacementRange: selection)
            setSelectedRange(NSRange(location: selection.location + 1, length: 0))
        } else {
            super.insertText(insertString, replacementRange: replacementRange)
        }
        suggestCompletionsIfUseful(afterTyping: typed)
    }

    override func deleteBackward(_ sender: Any?) {
        guard !hasMarkedText(), let text = textStorage?.mutableString else {
            super.deleteBackward(sender)
            return
        }
        let selection = selectedRange()
        let location = selection.location
        guard selection.length == 0, location > 0 else {
            super.deleteBackward(sender)
            return
        }

        // Deleting just after a collapsed environment expands it instead of editing it unseen.
        if let fold = folds.first(where: { NSMaxRange($0.range) == location }) {
            unfold(fold)
            return
        }

        // Deleting the opening half of an empty pair deletes both halves.
        if configuration.autoPairsBrackets, location < text.length,
           let closer = AutoPair.closer(for: text.character(at: location - 1)),
           text.character(at: location) == closer,
           location < 2 || text.character(at: location - 2) != Char.backslash {
            setSelectedRange(NSRange(location: location - 1, length: 2))
            super.deleteBackward(sender)
            return
        }

        // In leading spaces, delete back to the previous indent stop.
        if configuration.indentsWithSpaces {
            let lineStart = text.lineRange(for: NSRange(location: location, length: 0)).location
            let column = location - lineStart
            if column > 1, text.substring(with: NSRange(location: lineStart, length: column)).allSatisfy({ $0 == " " }) {
                let width = max(configuration.indentWidth, 1)
                let count = column % width == 0 ? width : column % width
                setSelectedRange(NSRange(location: location - count, length: count))
                super.deleteBackward(sender)
                return
            }
        }
        super.deleteBackward(sender)
    }

    override func deleteForward(_ sender: Any?) {
        let selection = selectedRange()
        if selection.length == 0, let fold = folds.first(where: { $0.range.location == selection.location }) {
            unfold(fold)
            return
        }
        super.deleteForward(sender)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let replacement = presentationLayoutManager?.replacement(at: point) {
            window?.makeFirstResponder(self)
            switch replacement.kind {
            case .math(_, let region):
                // Clicking a formula edits it: its source appears with the caret at the end.
                setSelectedRange(NSRange(location: NSMaxRange(region.contentRange), length: 0))
            case .fold(let region, _):
                unfold(region)
                setSelectedRange(NSRange(location: region.range.location, length: 0))
            }
            return
        }
        super.mouseDown(with: event)
    }

    override func insertNewline(_ sender: Any?) {
        guard !hasMarkedText(), let text = textStorage?.mutableString else {
            super.insertNewline(sender)
            return
        }
        let selection = selectedRange()
        let line = text.lineRange(for: NSRange(location: selection.location, length: 0))
        let beforeCaret = text.substring(with: NSRange(location: line.location, length: selection.location - line.location))
        let indent = Self.leadingWhitespace(of: beforeCaret)
        let unit = configuration.indentUnit
        let trimmed = beforeCaret.trimmingCharacters(in: .whitespaces)
        let lineEnd = line.location + Self.contentLength(ofLine: line, in: text)
        let restOfLine = selection.length == 0 && selection.location <= lineEnd
            ? text.substring(with: NSRange(location: selection.location, length: lineEnd - selection.location))
            : ""
        let restIsBlank = restOfLine.trimmingCharacters(in: .whitespaces).isEmpty

        // Return just before the brace that closes \begin{name} steps over the brace first.
        if selection.length == 0, restOfLine.hasPrefix("}"),
           restOfLine.trimmingCharacters(in: .whitespaces) == "}",
           Self.environmentOpened(atEndOf: beforeCaret + "}") != nil {
            setSelectedRange(NSRange(location: selection.location + 1, length: 0))
            insertNewline(sender)
            return
        }

        // Return after \begin{…} closes the environment and indents its body.
        if configuration.autoClosesEnvironments, selection.length == 0, restIsBlank,
           let environment = Self.environmentOpened(atEndOf: beforeCaret),
           isEnvironmentUnclosed(environment) {
            let item = LaTeXLanguage.listEnvironments.contains(environment) ? "\\item " : ""
            let body = "\n" + indent + unit + item
            let closing = "\n" + indent + "\\end{\(environment)}"
            super.insertText(body + closing, replacementRange: selection)
            setSelectedRange(NSRange(location: selection.location + (body as NSString).length, length: 0))
            return
        }

        // Return on an empty \item leaves the list, like pressing Return on an empty bullet.
        if selection.length == 0, trimmed == "\\item", restIsBlank {
            exitList(emptyItemLine: line, in: text, indent: indent)
            return
        }

        // Return inside a list item starts the next item. Option-Return inserts a plain line break.
        if selection.length == 0, trimmed.hasPrefix("\\item") {
            super.insertText("\n" + indent + "\\item ", replacementRange: selection)
            return
        }

        // Return between a pair of braces opens an indented block.
        if selection.length == 0, trimmed.hasSuffix("{"), restOfLine.hasPrefix("}") {
            let body = "\n" + indent + unit
            super.insertText(body + "\n" + indent, replacementRange: selection)
            setSelectedRange(NSRange(location: selection.location + (body as NSString).length, length: 0))
            return
        }

        super.insertText("\n" + indent, replacementRange: selection)
    }

    override func insertTab(_ sender: Any?) {
        guard !hasMarkedText(), let text = textStorage?.mutableString else {
            super.insertTab(sender)
            return
        }
        let selection = selectedRange()
        if selection.length > 0, text.substring(with: selection).contains("\n") {
            shiftSelectedLines(right: true)
            return
        }
        guard configuration.indentsWithSpaces else {
            super.insertTab(sender)
            return
        }
        let lineStart = text.lineRange(for: NSRange(location: selection.location, length: 0)).location
        let width = max(configuration.indentWidth, 1)
        let column = selection.location - lineStart
        super.insertText(String(repeating: " ", count: width - column % width), replacementRange: selection)
    }

    override func insertBacktab(_ sender: Any?) {
        shiftSelectedLines(right: false)
    }

    private func exitList(emptyItemLine line: NSRange, in text: NSString, indent: String) {
        let nextLineStart = NSMaxRange(line)
        if nextLineStart < text.length {
            let nextLine = text.lineRange(for: NSRange(location: nextLineStart, length: 0))
            let nextContentLength = Self.contentLength(ofLine: nextLine, in: text)
            let nextContent = text.substring(with: NSRange(location: nextLine.location, length: nextContentLength))
            if nextContent.trimmingCharacters(in: .whitespaces).hasPrefix("\\end{") {
                // Remove the empty item and continue on a new line after \end{…}.
                let replacement = nextContent + "\n" + Self.leadingWhitespace(of: nextContent)
                let range = NSRange(location: line.location, length: nextLine.location + nextContentLength - line.location)
                let caret = NSRange(location: line.location + (replacement as NSString).length, length: 0)
                replaceCharacters(in: range, with: replacement, selecting: caret, actionName: nil)
                return
            }
        }
        // Otherwise just remove the empty \item.
        let itemRange = NSRange(location: line.location, length: selectedRange().location - line.location)
        replaceCharacters(in: itemRange, with: indent, selecting: NSRange(location: line.location + (indent as NSString).length, length: 0), actionName: nil)
    }

    private func isEnvironmentUnclosed(_ name: String) -> Bool {
        guard let text = textStorage?.mutableString else { return false }
        return Self.occurrences(of: "\\begin{\(name)}", in: text) > Self.occurrences(of: "\\end{\(name)}", in: text)
    }

    // MARK: - Completion

    override var rangeForUserCompletion: NSRange {
        let selection = selectedRange()
        guard selection.length == 0, let text = textStorage?.mutableString else {
            return super.rangeForUserCompletion
        }
        let inArgument = CompletionContext.argumentCommand(at: selection.location, in: text) != nil
        var start = selection.location
        while start > 0, CompletionContext.isWordCharacter(text.character(at: start - 1), inArgument: inArgument) {
            start -= 1
        }
        if start > 0, text.character(at: start - 1) == Char.backslash {
            start -= 1
        }
        return NSRange(location: start, length: selection.location - start)
    }

    override func insertCompletion(_ word: String, forPartialWordRange charRange: NSRange, movement: Int, isFinal flag: Bool) {
        super.insertCompletion(word, forPartialWordRange: charRange, movement: movement, isFinal: flag)
        let acceptedByKey = movement == NSTextMovement.return.rawValue || movement == NSTextMovement.tab.rawValue
        guard flag, acceptedByKey, let text = textStorage?.mutableString else { return }
        let end = charRange.location + (word as NSString).length

        if word.hasPrefix("\\") {
            // A command that takes an argument gets its braces, with the caret inside.
            let name = String(word.dropFirst())
            let hasBrace = end < text.length && text.character(at: end) == Char.openBrace
            guard LaTeXCatalog.commandsTakingArgument.contains(name), !hasBrace else { return }
            replaceCharacters(in: NSRange(location: end, length: 0), with: "{}", selecting: NSRange(location: end + 1, length: 0), actionName: nil)
            suggestCompletionsIfUseful(afterTyping: "{")
            return
        }

        // An environment chosen inside \begin{…} is closed straight away.
        guard configuration.autoClosesEnvironments,
              CompletionContext.argumentCommand(at: charRange.location, in: text) == "begin",
              end < text.length, text.character(at: end) == Char.closeBrace else { return }
        setSelectedRange(NSRange(location: end + 1, length: 0))
        insertNewline(nil)
    }

    /// Offers completions automatically after `{` where the choices are hard to remember:
    /// environments, labels, citation keys, packages and files.
    private func suggestCompletionsIfUseful(afterTyping typed: String?) {
        guard configuration.suggestsCompletions, typed == "{" else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window?.firstResponder === self, !self.hasMarkedText() else { return }
            guard let text = self.textStorage?.mutableString else { return }
            let caret = self.selectedRange().location
            guard let command = CompletionContext.argumentCommand(at: caret, in: text),
                  CompletionContext.suggestsAutomatically(forArgumentOf: command),
                  self.hasCompletions?(self.rangeForUserCompletion) == true else { return }
            self.complete(nil)
        }
    }
}

/// Bracket pairs the editor completes as you type.
nonisolated enum AutoPair {
    static func closer(for opener: unichar) -> unichar? {
        switch opener {
        case Char.openBrace: Char.closeBrace
        case Char.openBracket: Char.closeBracket
        case Char.openParen: Char.closeParen
        case Char.dollar: Char.dollar
        default: nil
        }
    }

    static func isCloser(_ character: unichar) -> Bool {
        character == Char.closeBrace || character == Char.closeBracket
            || character == Char.closeParen || character == Char.dollar
    }

    /// Pairs are only inserted before whitespace or punctuation, so typing in the middle of
    /// a word behaves normally.
    static func allowsPairing(before next: unichar) -> Bool {
        Char.isWhitespace(next) || isCloser(next)
            || next == Char.comma || next == 0x2E || next == 0x3B || next == 0x3A
    }
}

/// The editor's scroll view. It keeps the text view as wide as the visible area (when
/// wrapping) every time it lays out, including the first layout after SwiftUI sizes it.
final class EditorScrollView: NSScrollView {
    override func tile() {
        super.tile()
        (documentView as? SourceTextView)?.fitToScrollView()
    }
}

/// Forwards text storage edits to the editor, which keeps its line index and colouring in
/// step before the edit is laid out.
private final class StorageObserver: NSObject, NSTextStorageDelegate {
    weak var textView: SourceTextView?

    func textStorage(_ textStorage: NSTextStorage, willProcessEditing editedMask: NSTextStorageEditActions, range editedRange: NSRange, changeInLength delta: Int) {
        textView?.textStorageWillProcessEditing(textStorage, editedMask: editedMask, range: editedRange, delta: delta)
    }
}
