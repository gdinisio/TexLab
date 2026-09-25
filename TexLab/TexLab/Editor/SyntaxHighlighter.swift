//
//  SyntaxHighlighter.swift
//  TexLab
//

import AppKit
import CoreGraphics
import CoreText
import Foundation

extension NSAttributedString.Key {
    /// Marks characters that are LaTeX markup rather than prose. The value is the raw value
    /// of a `SyntaxKind`. The editor uses it to keep spelling checks on prose only.
    nonisolated static let texLabSyntax = NSAttributedString.Key("TexLabSyntax")
}

/// Colours for LaTeX source that follow Xcode's default light and dark themes, so the
/// editor feels at home next to other Mac developer tools and stays legible in both
/// appearances.
nonisolated enum SyntaxPalette {
    static func color(for kind: SyntaxKind) -> NSColor {
        switch kind {
        case .command: dynamicColor(light: 0x9B2393, dark: 0xFC5FA3)
        case .environment: dynamicColor(light: 0x0B4F79, dark: 0x5DD8FF)
        case .math: dynamicColor(light: 0x1C00CF, dark: 0xD0BF69)
        case .comment: dynamicColor(light: 0x5D6C79, dark: 0x7F8C98)
        case .reference, .verbatim: dynamicColor(light: 0xC41A16, dark: 0xFC6A5D)
        case .special: dynamicColor(light: 0x643820, dark: 0xFD8F3F)
        case .sectionTitle: NSColor.textColor
        }
    }

    /// A subtle band behind the line containing the insertion point.
    static var currentLine: NSColor {
        dynamicColor(light: 0xECF5FF, dark: 0x23252B)
    }

    static func dynamicColor(light: UInt32, dark: UInt32) -> NSColor {
        let lightColor = color(hex: light)
        let darkColor = color(hex: dark)
        return NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? darkColor : lightColor
        }
    }

    private static func color(hex: UInt32) -> NSColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Fonts, colours and paragraph style for the source editor.
struct SyntaxTheme {
    let font: NSFont
    let boldFont: NSFont
    let paragraphStyle: NSParagraphStyle
    private let colors: [SyntaxKind: NSColor]

    init(fontSize: CGFloat, indentWidth: Int) {
        font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        boldFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)

        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = 1.12
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width
        style.defaultTabInterval = spaceWidth * CGFloat(max(indentWidth, 1))
        style.tabStops = []
        paragraphStyle = style

        let kinds: [SyntaxKind] = [.command, .environment, .math, .comment, .reference, .special, .verbatim, .sectionTitle]
        var colors: [SyntaxKind: NSColor] = [:]
        for kind in kinds {
            colors[kind] = SyntaxPalette.color(for: kind)
        }
        self.colors = colors
    }

    var baseAttributes: [NSAttributedString.Key: Any] {
        [
            .font: font,
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraphStyle,
        ]
    }

    func color(for kind: SyntaxKind) -> NSColor {
        colors[kind] ?? NSColor.textColor
    }
}

/// Applies syntax colouring to a text storage.
///
/// Edits are re-coloured one paragraph block at a time: LaTeX resets math mode at blank
/// lines, so scanning from the blank line before an edit to the blank line after it is
/// both correct and fast, whatever the length of the document.
final class SyntaxHighlighter {
    var theme: SyntaxTheme {
        didSet { styledFonts.removeAll() }
    }
    /// Shows the arguments of `\emph`, `\textbf` and similar commands in their style, for
    /// the live preview.
    var stylesFormatting = false
    private var styledFonts: [String: NSFont] = [:]

    init(theme: SyntaxTheme) {
        self.theme = theme
    }

    /// Colours the whole document. Call outside of text storage editing.
    func highlightAll(_ storage: NSTextStorage) {
        let range = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        apply(to: storage, in: range)
        storage.endEditing()
    }

    /// Colours the text affected by an edit, as its own attribute-only edit once the
    /// character change has been processed.
    func highlight(_ storage: NSTextStorage, editedRange: NSRange) {
        let region = Self.region(in: storage.mutableString, around: editedRange)
        apply(to: storage, in: region)
    }

    private func apply(to storage: NSTextStorage, in region: NSRange) {
        guard region.length > 0 else { return }
        let scan = LaTeXTokenizer.scan(storage.mutableString, range: region)

        storage.addAttributes(theme.baseAttributes, range: region)
        storage.removeAttribute(.texLabSyntax, range: region)
        storage.removeAttribute(.underlineStyle, range: region)
        storage.removeAttribute(.strikethroughStyle, range: region)

        for span in scan.regions {
            storage.addAttributes([
                .foregroundColor: theme.color(for: .math),
                .texLabSyntax: SyntaxKind.math.rawValue,
            ], range: span.range)
        }
        for span in scan.tokens {
            if span.kind == .sectionTitle {
                storage.addAttribute(.font, value: theme.boldFont, range: span.range)
            } else {
                storage.addAttributes([
                    .foregroundColor: theme.color(for: span.kind),
                    .texLabSyntax: span.kind.rawValue,
                ], range: span.range)
            }
        }
        if stylesFormatting {
            applyFormatting(to: storage, in: region, scan: scan)
        }
    }

    // MARK: - Formatting preview

    private func applyFormatting(to storage: NSTextStorage, in region: NSRange, scan: SyntaxScan) {
        let string = storage.mutableString
        let excluded = scan.regions.map(\.range) + scan.tokens.filter { $0.kind == .verbatim || $0.kind == .comment }.map(\.range)
        // Outer commands come first, so nested ones combine: \textbf{\emph{…}} is bold italic.
        for element in VisualScanner.scan(string, range: region, excluding: excluded, stylesOnly: true) {
            guard let content = element.contentRange, content.length > 0, NSMaxRange(content) <= NSMaxRange(region) else { continue }
            switch element.role {
            case .plain:
                break
            case .heading(let level):
                storage.addAttributes([.font: roleFont(size: Self.headingScale(level), weight: .bold), .foregroundColor: NSColor.labelColor], range: content)
            case .title:
                storage.addAttributes([.font: roleFont(size: 1.6, weight: .bold), .foregroundColor: NSColor.labelColor], range: content)
            case .author:
                storage.addAttributes([.font: roleFont(size: 1.1, weight: .regular), .foregroundColor: NSColor.secondaryLabelColor], range: content)
            case .link:
                storage.addAttributes([
                    .foregroundColor: NSColor.linkColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                ], range: content)
            case .footnote:
                storage.addAttributes([.font: roleFont(size: 0.85, weight: .regular), .foregroundColor: NSColor.secondaryLabelColor], range: content)
            }
            guard !element.style.isEmpty else { continue }
            storage.enumerateAttribute(.font, in: content) { value, run, _ in
                let font = (value as? NSFont) ?? theme.font
                storage.addAttribute(.font, value: styledFont(font, element.style), range: run)
            }
            if element.style.contains(.underline) {
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: content)
            }
            if element.style.contains(.strikethrough) {
                storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: content)
            }
        }
    }

    /// Heading sizes relative to the editor font, from `\part` down to `\subparagraph`.
    static func headingScale(_ level: Int) -> CGFloat {
        [1.8, 1.65, 1.4, 1.2, 1.08, 1, 1][min(max(level, 0), 6)]
    }

    /// The system font at `size` times the editor font's, for headings and the title.
    private func roleFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let key = "role|\(size)|\(weight.rawValue)|\(theme.font.pointSize)"
        if let cached = styledFonts[key] {
            return cached
        }
        let font = NSFont.systemFont(ofSize: (theme.font.pointSize * size).rounded(), weight: weight)
        styledFonts[key] = font
        return font
    }

    /// `font` changed to show `style`, keeping its size and any bold or italic it has.
    private func styledFont(_ font: NSFont, _ style: TextStyle) -> NSFont {
        let key = "\(font.fontName)|\(font.pointSize)|\(font.fontDescriptor.symbolicTraits.rawValue)|\(style.rawValue)"
        if let cached = styledFonts[key] {
            return cached
        }
        let size = font.pointSize
        var descriptor = font.fontDescriptor
        var traits = descriptor.symbolicTraits.intersection([.bold, .italic])
        if style.contains(.monospace) {
            descriptor = NSFont.monospacedSystemFont(ofSize: size, weight: .regular).fontDescriptor
        } else if style.contains(.sansSerif) {
            descriptor = NSFont.systemFont(ofSize: size).fontDescriptor
        } else if style.contains(.serif) {
            let system = NSFont.systemFont(ofSize: size).fontDescriptor
            descriptor = system.withDesign(.serif) ?? system
        } else if style.contains(.smallCaps) {
            let system = NSFont.systemFont(ofSize: size).fontDescriptor
            descriptor = system.addingAttributes([
                .featureSettings: [[
                    NSFontDescriptor.FeatureKey.typeIdentifier: kLowerCaseType,
                    NSFontDescriptor.FeatureKey.selectorIdentifier: kLowerCaseSmallCapsSelector,
                ]],
            ])
        }
        if style.contains(.bold) { traits.insert(.bold) }
        if style.contains(.italic) { traits.insert(.italic) }
        if style.contains(.upright) { traits.remove(.italic) }
        if style.contains(.medium) { traits.remove(.bold) }
        let styled = NSFont(descriptor: descriptor.withSymbolicTraits(traits), size: size)
            ?? NSFont(descriptor: descriptor, size: size)
            ?? font
        styledFonts[key] = styled
        return styled
    }

    /// The paragraph block around `range`, extended to cover verbatim environments that
    /// may contain blank lines.
    static func region(in string: NSString, around range: NSRange) -> NSRange {
        let length = string.length
        let blankLine = "\n\n"

        var start = 0
        if range.location > 0 {
            let found = string.range(of: blankLine, options: .backwards, range: NSRange(location: 0, length: min(range.location, length)))
            if found.location != NSNotFound {
                start = found.location + 1
            }
        }
        var end = length
        let searchStart = min(NSMaxRange(range), length)
        if searchStart < length {
            let found = string.range(of: blankLine, options: [], range: NSRange(location: searchStart, length: length - searchStart))
            if found.location != NSNotFound {
                end = found.location + 1
            }
        }

        // Start earlier if the block begins inside a verbatim environment.
        for environment in LaTeXLanguage.verbatimEnvironments where start > 0 {
            let before = NSRange(location: 0, length: start)
            let begin = string.range(of: "\\begin{\(environment)}", options: .backwards, range: before)
            guard begin.location != NSNotFound else { continue }
            let close = string.range(of: "\\end{\(environment)}", options: .backwards, range: before)
            if close.location == NSNotFound || close.location < begin.location {
                start = min(start, begin.location)
            }
        }

        // Opening or closing a verbatim environment can change everything after it.
        let block = NSRange(location: start, length: end - start)
        for environment in LaTeXLanguage.verbatimEnvironments where end < length {
            let opens = string.range(of: "\\begin{\(environment)}", options: [], range: block)
            let closes = string.range(of: "\\end{\(environment)}", options: [], range: block)
            if opens.location != NSNotFound || closes.location != NSNotFound {
                end = length
            }
        }
        return NSRange(location: start, length: end - start)
    }
}
