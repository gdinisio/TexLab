//
//  EditorConfiguration.swift
//  TexLab
//

import Foundation

/// The user's editor preferences, passed from SwiftUI settings into the AppKit editor.
nonisolated struct EditorConfiguration: Equatable, Sendable {
    var fontSize: Double = AppSettings.editorFontSize
    var showsLineNumbers = AppSettings.showsLineNumbers
    var highlightsCurrentLine = AppSettings.highlightsCurrentLine
    var wrapsLines = AppSettings.wrapsLines
    var autoPairsBrackets = AppSettings.autoPairsBrackets
    var autoClosesEnvironments = AppSettings.autoClosesEnvironments
    var indentWidth = AppSettings.indentWidth
    var indentsWithSpaces = AppSettings.indentsWithSpaces
    var checksSpelling = AppSettings.checksSpelling
    var suggestsCompletions = AppSettings.suggestsCompletions
    /// Shows typeset formulas in place of their source until the insertion point enters them.
    var rendersMath = AppSettings.rendersMathInEditor
    /// Hides the markup of `\emph{…}`, `\textbf{…}` and similar commands and shows their
    /// argument in its style instead.
    var stylesFormatting = AppSettings.hidesFormattingCommands

    /// The text inserted for one level of indentation.
    var indentUnit: String {
        indentsWithSpaces ? String(repeating: " ", count: max(indentWidth, 1)) : "\t"
    }

    /// Whether a change requires fonts and colours to be rebuilt.
    func needsNewTheme(comparedTo other: EditorConfiguration) -> Bool {
        fontSize != other.fontSize || indentWidth != other.indentWidth
    }
}

/// Editor actions that change settings rather than a single document.
enum EditorPreferences {
    /// Makes the editor text bigger or smaller for every document, like Format ▸ Font ▸
    /// Bigger in other Mac text editors.
    static func adjustFontSize(by delta: Double) {
        let defaults = UserDefaults.standard
        let current = defaults.double(forKey: SettingsKey.editorFontSize)
        defaults.set(AppSettings.clampedFontSize(current + delta), forKey: SettingsKey.editorFontSize)
    }

    static func resetFontSize() {
        UserDefaults.standard.set(AppSettings.editorFontSize, forKey: SettingsKey.editorFontSize)
    }
}
