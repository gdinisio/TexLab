//
//  TexLabCommands.swift
//  TexLab
//

import AppKit
import Foundation
import Observation
import SwiftUI

/// The menu bar. Commands act on the main project window through its session.
struct TexLabCommands: Commands {
    @FocusedValue(\.documentSession) private var focusedSession

    /// The main project window's session.
    private var session: DocumentSession? {
        focusedSession ?? ActiveSession.shared.session
    }

    @AppStorage(SettingsKey.showsLineNumbers) private var showsLineNumbers = AppSettings.showsLineNumbers
    @AppStorage(SettingsKey.wrapsLines) private var wrapsLines = AppSettings.wrapsLines
    @AppStorage(SettingsKey.showsStatusBar) private var showsStatusBar = AppSettings.showsStatusBar
    @AppStorage(SettingsKey.previewShowsTwoPages) private var previewShowsTwoPages = AppSettings.previewShowsTwoPages
    @AppStorage(SettingsKey.typesetsAutomatically) private var typesetsAutomatically = AppSettings.typesetsAutomatically

    var body: some Commands {
        SidebarCommands()
        ToolbarCommands()
        TextEditingCommands()

        FileAndHelpCommands()

        // Edit
        CommandGroup(after: .textEditing) {
            Button("Go to Line…") {
                session?.isShowingGoToLine = true
            }
            .keyboardShortcut("l")
            .disabled(session == nil)
            Button("Find in Project…") {
                session?.showFindInProject()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(session == nil)
            Button("Jump to Definition") {
                session?.jumpToDefinitionAtSelection()
            }
            .keyboardShortcut("j", modifiers: [.command, .control])
            .disabled(session == nil)
        }

        // View
        CommandGroup(after: .sidebar) {
            Group {
                Button(session?.isPreviewVisible == false ? "Show Preview" : "Hide Preview") {
                    session?.isPreviewVisible.toggle()
                }
                .keyboardShortcut("p", modifiers: [.command, .option])
                .disabled(session == nil)
                Button(showsStatusBar ? "Hide Status Bar" : "Show Status Bar") {
                    showsStatusBar.toggle()
                }
                Divider()
                Toggle("Line Numbers", isOn: $showsLineNumbers)
                Toggle("Wrap Lines", isOn: $wrapsLines)
            }
            liveSourceCommands
            Menu("Navigators") {
                navigatorButton("Project", tab: .project, key: "1")
                navigatorButton("Outline", tab: .outline, key: "2")
                navigatorButton("Find", tab: .find, key: "3")
                navigatorButton("References", tab: .references, key: "4")
                navigatorButton("Issues", tab: .issues, key: "5")
            }
            .disabled(session == nil)
            Group {
                Button("Go Back") {
                    session?.goBack()
                }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .control])
                .disabled(session?.canGoBack != true)
                Button("Go Forward") {
                    session?.goForward()
                }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .control])
                .disabled(session?.canGoForward != true)
                Button("Show Main File") {
                    session?.showMainFile()
                }
                .keyboardShortcut(.upArrow, modifiers: [.command, .control])
                .disabled(session?.project?.mainFile == nil || session?.isMainFile != false)
            }
            Divider()
            previewZoomCommands
            Toggle("Two Pages", isOn: $previewShowsTwoPages)
            Divider()
        }

        CommandMenu("Insert") {
            InsertMenuContent(session: session)
                .disabled(session == nil)
        }

        CommandMenu("Format") {
            Group {
                formatButton(.bold)
                    .keyboardShortcut("b")
                formatButton(.italic)
                    .keyboardShortcut("i")
                formatButton(.underline)
                    .keyboardShortcut("u")
                formatButton(.emphasis)
                formatButton(.monospace)
                formatButton(.smallCaps)
                formatButton(.sansSerif)
            }
            .disabled(session == nil)
            Divider()
            Group {
                Button("Comment Selection") {
                    session?.editor.toggleComment()
                }
                .keyboardShortcut("/")
                Button("Shift Right") {
                    session?.editor.shiftRight()
                }
                .keyboardShortcut("]")
                Button("Shift Left") {
                    session?.editor.shiftLeft()
                }
                .keyboardShortcut("[")
            }
            .disabled(session == nil)
            Divider()
            Menu("Text Size") {
                Button("Bigger") {
                    EditorPreferences.adjustFontSize(by: 1)
                }
                .keyboardShortcut("+")
                Button("Smaller") {
                    EditorPreferences.adjustFontSize(by: -1)
                }
                .keyboardShortcut("-")
                Button("Default Size") {
                    EditorPreferences.resetFontSize()
                }
            }
        }

        CommandMenu("Typeset") {
            typesetCommands
            Divider()
            Button("Show in PDF") {
                session?.revealSelectionInPreview()
            }
            .keyboardShortcut("j", modifiers: [.command, .shift])
            .disabled(session?.canSynchronize != true)
            Divider()
            Button("Next Issue") {
                session?.revealAdjacentIssue(forward: true)
            }
            .keyboardShortcut("'")
            .disabled(session?.allIssues.isEmpty != false)
            Button("Previous Issue") {
                session?.revealAdjacentIssue(forward: false)
            }
            .keyboardShortcut("'", modifiers: [.command, .shift])
            .disabled(session?.allIssues.isEmpty != false)
            Button("Show Log") {
                session?.isShowingLog = true
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
            .disabled(session == nil)
            Divider()
            Button("Clean Build Files") {
                session?.cleanBuildFiles()
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
            .disabled(session == nil)
        }
    }

    /// Typeset, Stop, Typeset Automatically and Engine.
    @ViewBuilder
    private var typesetCommands: some View {
        Button("Typeset") {
            session?.typeset()
        }
        .keyboardShortcut("r")
        .disabled(session == nil)
        Button("Stop Typesetting") {
            session?.stopTypesetting()
        }
        .keyboardShortcut(".")
        .disabled(session?.isTypesetting != true)
        Toggle("Typeset Automatically", isOn: $typesetsAutomatically)
        Divider()
        Menu("Engine") {
            if let session {
                EnginePicker(session: session)
            }
        }
        .disabled(session == nil)
    }

    /// The editor mode and Code Folding.
    @ViewBuilder
    private var liveSourceCommands: some View {
        Toggle("Code Editor", isOn: modeBinding(.code))
            .keyboardShortcut("1", modifiers: [.command, .control])
            .disabled(session == nil)
        Toggle("Visual Editor", isOn: modeBinding(.visual))
            .keyboardShortcut("2", modifiers: [.command, .control])
            .disabled(session?.supportsVisualEditor != true)
        Menu("Code Folding") {
            Button("Fold") {
                session?.editor.foldAtSelection()
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            Button("Unfold") {
                session?.editor.unfoldAtSelection()
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
            Divider()
            Button("Fold Figures and Tables") {
                session?.editor.foldFloats()
            }
            .keyboardShortcut(.leftArrow, modifiers: [.command, .option, .control])
            Button("Fold Sections") {
                session?.editor.foldSections()
            }
            Button("Fold Preamble") {
                session?.editor.foldPreamble()
            }
            Button("Unfold All") {
                session?.editor.unfoldAll()
            }
            .keyboardShortcut(.rightArrow, modifiers: [.command, .option, .control])
        }
        .disabled(session == nil)
    }

    private func navigatorButton(_ title: LocalizedStringKey, tab: SidebarTab, key: KeyEquivalent) -> some View {
        Button(title) {
            session?.showNavigator(tab)
        }
        .keyboardShortcut(key)
    }

    private func modeBinding(_ mode: EditorMode) -> Binding<Bool> {
        Binding {
            session?.effectiveEditorMode == mode
        } set: { isOn in
            if isOn {
                session?.setEditorMode(mode)
            }
        }
    }

    /// Zoom In, Zoom Out, Actual Size and Zoom to Fit for the PDF preview.
    @ViewBuilder
    private var previewZoomCommands: some View {
        Button("Zoom In") {
            session?.preview.zoomIn()
        }
        .keyboardShortcut(">", modifiers: .command)
        .disabled(session?.pdfDocument == nil)
        Button("Zoom Out") {
            session?.preview.zoomOut()
        }
        .keyboardShortcut("<", modifiers: .command)
        .disabled(session?.pdfDocument == nil)
        Button("Actual Size") {
            session?.preview.zoomToActualSize()
        }
        .keyboardShortcut("0")
        .disabled(session?.pdfDocument == nil)
        Button("Zoom to Fit") {
            session?.preview.zoomToFit()
        }
        .keyboardShortcut("9")
        .disabled(session?.pdfDocument == nil)
    }

    private func formatButton(_ format: FormatCommand) -> some View {
        Button(format.title) {
            session?.editor.toggleWrap(prefix: format.prefix, suffix: format.suffix, actionName: format.title)
        }
    }
}

/// The File and Help menus. The File menu is a Mac document app's: New, Open and Open
/// Recent from the document controller, and Save, Duplicate, Rename, Move To and Revert
/// To from the document the main window shows.
struct FileAndHelpCommands: Commands {
    @FocusedValue(\.documentSession) private var focusedSession
    @Environment(\.openWindow) private var openWindow

    private var session: DocumentSession? {
        focusedSession ?? ActiveSession.shared.session
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Document") {
                NSDocumentController.shared.newDocument(nil)
            }
            .keyboardShortcut("n")
            NewFromTemplateMenu()
            Button("New Project…") {
                openWindow(id: NewProjectWindow.id)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            Button("New File in Project…") {
                session?.showNewFileSheet()
            }
            .keyboardShortcut("n", modifiers: [.command, .option])
            .disabled(session?.project == nil)
            Divider()
            Button("Open…") {
                NSDocumentController.shared.openDocument(nil)
            }
            .keyboardShortcut("o")
            Button("Open Project…") {
                ProjectOpener.chooseAndOpen()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            OpenRecentMenu()
            OpenRecentProjectMenu()
        }
        CommandGroup(replacing: .saveItem) {
            Button("Close") {
                NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("w")
            Button("Close File") {
                if let session, let document = session.currentDocument {
                    session.closeDocument(document)
                }
            }
            .keyboardShortcut("w", modifiers: [.command, .control])
            .disabled((session?.documents.count ?? 0) < 2)
            Divider()
            documentButton("Save", action: #selector(NSDocument.save(_:)))
                .keyboardShortcut("s")
            documentButton("Duplicate", action: #selector(NSDocument.duplicate(_:)))
                .keyboardShortcut("s", modifiers: [.command, .shift])
            documentButton("Rename…", action: #selector(NSDocument.rename(_:)))
            documentButton("Move To…", action: #selector(NSDocument.move(_:)))
            Menu("Revert To") {
                documentButton("Last Saved Version", action: #selector(NSDocument.revertToSaved(_:)))
                documentButton("Browse All Versions…", action: #selector(NSDocument.browseVersions(_:)))
            }
            .disabled(session?.currentDocument?.fileURL == nil)
        }
        CommandGroup(after: .importExport) {
            Button("Export PDF…") {
                session?.isExportingPDF = true
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
            .disabled(session?.pdfFileURL == nil)
        }
        CommandGroup(replacing: .printItem) {
            Button("Print…") {
                session?.printPDF()
            }
            .keyboardShortcut("p")
            .disabled(session?.pdfDocument == nil)
        }
        CommandGroup(replacing: .help) {
            Link("LaTeX Documentation", destination: URL(string: "https://www.latex-project.org/help/documentation/")!)
            Link("LaTeX Wikibook", destination: URL(string: "https://en.wikibooks.org/wiki/LaTeX")!)
            Link("CTAN Package Search", destination: URL(string: "https://ctan.org/search")!)
            Divider()
            Link("Get MacTeX", destination: URL(string: "https://tug.org/mactex/")!)
        }
    }
}

extension FileAndHelpCommands {
    /// A command of the document the main window shows, sent along the responder chain to
    /// it as the standard menu items are.
    private func documentButton(_ title: LocalizedStringKey, action: Selector) -> some View {
        Button(title) {
            NSApp.sendAction(action, to: nil, from: nil)
        }
        .disabled(session?.currentDocument == nil)
    }
}

/// File ▸ New from Template, listing every built-in template.
struct NewFromTemplateMenu: View {
    var body: some View {
        Menu("New from Template") {
            ForEach(DocumentTemplate.allCases) { template in
                Button(template.title, systemImage: template.systemImage) {
                    TeXDocumentController.newDocument(text: template.text)
                }
            }
        }
    }
}

/// File ▸ Open Recent: the files opened lately, as the document controller remembers them.
struct OpenRecentMenu: View {
    private let recents = RecentDocuments.shared

    var body: some View {
        Menu("Open Recent") {
            let urls = recents.urls
            ForEach(urls, id: \.self) { url in
                Button {
                    TeXDocumentController.open(url)
                } label: {
                    Text(verbatim: url.lastPathComponent)
                }
            }
            Divider()
            Button("Clear Menu") {
                NSDocumentController.shared.clearRecentDocuments(nil)
            }
            .disabled(urls.isEmpty)
        }
    }
}

/// File ▸ Open Recent Project, listing the Welcome window's recent projects.
struct OpenRecentProjectMenu: View {
    private let recents = RecentProjects.shared

    var body: some View {
        Menu("Open Recent Project") {
            ForEach(recents.pinned + recents.unpinned.prefix(12)) { project in
                Button {
                    ProjectOpener.open(project)
                } label: {
                    Text(verbatim: project.name)
                }
                .disabled(!project.exists)
            }
            Divider()
            Button("Clear Menu") {
                recents.clear()
            }
        }
        .disabled(recents.items.isEmpty)
    }
}

/// The document controller's recent documents, observed for the Open Recent menu.
@Observable
final class RecentDocuments {
    static let shared = RecentDocuments()

    private(set) var urls: [URL] = []

    /// Reads the list again. Not before launch: the first document controller made is the
    /// app's, and it must be TexLab's own.
    func refresh() {
        let current = NSDocumentController.shared.recentDocumentURLs
        if current != urls {
            urls = current
        }
    }
}
