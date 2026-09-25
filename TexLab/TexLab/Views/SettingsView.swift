//
//  SettingsView.swift
//  TexLab
//

import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// TexLab ▸ Settings.
struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettings()
            }
            Tab("Editor", systemImage: "character.cursor.ibeam") {
                EditorSettings()
            }
            Tab("Typesetting", systemImage: "doc.richtext") {
                TypesettingSettings()
            }
        }
        .frame(width: 560)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @AppStorage(SettingsKey.typesetsAutomatically) private var typesetsAutomatically = AppSettings.typesetsAutomatically
    @AppStorage(SettingsKey.autoTypesetDelay) private var autoTypesetDelay = AppSettings.autoTypesetDelay
    @AppStorage(SettingsKey.previewShowsTwoPages) private var previewShowsTwoPages = AppSettings.previewShowsTwoPages
    @AppStorage(SettingsKey.showsWarnings) private var showsWarnings = AppSettings.showsWarnings
    @AppStorage(SettingsKey.showsBadBoxes) private var showsBadBoxes = AppSettings.showsBadBoxes

    var body: some View {
        Form {
            Section {
                Toggle("Typeset automatically while writing", isOn: $typesetsAutomatically)
                Picker("After a pause of", selection: $autoTypesetDelay) {
                    Text("Half a second").tag(0.5)
                    Text("1 second").tag(1.0)
                    Text("1.5 seconds").tag(1.5)
                    Text("2 seconds").tag(2.0)
                    Text("3 seconds").tag(3.0)
                    Text("5 seconds").tag(5.0)
                }
                .disabled(!typesetsAutomatically)
            } header: {
                Text("Typesetting")
            } footer: {
                Text("TexLab typesets a copy of your document, so the preview includes changes you haven’t saved yet.")
                    .foregroundStyle(.secondary)
            }

            Section("Preview") {
                Toggle("Show two pages side by side", isOn: $previewShowsTwoPages)
            }

            Section("Issues") {
                Toggle("Show warnings", isOn: $showsWarnings)
                Toggle("Show overfull and underfull boxes", isOn: $showsBadBoxes)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Editor

private struct EditorSettings: View {
    @AppStorage(SettingsKey.editorFontSize) private var fontSize = AppSettings.editorFontSize
    @AppStorage(SettingsKey.showsLineNumbers) private var showsLineNumbers = AppSettings.showsLineNumbers
    @AppStorage(SettingsKey.highlightsCurrentLine) private var highlightsCurrentLine = AppSettings.highlightsCurrentLine
    @AppStorage(SettingsKey.wrapsLines) private var wrapsLines = AppSettings.wrapsLines
    @AppStorage(SettingsKey.showsStatusBar) private var showsStatusBar = AppSettings.showsStatusBar
    @AppStorage(SettingsKey.autoPairsBrackets) private var autoPairsBrackets = AppSettings.autoPairsBrackets
    @AppStorage(SettingsKey.autoClosesEnvironments) private var autoClosesEnvironments = AppSettings.autoClosesEnvironments
    @AppStorage(SettingsKey.indentWidth) private var indentWidth = AppSettings.indentWidth
    @AppStorage(SettingsKey.indentsWithSpaces) private var indentsWithSpaces = AppSettings.indentsWithSpaces
    @AppStorage(SettingsKey.checksSpelling) private var checksSpelling = AppSettings.checksSpelling
    @AppStorage(SettingsKey.suggestsCompletions) private var suggestsCompletions = AppSettings.suggestsCompletions
    @AppStorage(SettingsKey.rendersMathInEditor) private var rendersMath = AppSettings.rendersMathInEditor
    @AppStorage(SettingsKey.foldsFloatsOnOpen) private var foldsFloatsOnOpen = AppSettings.foldsFloatsOnOpen
    @AppStorage(SettingsKey.texBinPath) private var texBinPath = AppSettings.texBinPath
    /// Whether formulas can be rendered with the TeX distribution; nil while checking.
    @State private var canRenderMath: Bool?

    var body: some View {
        Form {
            Section("Font") {
                Stepper(value: $fontSize, in: AppSettings.minimumFontSize...AppSettings.maximumFontSize, step: 1) {
                    LabeledContent("Size") {
                        Text("\(Int(fontSize)) pt")
                            .monospacedDigit()
                    }
                }
                Text(verbatim: "\\section{Results} Let $x^2 + y^2 = r^2$. % note")
                    .font(.system(size: fontSize, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .accessibilityHidden(true)
            }

            Section("Display") {
                Toggle("Show line numbers", isOn: $showsLineNumbers)
                Toggle("Highlight the current line", isOn: $highlightsCurrentLine)
                Toggle("Wrap lines to the editor width", isOn: $wrapsLines)
                Toggle("Show status bar", isOn: $showsStatusBar)
            }

            Section {
                Toggle("Show formulas rendered", isOn: $rendersMath)
                Toggle("Collapse figures and tables when opening a document", isOn: $foldsFloatsOnOpen)
            } header: {
                Text("Live Preview")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Formulas show their source again while the insertion point is inside them. Click the chevron beside a line number to collapse an environment.")
                    if rendersMath && canRenderMath == false {
                        Label("Rendering formulas needs a TeX distribution with the preview package, which MacTeX includes.", systemImage: "exclamationmark.triangle")
                    }
                }
                .foregroundStyle(.secondary)
            }
            .task(id: texBinPath) {
                canRenderMath = nil
                guard let distribution = TeXDistribution.locate(customPath: texBinPath) else {
                    canRenderMath = false
                    return
                }
                canRenderMath = await MathRenderer.isAvailable(in: distribution)
            }

            Section {
                Picker("Indentation", selection: indentation) {
                    Text("2 spaces").tag(2)
                    Text("4 spaces").tag(4)
                    Text("8 spaces").tag(8)
                    Text("Tabs").tag(0)
                }
                Toggle("Close brackets and dollar signs automatically", isOn: $autoPairsBrackets)
                Toggle("Close environments automatically", isOn: $autoClosesEnvironments)
                Toggle("Suggest completions after { in \\begin, \\ref, \\cite and more", isOn: $suggestsCompletions)
                Toggle("Check spelling while typing", isOn: $checksSpelling)
            } header: {
                Text("Editing")
            } footer: {
                Text("Press Esc for completions at any time. Option-Return inserts a line break without continuing a list.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var indentation: Binding<Int> {
        Binding {
            indentsWithSpaces ? indentWidth : 0
        } set: { newValue in
            if newValue == 0 {
                indentsWithSpaces = false
                indentWidth = max(indentWidth, 4)
            } else {
                indentsWithSpaces = true
                indentWidth = newValue
            }
        }
    }
}

// MARK: - Typesetting

private struct TypesettingSettings: View {
    @AppStorage(SettingsKey.texBinPath) private var texBinPath = AppSettings.texBinPath
    @AppStorage(SettingsKey.defaultEngine) private var defaultEngine = AppSettings.defaultEngine
    @AppStorage(SettingsKey.usesLatexmk) private var usesLatexmk = AppSettings.usesLatexmk
    @AppStorage(SettingsKey.allowsShellEscape) private var allowsShellEscape = AppSettings.allowsShellEscape

    @State private var distribution: TeXDistribution?
    @State private var version: String?
    @State private var hasSearched = false
    @State private var isChoosingFolder = false
    @State private var isConfirmingDeletion = false

    var body: some View {
        Form {
            Section("TeX Distribution") {
                LabeledContent("Status") {
                    status
                }
                LabeledContent("Location") {
                    HStack {
                        Text(texBinPath.isEmpty ? String(localized: "Automatic") : texBinPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Button("Choose…") {
                            isChoosingFolder = true
                        }
                    }
                }
                if !texBinPath.isEmpty {
                    Button("Use Automatic Location") {
                        texBinPath = ""
                    }
                }
            }

            Section {
                Picker("Default engine", selection: $defaultEngine) {
                    ForEach(TypesettingEngine.allCases) { engine in
                        Text(engine.displayName).tag(engine.rawValue)
                    }
                }
                Toggle("Use latexmk when it’s installed", isOn: $usesLatexmk)
            } header: {
                Text("Typesetting")
            } footer: {
                Text("A document can choose its own engine with Typeset ▸ Engine, which adds a “% !TEX program” comment other TeX editors understand too. latexmk runs BibTeX, Biber and makeindex and repeats passes as needed; without it, TexLab does the same itself.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Allow shell escape", isOn: $allowsShellEscape)
            } header: {
                Text("Security")
            } footer: {
                Text("Shell escape lets a document run programs on your Mac, which packages such as minted need. Turn it on only if you trust every document you typeset.")
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Build files") {
                    HStack {
                        Button("Show in Finder") {
                            showBuildFolder()
                        }
                        Button("Delete…", role: .destructive) {
                            isConfirmingDeletion = true
                        }
                    }
                }
            } footer: {
                Text("TexLab keeps auxiliary files in its cache folder, never next to your documents.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task(id: texBinPath) {
            await refreshDistribution()
        }
        .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                texBinPath = url.filePath
            }
        }
        .confirmationDialog("Delete all build files?", isPresented: $isConfirmingDeletion) {
            Button("Delete Build Files", role: .destructive) {
                try? FileManager.default.removeItem(at: BuildNaming.buildRoot)
            }
        } message: {
            Text("They are recreated the next time you typeset. Open documents keep their current preview.")
        }
    }

    @ViewBuilder
    private var status: some View {
        if BuildNaming.isSandboxed {
            Label("Blocked by App Sandbox", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .help("Remove the App Sandbox capability from the TexLab target, as described in the README.")
        } else if let distribution {
            VStack(alignment: .trailing, spacing: 2) {
                Label(version ?? String(localized: "Found"), systemImage: "checkmark.circle.fill")
                    .symbolRenderingMode(.multicolor)
                    .lineLimit(1)
                Text(distribution.binDirectory.filePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        } else if hasSearched {
            HStack {
                Label("Not found", systemImage: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.multicolor)
                Link("Get MacTeX", destination: URL(string: "https://tug.org/mactex/")!)
            }
        } else {
            ProgressView()
                .controlSize(.small)
        }
    }

    private func refreshDistribution() async {
        let found = TeXDistribution.locate(customPath: texBinPath)
        distribution = found
        hasSearched = true
        version = nil
        if let found {
            version = await found.versionDescription()
        }
    }

    private func showBuildFolder() {
        let folder = BuildNaming.buildRoot
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }
}
