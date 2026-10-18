//
//  ProjectWindowView.swift
//  TexLab
//
//  Created by Giovanni Di Nisio on 25/09/2026.
//

import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// The content of a project window: the navigators in the sidebar, and the source editor
/// beside the typeset PDF.
struct ProjectWindowView: View {
    @Bindable var session: DocumentSession

    @AppStorage("showsPreview") private var showsPreview = true

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
    @AppStorage(SettingsKey.editorFontName) private var fontName = AppSettings.editorFontName
    @AppStorage(SettingsKey.editorLineSpacing) private var lineSpacing = AppSettings.editorLineSpacing
    @AppStorage(SettingsKey.syntaxTheme) private var themeName = AppSettings.syntaxTheme
    @AppStorage(SettingsKey.visualTypeface) private var visualTypeface = AppSettings.visualTypeface
    @AppStorage(SettingsKey.visualFontSize) private var visualFontSize = AppSettings.visualFontSize
    @AppStorage(SettingsKey.visualLimitsLineWidth) private var limitsLineWidth = AppSettings.visualLimitsLineWidth
    @AppStorage(SettingsKey.visualLineWidth) private var lineWidth = AppSettings.visualLineWidth
    @AppStorage(SettingsKey.rendersMathInEditor) private var rendersMath = AppSettings.rendersMathInEditor
    @AppStorage(SettingsKey.showsImagesInline) private var showsImages = AppSettings.showsImagesInline
    @AppStorage(SettingsKey.showsLiveIssues) private var showsLiveIssues = AppSettings.showsLiveIssues

    var body: some View {
        NavigationSplitView(columnVisibility: $session.columnVisibility) {
            SidebarView(session: session)
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 420)
        } detail: {
            PaneSplitView(showsTrailing: session.isPreviewVisible, autosaveName: "TexLabEditorPreviewSplit") {
                editorColumn
            } trailing: {
                PreviewPane(session: session)
            }
        }
        .frame(minWidth: 640, minHeight: 400)
        .toolbar(id: "TexLabEditor") {
            EditorToolbar(session: session)
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
        .sheet(isPresented: $session.isShowingNewFileSheet) {
            NewProjectFileSheet(session: session)
        }
        .fileExporter(
            isPresented: $session.isExportingPDF,
            document: session.isExportingPDF ? session.pdfExportDocument : nil,
            contentType: .pdf,
            defaultFilename: session.pdfName
        ) { _ in }
        .onAppear {
            session.isPreviewVisible = showsPreview
            session.start()
        }
        .onChange(of: session.windowSubtitle, initial: true) { _, subtitle in
            // The title is the shown document's, set by the document system.
            session.windowController?.window?.subtitle = subtitle
        }
        .onChange(of: session.isPreviewVisible) { _, newValue in
            showsPreview = newValue
        }
        .onChange(of: rendersMath) {
            session.livePreviewSettingDidChange()
        }
        .onChange(of: showsLiveIssues) {
            session.checkLiveIssues()
        }
    }

    private var editorColumn: some View {
        VStack(spacing: 0) {
            if session.project != nil || session.documents.count > 1 {
                EditorFileBar(session: session)
            }
            SourceEditor(configuration: editorConfiguration, session: session)
            if showsStatusBar {
                StatusBar(session: session)
            }
        }
        // Kept apart from the window's file exporter; SwiftUI presents one file panel per view.
        .fileImporter(isPresented: $session.isImportingImage, allowedContentTypes: [.image, .pdf]) { result in
            if case .success(let url) = result {
                session.insertImportedImage(url)
            }
        }
    }

    private var editorConfiguration: EditorConfiguration {
        EditorConfiguration(
            fontSize: AppSettings.clampedFontSize(fontSize),
            fontName: fontName,
            lineSpacing: lineSpacing,
            themeName: themeName,
            showsLineNumbers: showsLineNumbers,
            highlightsCurrentLine: highlightsCurrentLine,
            wrapsLines: wrapsLines,
            autoPairsBrackets: autoPairsBrackets,
            autoClosesEnvironments: autoClosesEnvironments,
            indentWidth: indentWidth,
            indentsWithSpaces: indentsWithSpaces,
            checksSpelling: checksSpelling,
            suggestsCompletions: suggestsCompletions,
            mode: session.effectiveEditorMode,
            visualTypeface: VisualTypeface(rawValue: visualTypeface) ?? .serif,
            visualFontSize: visualFontSize,
            limitsLineWidth: limitsLineWidth,
            lineWidth: lineWidth,
            rendersMath: rendersMath,
            showsImages: showsImages
        )
    }
}

extension FocusedValues {
    /// The session of the focused document window, for menu commands.
    @Entry var documentSession: DocumentSession?
}
