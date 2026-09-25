//
//  TexLabCommands.swift
//  TexLab
//

import SwiftUI

/// The menu bar. Commands act on the focused document window through its session.
struct TexLabCommands: Commands {
    @FocusedValue(\.documentSession) private var session

    @AppStorage(SettingsKey.showsLineNumbers) private var showsLineNumbers = AppSettings.showsLineNumbers
    @AppStorage(SettingsKey.wrapsLines) private var wrapsLines = AppSettings.wrapsLines
    @AppStorage(SettingsKey.showsStatusBar) private var showsStatusBar = AppSettings.showsStatusBar
    @AppStorage(SettingsKey.previewShowsTwoPages) private var previewShowsTwoPages = AppSettings.previewShowsTwoPages
    @AppStorage(SettingsKey.typesetsAutomatically) private var typesetsAutomatically = AppSettings.typesetsAutomatically

    var body: some Commands {
        SidebarCommands()
        ToolbarCommands()
        TextEditingCommands()

        // File
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
            Divider()
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
                Divider()
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

        CommandGroup(replacing: .help) {
            Link("LaTeX Documentation", destination: URL(string: "https://www.latex-project.org/help/documentation/")!)
            Link("LaTeX Wikibook", destination: URL(string: "https://en.wikibooks.org/wiki/LaTeX")!)
            Link("CTAN Package Search", destination: URL(string: "https://ctan.org/search")!)
            Divider()
            Link("Get MacTeX", destination: URL(string: "https://tug.org/mactex/")!)
        }
    }

    private func formatButton(_ format: FormatCommand) -> some View {
        Button(format.title) {
            session?.editor.toggleWrap(prefix: format.prefix, suffix: format.suffix, actionName: format.title)
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
