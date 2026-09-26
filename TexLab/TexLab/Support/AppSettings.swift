//
//  AppSettings.swift
//  TexLab
//

import Foundation

/// The TeX engine used to typeset a document.
///
/// A document can choose its engine with a `% !TEX program = xelatex` magic comment,
/// the convention shared by TeXShop, TeXstudio and other editors. Otherwise the default
/// engine from Settings is used.
nonisolated enum TypesettingEngine: String, CaseIterable, Identifiable, Sendable {
    case pdfLaTeX = "pdflatex"
    case xeLaTeX = "xelatex"
    case luaLaTeX = "lualatex"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pdfLaTeX: "pdfLaTeX"
        case .xeLaTeX: "XeLaTeX"
        case .luaLaTeX: "LuaLaTeX"
        }
    }

    /// The executable that runs this engine.
    var executableName: String { rawValue }

    /// The latexmk option that selects this engine.
    var latexmkOption: String {
        switch self {
        case .pdfLaTeX: "-pdf"
        case .xeLaTeX: "-pdfxe"
        case .luaLaTeX: "-pdflua"
        }
    }

    /// Parses the value of a `% !TEX program` magic comment.
    init?(magicCommentValue value: String) {
        switch value.lowercased() {
        case "pdflatex", "latex", "pdftex": self = .pdfLaTeX
        case "xelatex", "xetex": self = .xeLaTeX
        case "lualatex", "luatex": self = .luaLaTeX
        default: return nil
        }
    }
}

/// `UserDefaults` keys for TexLab's settings.
///
/// Views read these with `@AppStorage`; the editor and typesetting code read them through
/// `UserDefaults.standard`. `AppSettings.registerDefaults()` keeps both in agreement.
nonisolated enum SettingsKey {
    static let editorFontSize = "editorFontSize"
    static let showsLineNumbers = "showsLineNumbers"
    static let highlightsCurrentLine = "highlightsCurrentLine"
    static let wrapsLines = "wrapsLines"
    static let autoPairsBrackets = "autoPairsBrackets"
    static let autoClosesEnvironments = "autoClosesEnvironments"
    static let indentWidth = "indentWidth"
    static let indentsWithSpaces = "indentsWithSpaces"
    static let checksSpelling = "checksSpelling"
    static let suggestsCompletions = "suggestsCompletions"
    static let showsStatusBar = "showsStatusBar"
    static let editorFontName = "editorFontName"
    static let editorLineSpacing = "editorLineSpacing"
    static let syntaxTheme = "syntaxTheme"
    static let defaultEditorMode = "defaultEditorMode"
    static let visualTypeface = "visualTypeface"
    static let visualFontSize = "visualFontSize"
    static let visualLimitsLineWidth = "visualLimitsLineWidth"
    static let visualLineWidth = "visualLineWidth"
    static let rendersMathInEditor = "rendersMathInEditor"
    static let showsImagesInline = "showsImagesInline"
    static let collapsesPreambleInVisual = "collapsesPreambleInVisual"
    static let foldsFloatsOnOpen = "foldsFloatsOnOpen"
    static let foldsPreambleOnOpen = "foldsPreambleOnOpen"
    static let showsWelcomeAtLaunch = "showsWelcomeAtLaunch"

    static let defaultEngine = "defaultEngine"
    static let typesetsAutomatically = "typesetsAutomatically"
    static let autoTypesetDelay = "autoTypesetDelay"
    static let usesLatexmk = "usesLatexmk"
    static let texBinPath = "texBinPath"
    static let allowsShellEscape = "allowsShellEscape"
    static let showsWarnings = "showsWarnings"
    static let showsBadBoxes = "showsBadBoxes"
    static let previewShowsTwoPages = "previewShowsTwoPages"
}

/// Default values for every setting.
nonisolated enum AppSettings {
    static let editorFontSize: Double = 13
    static let minimumFontSize: Double = 9
    static let maximumFontSize: Double = 32
    static let showsLineNumbers = true
    static let highlightsCurrentLine = true
    static let wrapsLines = true
    static let autoPairsBrackets = true
    static let autoClosesEnvironments = true
    static let indentWidth = 2
    static let indentsWithSpaces = true
    static let checksSpelling = true
    static let suggestsCompletions = true
    static let showsStatusBar = true
    /// Empty for the system's monospaced font, SF Mono.
    static let editorFontName = ""
    static let editorLineSpacing: Double = 1.15
    static let syntaxTheme = SyntaxColorTheme.standard.rawValue
    static let defaultEditorMode = EditorMode.visual.rawValue
    static let visualTypeface = VisualTypeface.serif.rawValue
    static let visualFontSize: Double = 16
    static let visualLimitsLineWidth = true
    static let visualLineWidth: Double = 720
    static let rendersMathInEditor = true
    static let showsImagesInline = true
    static let collapsesPreambleInVisual = true
    static let foldsFloatsOnOpen = false
    static let foldsPreambleOnOpen = false
    static let showsWelcomeAtLaunch = true

    static let defaultEngine = TypesettingEngine.pdfLaTeX.rawValue
    static let typesetsAutomatically = true
    static let autoTypesetDelay: Double = 1.5
    static let usesLatexmk = true
    static let texBinPath = ""
    static let allowsShellEscape = false
    static let showsWarnings = true
    static let showsBadBoxes = false
    static let previewShowsTwoPages = false

    /// Registers the defaults so code that reads `UserDefaults` directly sees the same
    /// values as `@AppStorage` before the user changes anything.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.editorFontSize: editorFontSize,
            SettingsKey.showsLineNumbers: showsLineNumbers,
            SettingsKey.highlightsCurrentLine: highlightsCurrentLine,
            SettingsKey.wrapsLines: wrapsLines,
            SettingsKey.autoPairsBrackets: autoPairsBrackets,
            SettingsKey.autoClosesEnvironments: autoClosesEnvironments,
            SettingsKey.indentWidth: indentWidth,
            SettingsKey.indentsWithSpaces: indentsWithSpaces,
            SettingsKey.checksSpelling: checksSpelling,
            SettingsKey.suggestsCompletions: suggestsCompletions,
            SettingsKey.showsStatusBar: showsStatusBar,
            SettingsKey.editorFontName: editorFontName,
            SettingsKey.editorLineSpacing: editorLineSpacing,
            SettingsKey.syntaxTheme: syntaxTheme,
            SettingsKey.defaultEditorMode: defaultEditorMode,
            SettingsKey.visualTypeface: visualTypeface,
            SettingsKey.visualFontSize: visualFontSize,
            SettingsKey.visualLimitsLineWidth: visualLimitsLineWidth,
            SettingsKey.visualLineWidth: visualLineWidth,
            SettingsKey.rendersMathInEditor: rendersMathInEditor,
            SettingsKey.showsImagesInline: showsImagesInline,
            SettingsKey.collapsesPreambleInVisual: collapsesPreambleInVisual,
            SettingsKey.foldsFloatsOnOpen: foldsFloatsOnOpen,
            SettingsKey.foldsPreambleOnOpen: foldsPreambleOnOpen,
            SettingsKey.showsWelcomeAtLaunch: showsWelcomeAtLaunch,
            SettingsKey.defaultEngine: defaultEngine,
            SettingsKey.typesetsAutomatically: typesetsAutomatically,
            SettingsKey.autoTypesetDelay: autoTypesetDelay,
            SettingsKey.usesLatexmk: usesLatexmk,
            SettingsKey.texBinPath: texBinPath,
            SettingsKey.allowsShellEscape: allowsShellEscape,
            SettingsKey.showsWarnings: showsWarnings,
            SettingsKey.showsBadBoxes: showsBadBoxes,
            SettingsKey.previewShowsTwoPages: previewShowsTwoPages,
        ])
    }

    /// Clamps an editor font size to the supported range.
    static func clampedFontSize(_ size: Double) -> Double {
        min(max(size, minimumFontSize), maximumFontSize)
    }
}
