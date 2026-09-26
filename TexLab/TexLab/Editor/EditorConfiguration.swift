//
//  EditorConfiguration.swift
//  TexLab
//

import Foundation

/// How the editor presents LaTeX.
nonisolated enum EditorMode: String, CaseIterable, Identifiable, Sendable {
    /// The source as it is: a monospaced font, syntax colouring and folding.
    case code
    /// Close to the typeset document, like Overleaf's Visual Editor: proportional text,
    /// large headings, rendered formulas and figures, with markup shown where you edit.
    case visual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .code: String(localized: "Code")
        case .visual: String(localized: "Visual")
        }
    }

    var systemImage: String {
        switch self {
        case .code: "chevron.left.forwardslash.chevron.right"
        case .visual: "eye"
        }
    }
}

/// The typeface of text in the Visual editor.
nonisolated enum VisualTypeface: String, CaseIterable, Identifiable, Sendable {
    /// New York, close to the look of a typeset document.
    case serif
    /// San Francisco.
    case sans
    /// The editor's code font.
    case code

    var id: String { rawValue }

    var title: String {
        switch self {
        case .serif: String(localized: "Serif (New York)")
        case .sans: String(localized: "Sans Serif (San Francisco)")
        case .code: String(localized: "Code Font")
        }
    }
}

/// The user's editor preferences, passed from SwiftUI settings into the AppKit editor.
nonisolated struct EditorConfiguration: Equatable, Sendable {
    var fontSize: Double = AppSettings.editorFontSize
    /// A font family name, or empty for the system's monospaced font.
    var fontName = AppSettings.editorFontName
    var lineSpacing = AppSettings.editorLineSpacing
    var themeName = AppSettings.syntaxTheme
    var showsLineNumbers = AppSettings.showsLineNumbers
    var highlightsCurrentLine = AppSettings.highlightsCurrentLine
    var wrapsLines = AppSettings.wrapsLines
    var autoPairsBrackets = AppSettings.autoPairsBrackets
    var autoClosesEnvironments = AppSettings.autoClosesEnvironments
    var indentWidth = AppSettings.indentWidth
    var indentsWithSpaces = AppSettings.indentsWithSpaces
    var checksSpelling = AppSettings.checksSpelling
    var suggestsCompletions = AppSettings.suggestsCompletions

    var mode: EditorMode = .code
    var visualTypeface = VisualTypeface(rawValue: AppSettings.visualTypeface) ?? .serif
    var visualFontSize = AppSettings.visualFontSize
    /// Keeps Visual text in a centred column of readable width, like a page.
    var limitsLineWidth = AppSettings.visualLimitsLineWidth
    var lineWidth = AppSettings.visualLineWidth
    /// Shows typeset formulas in place of their source (Visual only).
    var rendersMath = AppSettings.rendersMathInEditor
    /// Shows the image of `\includegraphics` in place of the command (Visual only).
    var showsImages = AppSettings.showsImagesInline

    var isVisual: Bool { mode == .visual }

    /// Headings, lists, references and formatting shown as they will look.
    var stylesFormatting: Bool { isVisual }

    /// Formulas drawn typeset: only in the Visual editor.
    var showsRenderedMath: Bool { isVisual && rendersMath }

    var colorTheme: SyntaxColorTheme {
        SyntaxColorTheme(rawValue: themeName) ?? .standard
    }

    /// The text inserted for one level of indentation.
    var indentUnit: String {
        indentsWithSpaces ? String(repeating: " ", count: max(indentWidth, 1)) : "\t"
    }

    /// Whether a change requires fonts and colours to be rebuilt.
    func needsNewTheme(comparedTo other: EditorConfiguration) -> Bool {
        fontSize != other.fontSize || fontName != other.fontName || lineSpacing != other.lineSpacing
            || themeName != other.themeName || indentWidth != other.indentWidth || mode != other.mode
            || visualTypeface != other.visualTypeface || visualFontSize != other.visualFontSize
    }
}

/// Editor actions that change settings rather than a single document.
enum EditorPreferences {
    /// Makes the editor text bigger or smaller for every document, like Format ▸ Font ▸
    /// Bigger in other Mac text editors. The Visual editor's size follows.
    static func adjustFontSize(by delta: Double) {
        let defaults = UserDefaults.standard
        let current = defaults.double(forKey: SettingsKey.editorFontSize)
        defaults.set(AppSettings.clampedFontSize(current + delta), forKey: SettingsKey.editorFontSize)
        let visual = defaults.double(forKey: SettingsKey.visualFontSize)
        defaults.set(AppSettings.clampedFontSize(visual + delta), forKey: SettingsKey.visualFontSize)
    }

    static func resetFontSize() {
        UserDefaults.standard.set(AppSettings.editorFontSize, forKey: SettingsKey.editorFontSize)
        UserDefaults.standard.set(AppSettings.visualFontSize, forKey: SettingsKey.visualFontSize)
    }
}
