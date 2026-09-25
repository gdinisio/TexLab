//
//  LineNumberRulerView.swift
//  TexLab
//

import AppKit

/// The severity of an issue marked in the editor's gutter.
nonisolated enum IssueMarker: Int, Comparable, Sendable {
    case warning = 1
    case error = 2

    static func < (lhs: IssueMarker, rhs: IssueMarker) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The editor's gutter: line numbers, the current line in full contrast, and a dot on lines
/// with typesetting issues. Clicking a number selects that line.
final class LineNumberRulerView: NSRulerView {
    private weak var sourceView: SourceTextView?
    private var numberFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    private var digitCount = 0

    /// Issues by 1-based line number.
    var issueMarkers: [Int: IssueMarker] = [:] {
        didSet { needsDisplay = true }
    }

    init(textView: SourceTextView, scrollView: NSScrollView) {
        sourceView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        reservedThicknessForMarkers = 0
        reservedThicknessForAccessoryView = 0
        updateThickness()
        setAccessibilityElement(false)

        let clipView = scrollView.contentView
        clipView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(visibleTextDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: clipView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(visibleTextDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: textView
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool { true }

    @objc private func visibleTextDidChange(_ notification: Notification) {
        needsDisplay = true
    }

    /// Call after the text changes, so the gutter can grow for more digits.
    func textDidChange() {
        updateThickness()
        needsDisplay = true
    }

    /// Call after the editor font changes.
    func editorFontDidChange() {
        let size = max((sourceView?.highlighter.theme.font.pointSize ?? 13) - 2, 9)
        numberFont = NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular)
        digitCount = 0
        updateThickness()
        needsDisplay = true
    }

    private func updateThickness() {
        let lineCount = sourceView?.lineIndex.lineCount ?? 1
        let digits = max(String(lineCount).count, 3)
        guard digits != digitCount else { return }
        digitCount = digits
        let digitWidth = ("0" as NSString).size(withAttributes: [.font: numberFont]).width
        ruleThickness = ceil(digitWidth * CGFloat(digits) + 22)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.textBackgroundColor.setFill()
        dirtyRect.fill()
        drawHashMarksAndLabels(in: dirtyRect)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = sourceView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let storage = textView.textStorage else { return }

        let text = storage.mutableString
        let lineIndex = textView.lineIndex
        let containerOrigin = textView.textContainerOrigin
        let visibleRect = textView.visibleRect.offsetBy(dx: -containerOrigin.x, dy: -containerOrigin.y)
        let visibleGlyphs = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let visibleCharacters = layoutManager.characterRange(forGlyphRange: visibleGlyphs, actualGlyphRange: nil)

        let selection = textView.selectedRange()
        let firstSelectedLine = lineIndex.lineNumber(at: selection.location)
        let lastSelectedLine = lineIndex.lineNumber(at: max(selection.location, NSMaxRange(selection) - (selection.length > 0 ? 1 : 0)))

        var line = lineIndex.lineNumber(at: visibleCharacters.location)
        while line <= lineIndex.lineCount {
            let start = lineIndex.startOfLine(line)
            guard start < text.length, start <= NSMaxRange(visibleCharacters) else { break }
            let glyph = layoutManager.glyphIndexForCharacter(at: start)
            let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let baseline = fragment.minY + layoutManager.location(forGlyphAt: glyph).y + containerOrigin.y
            drawNumber(line, atBaseline: baseline, in: textView, isCurrent: (firstSelectedLine...lastSelectedLine).contains(line))
            line += 1
        }

        // The empty line after a final line break has its own fragment.
        if layoutManager.extraLineFragmentTextContainer != nil, text.length == lineIndex.startOfLine(lineIndex.lineCount) {
            let fragment = layoutManager.extraLineFragmentRect
            let font = textView.highlighter.theme.font
            let baseline = fragment.maxY + font.descender + containerOrigin.y
            drawNumber(lineIndex.lineCount, atBaseline: baseline, in: textView, isCurrent: lastSelectedLine == lineIndex.lineCount)
        }
    }

    private func drawNumber(_ line: Int, atBaseline baseline: CGFloat, in textView: NSTextView, isCurrent: Bool) {
        let y = convert(NSPoint(x: 0, y: baseline), from: textView).y
        let attributes: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: isCurrent ? NSColor.labelColor : NSColor.secondaryLabelColor,
        ]
        let label = String(line) as NSString
        let size = label.size(withAttributes: attributes)
        label.draw(at: NSPoint(x: ruleThickness - size.width - 8, y: y - numberFont.ascender), withAttributes: attributes)

        if let marker = issueMarkers[line] {
            let diameter: CGFloat = 7
            let dot = NSRect(x: 5, y: y - numberFont.xHeight / 2 - diameter / 2, width: diameter, height: diameter)
            (marker == .error ? NSColor.systemRed : NSColor.systemYellow).setFill()
            NSBezierPath(ovalIn: dot).fill()
        }
    }

    // MARK: - Interaction

    override func mouseDown(with event: NSEvent) {
        guard let textView = sourceView, let storage = textView.textStorage else { return }
        let point = textView.convert(event.locationInWindow, from: nil)
        let location = textView.characterIndexForInsertion(at: NSPoint(x: textView.textContainerOrigin.x, y: point.y))
        let line = storage.mutableString.lineRange(for: NSRange(location: min(location, storage.length), length: 0))
        textView.setSelectedRange(line)
        textView.window?.makeFirstResponder(textView)
    }
}
