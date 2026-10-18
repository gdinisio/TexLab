//
//  VisualLabelRenderer.swift
//  TexLab
//

import AppKit
import CoreGraphics
import Foundation

/// Measures and draws the labels of the visual preview.
enum VisualLabelRenderer {
    /// The size of `label` and how far it reaches below the baseline.
    static func metrics(
        for label: VisualLabel,
        image: NSImage?,
        font: NSFont,
        lineHeight: CGFloat,
        availableWidth: CGFloat
    ) -> (size: CGSize, descent: CGFloat) {
        switch label.kind {
        case .inline(let bold):
            let text = inlineText(label.text, font: font, bold: bold)
            // A little spare width, so rounding can never clip the last letter.
            return (CGSize(width: ceil(text.size().width) + 2, height: ceil(font.ascender - font.descender)), -font.descender)
        case .chip, .inclusion:
            let text = chipText(label.text, font: font)
            let height = ceil(font.ascender - font.descender) + 2
            let width = ceil(chipPadding + chipIconWidth(font) + 3 + text.size().width + chipPadding + 2)
            return (CGSize(width: width, height: height), -font.descender + 1)
        case .preview(_, let onPaper):
            guard let image, image.size.width > 0, image.size.height > 0 else {
                return (.zero, 0)
            }
            let artwork = previewSize(of: image, onPaper: onPaper, font: font, lineHeight: lineHeight, availableWidth: availableWidth)
            guard !label.text.isEmpty else {
                return (CGSize(width: ceil(min(artwork.width, availableWidth)), height: ceil(artwork.height + 8)), 4)
            }
            let caption = captionText(label.text, font: font)
            let captionWidth = chipIconWidth(font) + 4 + caption.size().width
            let width = min(max(artwork.width, captionWidth), availableWidth)
            return (CGSize(width: ceil(width), height: ceil(artwork.height + previewGap + caption.size().height + 8)), 4)
        case .environment(_, let italic):
            let headingFont = environmentFont(font, italic: italic)
            let text = NSAttributedString(string: label.text, attributes: [.font: headingFont])
            let height = ceil(headingFont.ascender - headingFont.descender) + 6
            return (CGSize(width: ceil(text.size().width) + 2, height: height), environmentDescent(headingFont))
        case .titleBlock(let author):
            let title = titleText(label.text, font: font)
            var width = title.size().width
            var height = title.size().height + 10
            if let author {
                let authorLine = authorText(author, font: font)
                width = max(width, authorLine.size().width)
                height += authorLine.size().height + 4
            }
            return (CGSize(width: ceil(min(width, availableWidth)), height: ceil(height)), 6)
        case .picture:
            guard let image, image.size.width > 0, image.size.height > 0 else {
                return (.zero, 0)
            }
            let maxHeight = lineHeight * 12
            let maxWidth = min(availableWidth * 0.9, 520)
            let scale = min(maxHeight / image.size.height, maxWidth / image.size.width, 1.5)
            return (CGSize(width: ceil(image.size.width * scale), height: ceil(image.size.height * scale) + 8), 4)
        }
    }

    static func draw(_ label: VisualLabel, image: NSImage?, in rect: NSRect, font: NSFont) {
        switch label.kind {
        case .inline(let bold):
            let text = inlineText(label.text, font: font, bold: bold)
            drawOnBaseline(text, font: font, in: rect, descent: -font.descender)
        case .chip(let systemImage):
            drawChip(label.text, systemImage: systemImage, in: rect, font: font)
        case .inclusion:
            drawChip(label.text, systemImage: "doc.text", in: rect, font: font)
        case .preview(let systemImage, let onPaper):
            guard let image, image.size.width > 0, image.size.height > 0 else { return }
            drawPreview(label.text, image: image, systemImage: systemImage, onPaper: onPaper, in: rect, font: font)
        case .environment(_, let italic):
            let headingFont = environmentFont(font, italic: italic)
            let text = NSAttributedString(string: label.text, attributes: [
                .font: headingFont,
                .foregroundColor: NSColor.labelColor,
            ])
            drawOnBaseline(text, font: headingFont, in: rect, descent: environmentDescent(headingFont))
        case .titleBlock(let author):
            let title = titleText(label.text, font: font)
            let titleSize = title.size()
            var y = rect.minY + 4
            title.draw(with: NSRect(x: rect.midX - min(titleSize.width, rect.width) / 2, y: y, width: min(titleSize.width, rect.width), height: titleSize.height),
                       options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
            y += titleSize.height + 4
            if let author {
                let authorLine = authorText(author, font: font)
                let size = authorLine.size()
                authorLine.draw(with: NSRect(x: rect.midX - min(size.width, rect.width) / 2, y: y, width: min(size.width, rect.width), height: size.height),
                                options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
            }
        case .picture:
            guard let image else { return }
            let imageRect = rect.insetBy(dx: 0, dy: 4)
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: imageRect, xRadius: 4, yRadius: 4).addClip()
            image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    // MARK: - Included files

    /// The space between an included file's artwork and its caption.
    private static let previewGap: CGFloat = 6

    /// The size an included file's artwork is drawn at: a picture as `\includegraphics`
    /// pictures are, or a typeset drawing or table scaled like a formula, on its paper.
    private static func previewSize(of image: NSImage, onPaper: Bool, font: NSFont, lineHeight: CGFloat, availableWidth: CGFloat) -> CGSize {
        if onPaper {
            let fitted = RenderedPaper.fittedSize(of: image.size, scale: font.pointSize / 10, availableWidth: availableWidth, lineHeight: lineHeight)
            return CGSize(width: fitted.width + 2 * RenderedPaper.padding, height: fitted.height + 2 * RenderedPaper.padding)
        }
        let maxHeight = lineHeight * 12
        let maxWidth = min(availableWidth * 0.9, 520)
        let scale = min(maxHeight / image.size.height, maxWidth / image.size.width, 1.5)
        return CGSize(width: ceil(image.size.width * scale), height: ceil(image.size.height * scale))
    }

    private static func captionText(_ string: String, font: NSFont) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [
            .font: NSFont.systemFont(ofSize: font.pointSize - 1),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
    }

    /// The artwork centred at the top of `rect`, and the caption with the file's icon
    /// centred beneath it, as a figure is printed.
    private static func drawPreview(_ caption: String, image: NSImage, systemImage: String, onPaper: Bool, in rect: NSRect, font: NSFont) {
        let text = captionText(caption, font: font)
        let textSize = caption.isEmpty ? .zero : text.size()
        // The artwork takes the height the caption leaves, keeping its proportions.
        let paper = onPaper ? 2 * RenderedPaper.padding : 0
        let artworkHeight = max(rect.height - (caption.isEmpty ? 0 : previewGap + textSize.height) - 8, 0)
        let imageHeight = max(artworkHeight - paper, 0)
        let imageWidth = imageHeight * image.size.width / image.size.height
        let artwork = NSRect(x: rect.midX - (imageWidth + paper) / 2, y: rect.minY + 4, width: imageWidth + paper, height: artworkHeight)
        if onPaper {
            RenderedPaper.draw(image, in: artwork)
        } else {
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: artwork, xRadius: 4, yRadius: 4).addClip()
            image.draw(in: artwork, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            NSGraphicsContext.restoreGraphicsState()
        }
        guard !caption.isEmpty else { return }

        let iconSize = chipIconWidth(font)
        let width = min(iconSize + 4 + textSize.width, rect.width)
        var x = rect.midX - width / 2
        let y = artwork.maxY + previewGap
        if let symbol = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: iconSize - 3, weight: .medium)
                .applying(NSImage.SymbolConfiguration(paletteColors: [.secondaryLabelColor]))) {
            let size = symbol.size
            symbol.draw(in: NSRect(x: x + (iconSize - size.width) / 2, y: y + (textSize.height - size.height) / 2, width: size.width, height: size.height),
                        from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
        x += iconSize + 4
        text.draw(with: NSRect(x: x, y: y, width: max(rect.maxX - x, 0), height: textSize.height),
                  options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
    }

    // MARK: - Styles

    private static let chipPadding: CGFloat = 5

    private static func chipIconWidth(_ font: NSFont) -> CGFloat {
        font.pointSize - 1
    }

    /// `font` with `traits`, in the same family, so labels match the Visual editor's text.
    private static func variant(of font: NSFont, traits: NSFontDescriptor.SymbolicTraits, scale: CGFloat = 1) -> NSFont {
        let size = (font.pointSize * scale).rounded()
        return NSFont(descriptor: font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(traits)), size: size)
            ?? NSFont(descriptor: font.fontDescriptor, size: size)
            ?? font
    }

    private static func inlineText(_ string: String, font: NSFont, bold: Bool) -> NSAttributedString {
        let displayFont = bold ? variant(of: font, traits: .bold) : font
        return NSAttributedString(string: string, attributes: [.font: displayFont, .foregroundColor: NSColor.labelColor])
    }

    private static func chipText(_ string: String, font: NSFont) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [
            .font: NSFont.systemFont(ofSize: font.pointSize - 1, weight: .medium),
            .foregroundColor: NSColor.controlAccentColor,
        ])
    }

    /// Theorem-like headings in bold and Proof in italic, in the text's own typeface and
    /// size, as LaTeX sets them.
    private static func environmentFont(_ font: NSFont, italic: Bool) -> NSFont {
        italic ? variant(of: font, traits: .italic) : variant(of: font, traits: .bold)
    }

    private static func environmentDescent(_ font: NSFont) -> CGFloat {
        -font.descender + 2
    }

    /// Draws one line of text with its baseline where the layout put the label's baseline,
    /// without a width limit, so it's never wrapped or cut short.
    private static func drawOnBaseline(_ text: NSAttributedString, font: NSFont, in rect: NSRect, descent: CGFloat) {
        let baseline = rect.maxY - descent
        text.draw(at: NSPoint(x: rect.minX, y: baseline - font.ascender))
    }

    private static func titleText(_ string: String, font: NSFont) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [
            .font: variant(of: font, traits: .bold, scale: 1.8),
            .foregroundColor: NSColor.labelColor,
        ])
    }

    private static func authorText(_ string: String, font: NSFont) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [
            .font: variant(of: font, traits: [], scale: 1.1),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
    }

    private static func drawChip(_ string: String, systemImage: String, in rect: NSRect, font: NSFont) {
        let chip = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: rect.height / 2 - 1, yRadius: rect.height / 2 - 1)
        NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
        chip.fill()

        var x = rect.minX + chipPadding
        let iconSize = chipIconWidth(font)
        if let symbol = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: iconSize - 3, weight: .semibold)
                .applying(NSImage.SymbolConfiguration(paletteColors: [.controlAccentColor]))) {
            let size = symbol.size
            symbol.draw(in: NSRect(x: x + (iconSize - size.width) / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height),
                        from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        }
        x += iconSize + 3
        let text = chipText(string, font: font)
        let textSize = text.size()
        text.draw(with: NSRect(x: x, y: rect.midY - textSize.height / 2, width: max(rect.maxX - chipPadding - x, 0), height: textSize.height),
                  options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
    }
}
