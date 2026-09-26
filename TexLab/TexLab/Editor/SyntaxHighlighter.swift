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

/// The colour schemes for LaTeX source. Each has light and dark variants, so the editor
/// follows the system appearance.
nonisolated enum SyntaxColorTheme: String, CaseIterable, Identifiable, Sendable {
    /// Xcode's default colours.
    case standard
    /// Blue commands and red comments, as in classic Mac TeX editors.
    case classic
    /// Muted colours for long writing sessions.
    case soft
    /// Stronger colours for legibility.
    case highContrast
    /// Shades of grey, so the text stands out rather than the markup.
    case monochrome

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: String(localized: "Xcode")
        case .classic: String(localized: "Classic")
        case .soft: String(localized: "Soft")
        case .highContrast: String(localized: "High Contrast")
        case .monochrome: String(localized: "Monochrome")
        }
    }

    func color(for kind: SyntaxKind) -> NSColor {
        if kind == .sectionTitle {
            return .textColor
        }
        if self == .monochrome {
            switch kind {
            case .comment: return .tertiaryLabelColor
            case .math, .verbatim, .reference: return .secondaryLabelColor
            default: return NSColor.labelColor.withAlphaComponent(0.72)
            }
        }
        let (light, dark) = hexColors(for: kind)
        return SyntaxPalette.dynamicColor(light: light, dark: dark)
    }

    private func hexColors(for kind: SyntaxKind) -> (UInt32, UInt32) {
        switch (self, kind) {
        case (.classic, .command), (.classic, .special): (0x0433FF, 0x6E9CFF)
        case (.classic, .environment): (0x7A1FA2, 0xC792EA)
        case (.classic, .math): (0x007A3D, 0x7FD88F)
        case (.classic, .comment): (0xB22222, 0xFF7B72)
        case (.classic, _): (0x8B4513, 0xE0A96D)

        case (.soft, .command): (0x8E5B9E, 0xC8A2D6)
        case (.soft, .environment): (0x4A7A94, 0x8FC1D9)
        case (.soft, .math): (0x5A6BB5, 0xA9B4E8)
        case (.soft, .comment): (0x8A939C, 0x7D858E)
        case (.soft, .special): (0x8C6A4F, 0xC9A889)
        case (.soft, _): (0xB0625A, 0xE0998F)

        case (.highContrast, .command): (0x7D007D, 0xFF6AC1)
        case (.highContrast, .environment): (0x00427A, 0x00D4FF)
        case (.highContrast, .math): (0x0000C8, 0xFFE45C)
        case (.highContrast, .comment): (0x3F4A54, 0xA8B3BD)
        case (.highContrast, .special): (0x5A2E00, 0xFFA657)
        case (.highContrast, _): (0xAE0000, 0xFF6159)

        case (_, .command): (0x9B2393, 0xFC5FA3)
        case (_, .environment): (0x0B4F79, 0x5DD8FF)
        case (_, .math): (0x1C00CF, 0xD0BF69)
        case (_, .comment): (0x5D6C79, 0x7F8C98)
        case (_, .special): (0x643820, 0xFD8F3F)
        case (_, _): (0xC41A16, 0xFC6A5D)
        }
    }
}

/// Colour helpers shared by the themes.
nonisolated enum SyntaxPalette {
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
    /// The font of ordinary text: the code font, or the Visual editor's typeface.
    let font: NSFont
    let boldFont: NSFont
    /// The font of markup — commands, math source, comments. The code font, sized to sit
    /// well beside `font`.
    let markupFont: NSFont
    let isVisual: Bool
    /// The code font as configured: a family name, or empty for SF Mono.
    let codeFontName: String
    let paragraphStyle: NSParagraphStyle
    private let colors: [SyntaxKind: NSColor]

    init(configuration: EditorConfiguration) {
        let codeSize = CGFloat(AppSettings.clampedFontSize(configuration.fontSize))
        isVisual = configuration.isVisual
        codeFontName = configuration.fontName
        let visualSize = CGFloat(AppSettings.clampedFontSize(configuration.visualFontSize))

        if isVisual {
            let proseSize = visualSize
            switch configuration.visualTypeface {
            case .serif:
                let system = NSFont.systemFont(ofSize: proseSize).fontDescriptor
                font = NSFont(descriptor: system.withDesign(.serif) ?? system, size: proseSize) ?? .systemFont(ofSize: proseSize)
            case .sans:
                font = .systemFont(ofSize: proseSize)
            case .code:
                font = Self.codeFont(named: configuration.fontName, size: proseSize)
            }
            // Markup is set a little smaller than the text, as code often is in prose.
            markupFont = Self.codeFont(named: configuration.fontName, size: (proseSize * 0.86).rounded())
        } else {
            font = Self.codeFont(named: configuration.fontName, size: codeSize)
            markupFont = font
        }
        boldFont = NSFont(descriptor: font.fontDescriptor.withSymbolicTraits(.bold), size: font.pointSize) ?? font

        let style = NSMutableParagraphStyle()
        let spacing = CGFloat(min(max(configuration.lineSpacing, 0.9), 2.5))
        style.lineHeightMultiple = isVisual ? max(spacing, 1.3) : spacing
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: markupFont]).width
        style.defaultTabInterval = spaceWidth * CGFloat(max(configuration.indentWidth, 1))
        style.tabStops = []
        paragraphStyle = style

        let theme = configuration.colorTheme
        let kinds: [SyntaxKind] = [.command, .environment, .math, .comment, .reference, .special, .verbatim, .sectionTitle]
        var colors: [SyntaxKind: NSColor] = [:]
        for kind in kinds {
            colors[kind] = theme.color(for: kind)
        }
        self.colors = colors
    }

    /// The chosen code font, or SF Mono when it isn't installed.
    static func codeFont(named name: String, size: CGFloat) -> NSFont {
        if !name.isEmpty, let font = NSFont(name: name, size: size) {
            return font
        }
        if !name.isEmpty, let font = NSFontManager.shared.font(withFamily: name, traits: [], weight: 5, size: size) {
            return font
        }
        return .monospacedSystemFont(ofSize: size, weight: .regular)
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
    /// The code font's name, for `\texttt` in the Visual editor.
    private var codeFontName: String {
        theme.codeFontName
    }

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

        // In the Visual editor the text is set in its typeface and markup keeps the code
        // font, so commands and formulas being edited read as source.
        let markupFont = theme.isVisual ? theme.markupFont : nil
        for span in scan.regions {
            var attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: theme.color(for: .math),
                .texLabSyntax: SyntaxKind.math.rawValue,
            ]
            if let markupFont {
                attributes[.font] = markupFont
            }
            storage.addAttributes(attributes, range: span.range)
        }
        for span in scan.tokens {
            if span.kind == .sectionTitle {
                storage.addAttribute(.font, value: theme.boldFont, range: span.range)
            } else {
                var attributes: [NSAttributedString.Key: Any] = [
                    .foregroundColor: theme.color(for: span.kind),
                    .texLabSyntax: span.kind.rawValue,
                ]
                if let markupFont {
                    attributes[.font] = markupFont
                }
                storage.addAttributes(attributes, range: span.range)
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

    /// The text typeface at `size` times the text size, for headings and the title.
    private func roleFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let key = "role|\(size)|\(weight.rawValue)|\(theme.font.fontName)|\(theme.font.pointSize)"
        if let cached = styledFonts[key] {
            return cached
        }
        let pointSize = (theme.font.pointSize * size).rounded()
        let traits: NSFontDescriptor.SymbolicTraits = weight == .bold ? .bold : []
        let font = NSFont(descriptor: theme.font.fontDescriptor.withSymbolicTraits(traits), size: pointSize)
            ?? NSFont.systemFont(ofSize: pointSize, weight: weight)
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
            descriptor = SyntaxTheme.codeFont(named: codeFontName, size: size).fontDescriptor
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
