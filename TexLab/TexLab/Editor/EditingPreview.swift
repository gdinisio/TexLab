//
//  EditingPreview.swift
//  TexLab
//

import AppKit
import CoreGraphics
import Foundation

/// What the editing preview shows: the typeset version of the formula, drawing, table or
/// picture whose source is being edited.
struct EditingPreviewContent {
    enum Style {
        /// A formula, drawn in the text colour.
        case math
        /// A TikZ drawing or a table, on its piece of paper.
        case paper
        /// An image, as it is.
        case picture
    }

    enum Status {
        case current
        /// The source has changed since; the new version is being typeset.
        case updating
        /// TeX can't typeset the source as it is now, so the last version that worked is
        /// shown.
        case failed
    }

    var image: NSImage
    /// The size the artwork is drawn at.
    var size: CGSize
    var style: Style
    var status: Status = .current
}

/// A small panel of Liquid Glass floating beside the source being edited, with its typeset
/// version, so the source and what it makes are both in view. It follows each change, and
/// shows the last version that typeset, dimmed, while TeX catches up. Clicks pass through
/// it to the text.
final class EditingPreviewView: NSView {
    static let padding: CGFloat = 10
    /// Room for the progress or problem indicator beside the artwork.
    private static let indicatorWidth: CGFloat = 22

    private let glass = NSGlassEffectView()
    private let container = FlippedView()
    private let artwork = ArtworkView()
    private let spinner = NSProgressIndicator()
    private let warning = NSImageView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        glass.cornerRadius = 14
        glass.frame = bounds
        glass.autoresizingMask = [.width, .height]
        container.frame = bounds
        container.autoresizingMask = [.width, .height]
        glass.contentView = container
        addSubview(glass)

        container.addSubview(artwork)
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        container.addSubview(spinner)
        warning.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: String(localized: "Can’t typeset"))?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .medium).applying(.preferringMulticolor()))
        warning.isHidden = true
        container.addSubview(warning)

        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel(String(localized: "Typeset preview"))
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override var isFlipped: Bool { true }

    /// Clicks go to the text beneath; the preview is only to look at.
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    /// The panel's size for `content`.
    static func size(for content: EditingPreviewContent) -> NSSize {
        let indicator = content.status == .current ? 0 : indicatorWidth
        return NSSize(width: ceil(content.size.width + 2 * padding + indicator), height: ceil(content.size.height + 2 * padding))
    }

    func show(_ content: EditingPreviewContent) {
        artwork.content = content
        artwork.frame = NSRect(x: Self.padding, y: Self.padding, width: content.size.width, height: content.size.height)
        let indicatorX = Self.padding + content.size.width + 6
        spinner.frame = NSRect(x: indicatorX, y: Self.padding, width: 16, height: 16)
        warning.frame = NSRect(x: indicatorX, y: Self.padding, width: 16, height: 16)
        switch content.status {
        case .current:
            spinner.stopAnimation(nil)
            warning.isHidden = true
            setAccessibilityHelp(nil)
        case .updating:
            spinner.startAnimation(nil)
            warning.isHidden = true
            setAccessibilityHelp(String(localized: "Typesetting the changes"))
        case .failed:
            spinner.stopAnimation(nil)
            warning.isHidden = false
            setAccessibilityHelp(String(localized: "TeX can’t typeset the source as it is; the last version that worked is shown"))
        }
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// Draws the artwork: a formula in the text colour, a drawing or table on paper, or an
/// image, dimmed while it's out of date.
private final class ArtworkView: NSView {
    var content: EditingPreviewContent? {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let content, let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.setAlpha(content.status == .current ? 1 : 0.45)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        switch content.style {
        case .math:
            Replacement.drawTinted(content.image, in: bounds, color: .labelColor)
        case .paper:
            RenderedPaper.draw(content.image, in: bounds)
        case .picture:
            NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).addClip()
            content.image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
        context.endTransparencyLayer()
        context.restoreGState()
    }
}

// MARK: - The editor

/// The editing preview in the editor: while the insertion point is in a formula, a TikZ
/// drawing, a table, an `\includegraphics` or an `\input` of a figure, its typeset version
/// floats just below the source (or above, when there's no room below or the completion
/// list is there), in both the Code and the Visual editor.
extension SourceTextView {
    /// Shows, updates, moves or hides the preview for what the insertion point is in.
    func updateEditingPreview() {
        guard window?.firstResponder === self, let current = currentEditingPreview() else {
            hideEditingPreview()
            return
        }
        if current.content.status == .current {
            editingPreviewLast = (current.anchor, current.content)
        } else {
            editingPreviewLast?.anchor = current.anchor
        }
        let preview: EditingPreviewView
        if let existing = editingPreview {
            preview = existing
        } else {
            preview = EditingPreviewView(frame: .zero)
            preview.isHidden = true
            addSubview(preview)
            editingPreview = preview
        }
        let wasHidden = preview.isHidden
        preview.show(current.content)
        preview.setFrameSize(EditingPreviewView.size(for: current.content))
        positionEditingPreview(around: current.anchor)
        if wasHidden {
            preview.alphaValue = 0
            preview.isHidden = false
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                preview.animator().alphaValue = 1
            }
        }
    }

    func hideEditingPreview() {
        editingPreviewLast = nil
        editingPreview?.isHidden = true
    }

    /// Moves the preview after scrolling or resizing, keeping what it shows.
    func repositionEditingPreview() {
        guard let preview = editingPreview, !preview.isHidden, let anchor = editingPreviewLast?.anchor else { return }
        positionEditingPreview(around: anchor)
    }

    /// Keeps the source the preview belongs to in step with an edit, while the text storage
    /// processes it: an edit in it or at its edges grows or shrinks it, so the preview stays
    /// until the next analysis finds the formula again.
    func editingPreviewTextWillChange(editedRange: NSRange, changeInLength delta: Int) {
        guard var last = editingPreviewLast else { return }
        let oldEnd = NSMaxRange(editedRange) - delta
        let anchor = last.anchor
        if NSMaxRange(anchor) < editedRange.location {
            return
        }
        if anchor.location > oldEnd {
            last.anchor.location += delta
        } else {
            let start = min(anchor.location, editedRange.location)
            let end = max(NSMaxRange(anchor) + delta, NSMaxRange(editedRange))
            last.anchor = NSRange(location: start, length: max(end - start, 0))
        }
        editingPreviewLast = last
    }

    /// Forgets the last version shown once the source it belonged to is gone — the formula
    /// was deleted, say — rather than showing it as out of date.
    func editingPreviewRegionsDidChange() {
        guard let anchor = editingPreviewLast?.anchor else { return }
        let stillThere = mathRegions.contains { Self.meets($0.range, anchor) }
            || visualElements.contains { $0.label != nil && Self.meets($0.range, anchor) }
        if !stillThere {
            editingPreviewLast = nil
        }
    }

    // MARK: - What to show

    private func currentEditingPreview() -> (anchor: NSRange, content: EditingPreviewContent)? {
        guard configuration.previewsWhileEditing, let storage = textStorage, !hasMarkedText() else { return nil }
        let selection = selectedRange()
        let length = storage.length
        func touches(_ range: NSRange) -> Bool {
            NSMaxRange(range) <= length && selection.location <= NSMaxRange(range) && NSMaxRange(selection) >= range.location
        }

        // A formula, drawing or table. A one- or two-letter formula such as $n$ needs no
        // preview.
        if let region = mathRegions.first(where: { touches($0.range) && ($0.isBlock || $0.isDisplay || $0.snippet.count > 2) }),
           !folds.contains(where: { NSIntersectionRange($0.range, region.range).length > 0 }) {
            if let math = renderedMath[region.key] {
                return (region.range, editingPreviewContent(for: math, isBlock: region.isBlock))
            }
            guard let last = editingPreviewLast, Self.meets(last.anchor, region.range) else { return nil }
            var stale = last.content
            stale.status = failedRenderKeys.contains(region.key) ? .failed : .updating
            return (region.range, stale)
        }

        // A picture, or a file holding a figure, drawing or table.
        for element in visualElements where touches(element.range) {
            switch element.label?.kind {
            case .picture(let path)?:
                if let image = thumbnail(for: path) {
                    return (element.range, editingPreviewContent(forPicture: image))
                }
            case .inclusion(let path)?:
                guard let preview = inclusionPreviews[path] else { continue }
                if let block = preview.block, let math = renderedMath[block.key] {
                    return (element.range, editingPreviewContent(for: math, isBlock: true))
                }
                if let imagePath = preview.imagePath, let image = thumbnail(for: imagePath) {
                    return (element.range, editingPreviewContent(forPicture: image))
                }
            default:
                continue
            }
        }

        // A formula being edited, which the next analysis will find again.
        if let last = editingPreviewLast, touches(last.anchor) {
            var stale = last.content
            stale.status = .updating
            return (last.anchor, stale)
        }
        return nil
    }

    /// Formulas a little larger than the text, so the details are easy to read; drawings
    /// and tables at the size the Visual editor shows them.
    private func editingPreviewContent(for math: MathImage, isBlock: Bool) -> EditingPreviewContent {
        let font = highlighter.theme.font
        let maxWidth = min(presentationWidth * 0.9, 680)
        if isBlock {
            let lineHeight = layoutManager?.defaultLineHeight(for: font) ?? font.pointSize * 1.2
            let fitted = RenderedPaper.fittedSize(of: math.size, scale: max(font.pointSize, 13) / 10, availableWidth: maxWidth, lineHeight: lineHeight)
            let size = CGSize(width: fitted.width + 2 * RenderedPaper.padding, height: fitted.height + 2 * RenderedPaper.padding)
            return EditingPreviewContent(image: math.image, size: size, style: .paper)
        }
        let scale = min(max(font.pointSize, 13) / 10 * 1.25, maxWidth / max(math.size.width, 1), 240 / max(math.size.height, 1))
        return EditingPreviewContent(image: math.image, size: CGSize(width: ceil(math.size.width * scale), height: ceil(math.size.height * scale)), style: .math)
    }

    private func editingPreviewContent(forPicture image: NSImage) -> EditingPreviewContent {
        guard image.size.width > 0, image.size.height > 0 else {
            return EditingPreviewContent(image: image, size: CGSize(width: 1, height: 1), style: .picture)
        }
        let scale = min(320 / image.size.width, 220 / image.size.height, 1)
        return EditingPreviewContent(image: image, size: CGSize(width: ceil(image.size.width * scale), height: ceil(image.size.height * scale)), style: .picture)
    }

    // MARK: - Where

    /// Below the source, or above it when there's no room below or the completion list is
    /// there; when the source is taller than the window, at the edge away from the
    /// insertion point.
    private func positionEditingPreview(around anchor: NSRange) {
        guard let preview = editingPreview, let layoutManager, let textContainer, let storage = textStorage else { return }
        let location = min(anchor.location, storage.length)
        let range = NSRange(location: location, length: min(anchor.length, storage.length - location))
        let glyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var source = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer)
        source.origin.x += textContainerOrigin.x
        source.origin.y += textContainerOrigin.y

        let size = preview.frame.size
        let visible = visibleRect
        let gap: CGFloat = 6
        let margin: CGFloat = 8
        let below = source.maxY + gap
        let above = source.minY - gap - size.height
        let fitsBelow = below + size.height <= visible.maxY - margin
        let fitsAbove = above >= visible.minY + margin
        var y: CGFloat
        if completionPopup.isVisible && fitsAbove {
            y = above
        } else if fitsBelow {
            y = below
        } else if fitsAbove {
            y = above
        } else {
            let caret = layoutManager.boundingRect(forGlyphRange: layoutManager.glyphRange(forCharacterRange: NSRange(location: min(selectedRange().location, storage.length), length: 0), actualCharacterRange: nil), in: textContainer)
            let caretY = caret.midY + textContainerOrigin.y
            y = caretY > visible.midY ? visible.minY + margin : visible.maxY - margin - size.height
        }
        let x = min(max(source.minX, visible.minX + margin), max(visible.maxX - size.width - margin, visible.minX + margin))
        preview.setFrameOrigin(NSPoint(x: x.rounded(), y: y.rounded()))
    }

    /// Whether two ranges overlap or touch.
    private static func meets(_ lhs: NSRange, _ rhs: NSRange) -> Bool {
        lhs.location <= NSMaxRange(rhs) && rhs.location <= NSMaxRange(lhs)
    }

    // MARK: - Following the view

    /// Moves the preview along when the editor scrolls or changes size.
    func followScrollingForEditingPreview() {
        for observer in editingPreviewObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        editingPreviewObservers = []
        guard let clipView = enclosingScrollView?.contentView else { return }
        clipView.postsBoundsChangedNotifications = true
        clipView.postsFrameChangedNotifications = true
        for name in [NSView.boundsDidChangeNotification, NSView.frameDidChangeNotification] {
            editingPreviewObservers.append(NotificationCenter.default.addObserver(forName: name, object: clipView, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.repositionEditingPreview()
                }
            })
        }
    }
}
