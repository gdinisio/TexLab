//
//  ContentView.swift
//  TexLab
//
//  Created by Giovanni Di Nisio on 25/09/2026.
//

import SwiftUI
import UniformTypeIdentifiers

/// The content of a document window: the outline and issues in the sidebar, and the
/// source editor beside the typeset PDF.
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
        NavigationSplitView(columnVisibility: $session.columnVisibility) {
            SidebarView(session: session)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 420)
        } detail: {
            HSplitView {
                editorColumn
                    .frame(minWidth: 320, idealWidth: 620, maxWidth: .infinity, maxHeight: .infinity)
                if session.isPreviewVisible {
                    PreviewPane(session: session)
                        .frame(minWidth: 280, idealWidth: 560, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 640, minHeight: 400)
        .navigationSubtitle(session.status.summary)
        .toolbar(id: "TexLabDocument") {
            ToolbarItem(id: "typeset", placement: .primaryAction) {
                TypesetToolbarButton(session: session)
            }
            ToolbarItem(id: "insert") {
                InsertToolbarMenu(session: session)
            }
            ToolbarItem(id: "symbols") {
                SymbolsToolbarButton(session: session)
            }
            ToolbarItem(id: "preview") {
                PreviewToolbarToggle(session: session)
            }
            ToolbarItem(id: "share") {
                ShareToolbarButton(session: session)
            }
        }
        .focusedSceneValue(\.documentSession, session)
        .sheet(isPresented: $session.isShowingLog) {
            LogView(session: session)
        }
        .sheet(isPresented: $session.isShowingTableSheet) {
            TableSheet(session: session)
        }
        .sheet(isPresented: $session.isShowingGoToLine) {
            GoToLineSheet(session: session)
        }
        .fileExporter(
            isPresented: $session.isExportingPDF,
            document: session.isExportingPDF ? session.pdfExportDocument : nil,
            contentType: .pdf,
            defaultFilename: session.displayName
        ) { _ in }
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
        // Kept apart from the window's file exporter; SwiftUI presents one file panel per view.
        .fileImporter(isPresented: $session.isImportingImage, allowedContentTypes: [.image, .pdf]) { result in
            if case .success(let url) = result {
                session.insertFigure(for: url)
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

extension FocusedValues {
    /// The session of the focused document window, for menu commands.
    @Entry var documentSession: DocumentSession?
}

#Preview {
    ContentView(document: .constant(TexLabDocument()), fileURL: nil)
}
