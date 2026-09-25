//
//  ContentView.swift
//  TexLab
//
//  Created by Giovanni Di Nisio on 25/09/2026.
//

import SwiftUI

/// The content of a document window.
struct ContentView: View {
    @Binding var document: TexLabDocument
    var fileURL: URL?

    @State private var session = DocumentSession()

    @AppStorage(SettingsKey.editorFontSize) private var fontSize = AppSettings.editorFontSize
    @AppStorage(SettingsKey.showsLineNumbers) private var showsLineNumbers = AppSettings.showsLineNumbers
    @AppStorage(SettingsKey.highlightsCurrentLine) private var highlightsCurrentLine = AppSettings.highlightsCurrentLine
    @AppStorage(SettingsKey.wrapsLines) private var wrapsLines = AppSettings.wrapsLines
    @AppStorage(SettingsKey.autoPairsBrackets) private var autoPairsBrackets = AppSettings.autoPairsBrackets
    @AppStorage(SettingsKey.autoClosesEnvironments) private var autoClosesEnvironments = AppSettings.autoClosesEnvironments
    @AppStorage(SettingsKey.indentWidth) private var indentWidth = AppSettings.indentWidth
    @AppStorage(SettingsKey.indentsWithSpaces) private var indentsWithSpaces = AppSettings.indentsWithSpaces
    @AppStorage(SettingsKey.checksSpelling) private var checksSpelling = AppSettings.checksSpelling
    @AppStorage(SettingsKey.suggestsCompletions) private var suggestsCompletions = AppSettings.suggestsCompletions
    @AppStorage(SettingsKey.showsStatusBar) private var showsStatusBar = AppSettings.showsStatusBar

    var body: some View {
        VStack(spacing: 0) {
            SourceEditor(text: $document.text, configuration: editorConfiguration, session: session)
            if showsStatusBar {
                StatusBar(session: session)
            }
        }
        .frame(minWidth: 480, minHeight: 320)
        .onAppear {
            session.start(text: document.text, fileURL: fileURL)
        }
        .onDisappear {
            session.stop()
        }
        .onChange(of: fileURL) { _, newValue in
            session.fileURL = newValue
        }
    }

    private var editorConfiguration: EditorConfiguration {
        EditorConfiguration(
            fontSize: AppSettings.clampedFontSize(fontSize),
            showsLineNumbers: showsLineNumbers,
            highlightsCurrentLine: highlightsCurrentLine,
            wrapsLines: wrapsLines,
            autoPairsBrackets: autoPairsBrackets,
            autoClosesEnvironments: autoClosesEnvironments,
            indentWidth: indentWidth,
            indentsWithSpaces: indentsWithSpaces,
            checksSpelling: checksSpelling,
            suggestsCompletions: suggestsCompletions
        )
    }
}

#Preview {
    ContentView(document: .constant(TexLabDocument()), fileURL: nil)
}
