//
//  PresentationLayoutManager.swift
//  TexLab
//

import AppKit
import CoreGraphics
import Foundation

/// A rendered formula ready to draw.
final class MathImage {
    let image: NSImage
    /// Size in PDF points for 10 pt text.
    let size: CGSize
    let depth: CGFloat

    init?(_ rendered: RenderedMath) {
        guard let image = NSImage(data: rendered.pdfData) else { return nil }
        self.image = image
        size = rendered.size
        depth = rendered.depth
    }
}

/// A source range the editor shows as something else: a rendered formula, or a collapsed
/// environment. The text itself is never changed — only how it is laid out.
final class Replacement {
    enum Kind {
        case math(MathImage, region: MathRegion)
        case fold(FoldableRegion, thumbnail: NSImage?)
        /// Markup hidden without a drawing, such as the `\emph{` and `}` around emphasis.
        case hidden
        /// Markup shown as a drawing: a bullet, a reference chip, a heading or a figure.
        case label(VisualLabel, image: NSImage?)
    }

    var isHidden: Bool {
        if case .hidden = kind { return true }
        return false
    }

    let range: NSRange
    let kind: Kind
    /// Width and height of what is drawn.
    let size: CGSize
    /// How far the drawing reaches below the baseline.
    let descent: CGFloat
    /// Centred on its own line, like display math in the PDF.
    let fillsLine: Bool
    /// Distinguishes replacements that look different, for updating only what changed.
    let identity: String

    init(range: NSRange, kind: Kind, size: CGSize, descent: CGFloat, fillsLine: Bool, identity: String) {
        self.range = range
        self.kind = kind
        self.size = size
        self.descent = descent
        self.fillsLine = fillsLine
        self.identity = identity
    }

    func movingBy(_ delta: Int) -> Replacement {
        Replacement(range: NSRange(location: range.location + delta, length: range.length), kind: kind, size: size, descent: descent, fillsLine: fillsLine, identity: identity)
    }

    /// Draws the replacement in `rect` (flipped view coordinates).
    func draw(in rect: NSRect, font: NSFont) {
        switch kind {
        case .math(let math, _):
            drawTinted(math.image, in: rect)
        case .fold(let region, let thumbnail):
            FoldChip.draw(region, thumbnail: thumbnail, in: rect, font: font)
        case .hidden:
            break
        case .label(let label, let image):
            VisualLabelRenderer.draw(label, image: image, in: rect, font: font)
        }
    }

    /// Draws black-on-clear artwork in the current text colour, so formulas follow Dark Mode.
    private func drawTinted(_ image: NSImage, in rect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        context.beginTransparencyLayer(in: rect, auxiliaryInfo: nil)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        NSColor.textColor.setFill()
        rect.fill(using: .sourceAtop)
        context.endTransparencyLayer()
        context.restoreGState()
    }
}

/// The look of a collapsed environment: a rounded chip with an icon, a summary, the line
/// count and, for figures, a thumbnail of the image.
enum FoldChip {
    static let padding: CGFloat = 6
    static let thumbnailMaxWidth: CGFloat = 120

    static func attributedSummary(for region: FoldableRegion, font: NSFont) -> NSAttributedString {
        let text = NSMutableAttributedString(string: region.summary, attributes: [
            .font: NSFont.systemFont(ofSize: font.pointSize - 1, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
        text.append(NSAttributedString(string: "  " + String(localized: "\(region.lineCount) lines"), attributes: [
            .font: NSFont.systemFont(ofSize: font.pointSize - 2),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]))
        return text
    }

    /// The chip's size for a line of `lineHeight`.
    static func size(for region: FoldableRegion, thumbnail: NSImage?, font: NSFont, lineHeight: CGFloat) -> CGSize {
        let textWidth = ceil(attributedSummary(for: region, font: font).size().width)
        let iconWidth = font.pointSize + 4
        var width = padding + iconWidth + textWidth + padding
        var height = lineHeight
        if let thumbnail {
            let size = thumbnailSize(for: thumbnail, lineHeight: lineHeight)
            width += size.width + padding
            height = max(height, size.height + 2 * padding)
        }
        return CGSize(width: width, height: height)
    }

    static func thumbnailSize(for image: NSImage, lineHeight: CGFloat) -> CGSize {
        let maxHeight = lineHeight * 3.5
        guard image.size.width > 0, image.size.height > 0 else { return .zero }
        let scale = min(maxHeight / image.size.height, thumbnailMaxWidth / image.size.width)
        return CGSize(width: image.size.width * scale, height: image.size.height * scale)
    }

    static func draw(_ region: FoldableRegion, thumbnail: NSImage?, in rect: NSRect, font: NSFont) {
        let chip = NSBezierPath(roundedRect: rect.insetBy(dx: 0, dy: 1), xRadius: 6, yRadius: 6)
        NSColor.labelColor.withAlphaComponent(0.07).setFill()
        chip.fill()
        NSColor.separatorColor.setStroke()
        chip.lineWidth = 0.5
        chip.stroke()

        var x = rect.minX + padding
        if let thumbnail {
            let size = thumbnailSize(for: thumbnail, lineHeight: rect.height)
            let imageRect = NSRect(x: x, y: rect.midY - size.height / 2, width: size.width, height: size.height)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: imageRect, xRadius: 3, yRadius: 3).addClip()
            thumbnail.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            NSGraphicsContext.restoreGraphicsState()
            x += size.width + padding
        }

        let iconSize = font.pointSize
        if let symbol = NSImage(systemSymbolName: region.systemImage, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: iconSize - 2, weight: .medium)
                .applying(NSImage.SymbolConfiguration(paletteColors: [.secondaryLabelColor]))) {
            let symbolSize = symbol.size
            let symbolRect = NSRect(x: x + (iconSize - symbolSize.width) / 2, y: rect.midY - symbolSize.height / 2, width: symbolSize.width, height: symbolSize.height)
            symbol.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
        x += iconSize + 4

        let text = attributedSummary(for: region, font: font)
        let textSize = text.size()
        let available = rect.maxX - padding - x
        text.draw(with: NSRect(x: x, y: rect.midY - textSize.height / 2, width: max(available, 0), height: textSize.height),
                  options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
    }
}

/// Lays out the source with some ranges replaced by drawings, using the standard TextKit 1
/// technique: the replaced characters get null glyphs, except the first, which becomes a
/// control glyph as wide as the drawing; line breaks inside get zero advancement, and the
/// line grows to fit the drawing's height.
final class PresentationLayoutManager: NSLayoutManager, NSLayoutManagerDelegate {
    /// Sorted by location, never overlapping.
    private(set) var replacements: [Replacement] = []
    /// Where each replacement was last drawn, by anchor location, in text view coordinates.
    private var drawnRects: [Int: NSRect] = [:]
    /// Ranges whose glyphs must be regenerated once the current edit has finished.
    private var pendingInvalidation: [NSRange] = []

    override init() {
        super.init()
        delegate = self
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        delegate = self
    }

    // MARK: - Replacements

    /// Replaces the set of replacements, relaying out only what changed.
    func setReplacements(_ newReplacements: [Replacement]) {
        // At the same location the longer one wins, so a collapsed section keeps priority
        // over markup hidden at its start.
        var sorted = newReplacements.sorted {
            $0.range.location != $1.range.location ? $0.range.location < $1.range.location : $0.range.length > $1.range.length
        }
        // Drop any that overlap an earlier one.
        var accepted: [Replacement] = []
        for replacement in sorted where accepted.last.map({ NSMaxRange($0.range) <= replacement.range.location }) ?? true {
            accepted.append(replacement)
        }
        sorted = accepted

        let signature: (Replacement) -> String = { "\($0.range.location):\($0.range.length):\($0.identity)" }
        let oldKeys = Set(replacements.map(signature))
        let newKeys = Set(sorted.map(signature))
        guard oldKeys != newKeys else { return }

        let changed = replacements.filter { !newKeys.contains(signature($0)) } + sorted.filter { !oldKeys.contains(signature($0)) }
        replacements = sorted
        drawnRects.removeAll()
        let length = textStorage?.length ?? 0
        for replacement in changed {
            invalidate(clamped(replacement.range, to: length))
        }
    }

    /// Keeps replacements in step with an edit, while the text storage processes it.
    /// Replacements the edit touches are dropped and relaid out once the edit is done.
    func textWillChange(editedRange: NSRange, changeInLength delta: Int) {
        guard !replacements.isEmpty else { return }
        let oldEnd = NSMaxRange(editedRange) - delta
        var kept: [Replacement] = []
        for replacement in replacements {
            if NSMaxRange(replacement.range) <= editedRange.location {
                kept.append(replacement)
            } else if replacement.range.location >= oldEnd {
                kept.append(replacement.movingBy(delta))
            } else {
                let start = min(replacement.range.location, editedRange.location)
                let end = max(NSMaxRange(replacement.range) + delta, NSMaxRange(editedRange))
                pendingInvalidation.append(NSRange(location: start, length: max(end - start, 0)))
            }
        }
        replacements = kept
        drawnRects.removeAll()
    }

    /// Relays out replacements dropped by an edit. Call after the edit has been processed.
    func flushPendingInvalidation() {
        guard !pendingInvalidation.isEmpty else { return }
        let length = textStorage?.length ?? 0
        let ranges = pendingInvalidation
        pendingInvalidation.removeAll()
        for range in ranges {
            invalidate(clamped(range, to: length))
        }
    }

    private func invalidate(_ range: NSRange) {
        guard range.length > 0 else { return }
        invalidateGlyphs(forCharacterRange: range, changeInLength: 0, actualCharacterRange: nil)
        invalidateLayout(forCharacterRange: range, actualCharacterRange: nil)
        invalidateDisplay(forCharacterRange: range)
    }

    private func clamped(_ range: NSRange, to length: Int) -> NSRange {
        let location = min(range.location, length)
        return NSRange(location: location, length: min(range.length, length - location))
    }

    /// The replacement covering `location`, if any.
    func replacement(containing location: Int) -> Replacement? {
        var low = 0
        var high = replacements.count - 1
        while low <= high {
            let middle = (low + high) / 2
            let range = replacements[middle].range
            if location < range.location {
                high = middle - 1
            } else if location >= NSMaxRange(range) {
                low = middle + 1
            } else {
                return replacements[middle]
            }
        }
        return nil
    }

    /// Replacements whose first character lies in `range`.
    private func replacements(anchoredIn range: NSRange) -> [Replacement] {
        replacements.filter { NSLocationInRange($0.range.location, range) }
    }

    /// The replacement drawn at `point` (text view coordinates).
    func replacement(at point: NSPoint) -> Replacement? {
        guard let entry = drawnRects.first(where: { $0.value.contains(point) }) else { return nil }
        return replacement(containing: entry.key)
    }

    /// Whether all of `line` (including its line break) is hidden markup, such as a
    /// `\begin{itemize}` line in the visual preview.
    func isLineHidden(_ line: NSRange) -> Bool {
        guard line.length > 0, let replacement = replacement(containing: line.location), replacement.isHidden else { return false }
        return NSMaxRange(replacement.range) >= NSMaxRange(line)
    }

    /// Whether the line starting at `location` is hidden inside a replacement.
    func isHidden(_ location: Int) -> Bool {
        guard let replacement = replacement(containing: location), !replacement.isHidden else { return false }
        return location != replacement.range.location
    }

    // MARK: - Glyph generation

    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
        properties props: UnsafePointer<NSLayoutManager.GlyphProperty>,
        characterIndexes charIndexes: UnsafePointer<Int>,
        font aFont: NSFont,
        forGlyphRange glyphRange: NSRange
    ) -> Int {
        guard !replacements.isEmpty else { return 0 }
        var modified: [NSLayoutManager.GlyphProperty]?
        for index in 0..<glyphRange.length {
            let character = charIndexes[index]
            guard let replacement = replacement(containing: character) else { continue }
            if modified == nil {
                modified = Array(UnsafeBufferPointer(start: props, count: glyphRange.length))
            }
            if character == replacement.range.location && !replacement.isHidden {
                modified?[index] = .controlCharacter
            } else if !props[index].contains(.controlCharacter) {
                // Line breaks stay control characters so they can be given zero advancement.
                modified?[index] = .null
            }
        }
        guard let modified else { return 0 }
        modified.withUnsafeBufferPointer { buffer in
            layoutManager.setGlyphs(glyphs, properties: buffer.baseAddress!, characterIndexes: charIndexes, font: aFont, forGlyphRange: glyphRange)
        }
        return glyphRange.length
    }

    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldUse action: NSLayoutManager.ControlCharacterAction,
        forControlCharacterAt charIndex: Int
    ) -> NSLayoutManager.ControlCharacterAction {
        guard let replacement = replacement(containing: charIndex) else { return action }
        return charIndex == replacement.range.location && !replacement.isHidden ? .whitespace : .zeroAdvancement
    }

    func layoutManager(
        _ layoutManager: NSLayoutManager,
        boundingBoxForControlGlyphAt glyphIndex: Int,
        for textContainer: NSTextContainer,
        proposedLineFragment proposedRect: NSRect,
        glyphPosition: NSPoint,
        characterIndex charIndex: Int
    ) -> NSRect {
        guard let replacement = replacement(containing: charIndex), charIndex == replacement.range.location else {
            return NSRect(x: 0, y: 0, width: 0, height: 0)
        }
        // Display math is centred when drawn; its glyph only takes the formula's width, so
        // the line can never overflow and push what follows onto the next line.
        return NSRect(x: 0, y: 0, width: replacement.size.width, height: replacement.size.height)
    }

    /// Makes lines tall enough for the drawings they contain.
    func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<NSRect>,
        lineFragmentUsedRect: UnsafeMutablePointer<NSRect>,
        baselineOffset: UnsafeMutablePointer<CGFloat>,
        in textContainer: NSTextContainer,
        forGlyphRange glyphRange: NSRange
    ) -> Bool {
        guard !replacements.isEmpty else { return false }
        let characters = characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let anchored = replacements(anchoredIn: characters).filter { !$0.isHidden }
        guard !anchored.isEmpty else { return false }

        let padding: CGFloat = 2
        var ascent = baselineOffset.pointee
        var descent = lineFragmentRect.pointee.height - ascent
        for replacement in anchored {
            ascent = max(ascent, replacement.size.height - replacement.descent + padding)
            descent = max(descent, replacement.descent + padding)
        }
        let height = ascent + descent
        guard height > lineFragmentRect.pointee.height + 0.5 else { return false }
        lineFragmentRect.pointee.size.height = height
        lineFragmentUsedRect.pointee.size.height = max(lineFragmentUsedRect.pointee.height, height)
        baselineOffset.pointee = ascent
        return true
    }

    // MARK: - Drawing

    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        guard !replacements.isEmpty, let textContainer = textContainers.first else { return }
        let characters = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        let font = (textStorage?.length ?? 0) > 0
            ? (textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont) ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            : NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

        for replacement in replacements(anchoredIn: characters) where !replacement.isHidden {
            let glyph = glyphIndexForCharacter(at: replacement.range.location)
            let fragment = lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let box = boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: textContainer)
            let baseline = fragment.minY + location(forGlyphAt: glyph).y
            var x = box.minX
            if replacement.fillsLine {
                // Centre in the visible text width, like display math in the PDF.
                let padding = textContainer.lineFragmentPadding
                var usable = textContainer.size.width
                if let textView = textContainer.textView {
                    usable = min(usable, textView.visibleRect.width - 2 * textView.textContainerInset.width)
                }
                usable -= 2 * padding
                x = max(fragment.minX + padding + (usable - replacement.size.width) / 2, box.minX)
            }
            let rect = NSRect(
                x: origin.x + x,
                y: origin.y + baseline - (replacement.size.height - replacement.descent),
                width: replacement.size.width,
                height: replacement.size.height
            )
            replacement.draw(in: rect, font: font)
            drawnRects[replacement.range.location] = rect
        }
    }
}
