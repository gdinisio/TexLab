//
//  TexLabCommands.swift
//  TexLab
//

import Foundation
import SwiftUI

/// The menu bar. Commands act on the focused document window through its session.
struct TexLabCommands: Commands {
    @FocusedValue(\.documentSession) private var session

    @AppStorage(SettingsKey.showsLineNumbers) private var showsLineNumbers = AppSettings.showsLineNumbers
    @AppStorage(SettingsKey.wrapsLines) private var wrapsLines = AppSettings.wrapsLines
    @AppStorage(SettingsKey.showsStatusBar) private var showsStatusBar = AppSettings.showsStatusBar
    @AppStorage(SettingsKey.previewShowsTwoPages) private var previewShowsTwoPages = AppSettings.previewShowsTwoPages
    @AppStorage(SettingsKey.typesetsAutomatically) private var typesetsAutomatically = AppSettings.typesetsAutomatically
    @AppStorage(SettingsKey.showsLivePreview) private var showsLivePreview = AppSettings.showsLivePreview

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
            .disabled(session?.issues.isEmpty != false)
            Button("Previous Issue") {
                session?.revealAdjacentIssue(forward: false)
            }
            .keyboardShortcut("'", modifiers: [.command, .shift])
            .disabled(session?.issues.isEmpty != false)
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

    /// Live Preview and Code Folding.
    @ViewBuilder
    private var liveSourceCommands: some View {
        Toggle("Live Preview", isOn: $showsLivePreview)
            .keyboardShortcut("m", modifiers: [.command, .control])
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

/// The File and Help menu additions.
struct FileAndHelpCommands: Commands {
    @FocusedValue(\.documentSession) private var session

    var body: some Commands {
        CommandGroup(after: .newItem) {
            NewFromTemplateMenu()
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

/// File ▸ New from Template, listing every built-in template.
struct NewFromTemplateMenu: View {
    @Environment(\.newDocument) private var newDocument

    var body: some View {
        Menu("New from Template") {
            ForEach(DocumentTemplate.allCases) { template in
                Button(template.title, systemImage: template.systemImage) {
                    newDocument(TexLabDocument(text: template.text))
                }
            }
        }
    }
}
