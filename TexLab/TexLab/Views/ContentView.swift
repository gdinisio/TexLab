//
//  ContentView.swift
//  TexLab
//
//  Created by Giovanni Di Nisio on 25/09/2026.
//

import SwiftUI

/// The content of a document window: the source editor beside the typeset PDF.
struct ContentView: View {
    @Binding var document: TexLabDocument
    var fileURL: URL?

    @State private var session = DocumentSession()
    @SceneStorage("showsPreview") private var showsPreview = true

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
        HSplitView {
            editorColumn
                .frame(minWidth: 320, idealWidth: 640, maxWidth: .infinity, maxHeight: .infinity)
            if session.isPreviewVisible {
                PreviewPane(session: session)
                    .frame(minWidth: 280, idealWidth: 560, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 480, minHeight: 320)
        .navigationSubtitle(session.status.summary)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    session.typeset()
                } label: {
                    Label("Typeset", systemImage: "play.fill")
                }
                .keyboardShortcut("r")
                .help("Typeset the document")
            }
            ToolbarItem(placement: .primaryAction) {
                Toggle(isOn: $session.isPreviewVisible) {
                    Label("Preview", systemImage: "sidebar.trailing")
                }
                .help(session.isPreviewVisible ? "Hide the PDF preview" : "Show the PDF preview")
            }
        }
        .sheet(isPresented: $session.isShowingLog) {
            LogView(session: session)
        }
        .onAppear {
            session.isPreviewVisible = showsPreview
            session.start(text: document.text, encoding: document.encoding, fileURL: fileURL)
        }
        .onDisappear {
            session.stop()
        }
        .onChange(of: fileURL) { _, newValue in
            session.fileURL = newValue
        }
        .onChange(of: session.isPreviewVisible) { _, newValue in
            showsPreview = newValue
        }
    }

    private var editorColumn: some View {
        VStack(spacing: 0) {
            SourceEditor(text: $document.text, configuration: editorConfiguration, session: session)
            if showsStatusBar {
                StatusBar(session: session)
            }
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
