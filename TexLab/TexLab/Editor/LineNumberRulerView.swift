//
//  LineNumberRulerView.swift
//  TexLab
//

import AppKit
import CoreGraphics
import Foundation

/// The severity of an issue marked in the editor's gutter.
nonisolated enum IssueMarker: Int, Comparable, Sendable {
    case warning = 1
    case error = 2

    static func < (lhs: IssueMarker, rhs: IssueMarker) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The editor's gutter: line numbers, the current line in full contrast, a dot on lines
/// with typesetting issues, and fold controls. Clicking a number selects that line;
/// clicking a chevron collapses or expands the environment starting there.
final class LineNumberRulerView: NSRulerView {
    private weak var sourceView: SourceTextView?
    private var numberFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    private var digitCount = 0
    /// The pointer's position in the gutter while it's over it, for showing fold controls.
    private var hoverPoint: NSPoint?
    private var hoverTrackingArea: NSTrackingArea?
    /// Width of the fold control column at the right edge.
    private let foldColumnWidth: CGFloat = 14

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
        clipsToBounds = true
        updateTrackingAreas()

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
        ruleThickness = ceil(digitWidth * CGFloat(digits) + 22 + foldColumnWidth)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        // Since macOS 14 views don't clip their drawing by default and the dirty rect can
        // extend past the gutter, so filling it would paint over the editor's text.
        let area = dirtyRect.intersection(bounds)
        guard !area.isEmpty else { return }
        NSColor.textBackgroundColor.setFill()
        area.fill()
        drawHashMarksAndLabels(in: area)
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

        let presentation = textView.presentationLayoutManager
        let foldControls = foldControlsByLine(in: textView)

        var line = lineIndex.lineNumber(at: visibleCharacters.location)
        while line <= lineIndex.lineCount {
            let start = lineIndex.startOfLine(line)
            guard start < text.length, start <= NSMaxRange(visibleCharacters) else { break }
            line += 1
            // Lines inside a collapsed environment or a rendered formula aren't shown, nor
            // lines the visual preview hides, such as \begin{itemize}.
            if let presentation, presentation.isHidden(start)
                || presentation.isLineHidden(NSRange(location: start, length: lineIndex.startOfLine(line) - start)) && line <= lineIndex.lineCount {
                continue
            }
            let glyph = layoutManager.glyphIndexForCharacter(at: start)
            let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let baseline = fragment.minY + layoutManager.location(forGlyphAt: glyph).y + containerOrigin.y
            drawNumber(line - 1, atBaseline: baseline, in: textView, isCurrent: (firstSelectedLine...lastSelectedLine).contains(line - 1))
            if let control = foldControls[line - 1] {
                let isHovered = hoverPoint.map { abs(convert(NSPoint(x: 0, y: baseline), from: textView).y - numberFont.xHeight / 2 - $0.y) < fragment.height / 2 } ?? false
                drawFoldControl(isFolded: control.isFolded, isHovered: isHovered, atBaseline: baseline, in: textView)
            }
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
        label.draw(at: NSPoint(x: ruleThickness - foldColumnWidth - size.width - 4, y: y - numberFont.ascender), withAttributes: attributes)

        if let marker = issueMarkers[line] {
            let diameter: CGFloat = 7
            let dot = NSRect(x: 5, y: y - numberFont.xHeight / 2 - diameter / 2, width: diameter, height: diameter)
            (marker == .error ? NSColor.systemRed : NSColor.systemYellow).setFill()
            NSBezierPath(ovalIn: dot).fill()
        }
    }

    // MARK: - Folding

    private struct FoldControl {
        var region: FoldableRegion
        var isFolded: Bool
    }

    /// The outermost foldable environment starting on each line. Collapsed ones always show
    /// their chevron; the others only while the pointer is over the gutter, as in Xcode.
    private func foldControlsByLine(in textView: SourceTextView) -> [Int: FoldControl] {
        var controls: [Int: FoldControl] = [:]
        let showsAll = isPointerInside
        for region in textView.foldableRegions {
            let line = textView.lineIndex.lineNumber(at: region.range.location)
            let isFolded = textView.isFolded(region)
            guard isFolded || showsAll else { continue }
            if let existing = controls[line], existing.region.range.length >= region.range.length, !isFolded {
                continue
            }
            controls[line] = FoldControl(region: region, isFolded: isFolded)
        }
        return controls
    }

    private func drawFoldControl(isFolded: Bool, isHovered: Bool, atBaseline baseline: CGFloat, in textView: NSTextView) {
        let y = convert(NSPoint(x: 0, y: baseline), from: textView).y
        let color: NSColor = isFolded ? .controlAccentColor : (isHovered ? .labelColor : .secondaryLabelColor)
        let configuration = NSImage.SymbolConfiguration(pointSize: max(numberFont.pointSize - 2, 8), weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        guard let symbol = NSImage(systemSymbolName: isFolded ? "chevron.right" : "chevron.down", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else { return }
        let size = symbol.size
        let center = NSPoint(x: ruleThickness - foldColumnWidth / 2 - 1, y: y - numberFont.xHeight / 2)
        let rect = NSRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
        symbol.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        // Always active and covering the whole gutter, so the chevrons appear whenever the
        // pointer is over it, even while another window is key.
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect, .cursorUpdate],
            owner: self
        )
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        updateHover(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        updateHover(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        hoverPoint = nil
        needsDisplay = true
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    private func updateHover(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let newPoint: NSPoint? = bounds.contains(point) ? point : nil
        guard newPoint != hoverPoint else { return }
        hoverPoint = newPoint
        needsDisplay = true
    }

    /// Whether the pointer is over the gutter, checked directly as well, in case a tracking
    /// event was missed while the editor scrolled under it.
    private var isPointerInside: Bool {
        if hoverPoint != nil { return true }
        guard let window else { return false }
        return bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil))
    }

    // MARK: - Interaction

    override func mouseDown(with event: NSEvent) {
        guard let textView = sourceView, let storage = textView.textStorage else { return }
        let point = textView.convert(event.locationInWindow, from: nil)
        let location = textView.characterIndexForInsertion(at: NSPoint(x: textView.textContainerOrigin.x, y: point.y))
        let clamped = min(location, storage.length)

        // A click in the fold column collapses or expands the environment on that line.
        let localPoint = convert(event.locationInWindow, from: nil)
        if localPoint.x >= ruleThickness - foldColumnWidth - 2 {
            let lineNumber = textView.lineIndex.lineNumber(at: clamped)
            if let control = foldControlsByLine(in: textView)[lineNumber] ?? foldControl(forLine: lineNumber, in: textView) {
                textView.toggleFold(control.region)
                needsDisplay = true
                return
            }
        }

        let line = storage.mutableString.lineRange(for: NSRange(location: clamped, length: 0))
        textView.setSelectedRange(line)
        textView.window?.makeFirstResponder(textView)
    }

    /// The fold control for a line regardless of hover, for clicks.
    private func foldControl(forLine line: Int, in textView: SourceTextView) -> FoldControl? {
        let regions = textView.foldableRegions.filter { textView.lineIndex.lineNumber(at: $0.range.location) == line }
        guard let region = regions.max(by: { $0.range.length < $1.range.length }) else { return nil }
        return FoldControl(region: region, isFolded: textView.isFolded(region))
    }
}
