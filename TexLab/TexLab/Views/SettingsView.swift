//
//  SettingsView.swift
//  TexLab
//

import AppKit
import CoreText
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
            Tab("Visual Editor", systemImage: "eye") {
                VisualEditorSettings()
            }
            Tab("Typesetting", systemImage: "doc.richtext") {
                TypesettingSettings()
            }
        }
        .frame(width: 600)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @AppStorage(SettingsKey.showsWelcomeAtLaunch) private var showsWelcomeAtLaunch = AppSettings.showsWelcomeAtLaunch
    @AppStorage(SettingsKey.typesetsAutomatically) private var typesetsAutomatically = AppSettings.typesetsAutomatically
    @AppStorage(SettingsKey.autoTypesetDelay) private var autoTypesetDelay = AppSettings.autoTypesetDelay
    @AppStorage(SettingsKey.previewShowsTwoPages) private var previewShowsTwoPages = AppSettings.previewShowsTwoPages
    @AppStorage(SettingsKey.showsWarnings) private var showsWarnings = AppSettings.showsWarnings
    @AppStorage(SettingsKey.showsBadBoxes) private var showsBadBoxes = AppSettings.showsBadBoxes
    @AppStorage(SettingsKey.showsStatusBar) private var showsStatusBar = AppSettings.showsStatusBar

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Show the Welcome window when TexLab opens", isOn: $showsWelcomeAtLaunch)
            }

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

            Section("Window") {
                Toggle("Show two preview pages side by side", isOn: $previewShowsTwoPages)
                Toggle("Show the status bar", isOn: $showsStatusBar)
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
    @AppStorage(SettingsKey.editorFontName) private var fontName = AppSettings.editorFontName
    @AppStorage(SettingsKey.editorFontSize) private var fontSize = AppSettings.editorFontSize
    @AppStorage(SettingsKey.editorLineSpacing) private var lineSpacing = AppSettings.editorLineSpacing
    @AppStorage(SettingsKey.syntaxTheme) private var themeName = AppSettings.syntaxTheme
    @AppStorage(SettingsKey.showsLineNumbers) private var showsLineNumbers = AppSettings.showsLineNumbers
    @AppStorage(SettingsKey.highlightsCurrentLine) private var highlightsCurrentLine = AppSettings.highlightsCurrentLine
    @AppStorage(SettingsKey.wrapsLines) private var wrapsLines = AppSettings.wrapsLines
    @AppStorage(SettingsKey.autoPairsBrackets) private var autoPairsBrackets = AppSettings.autoPairsBrackets
    @AppStorage(SettingsKey.autoClosesEnvironments) private var autoClosesEnvironments = AppSettings.autoClosesEnvironments
    @AppStorage(SettingsKey.indentWidth) private var indentWidth = AppSettings.indentWidth
    @AppStorage(SettingsKey.indentsWithSpaces) private var indentsWithSpaces = AppSettings.indentsWithSpaces
    @AppStorage(SettingsKey.checksSpelling) private var checksSpelling = AppSettings.checksSpelling
    @AppStorage(SettingsKey.suggestsCompletions) private var suggestsCompletions = AppSettings.suggestsCompletions
    @AppStorage(SettingsKey.foldsFloatsOnOpen) private var foldsFloatsOnOpen = AppSettings.foldsFloatsOnOpen
    @AppStorage(SettingsKey.foldsPreambleOnOpen) private var foldsPreambleOnOpen = AppSettings.foldsPreambleOnOpen

    /// Installed monospaced font families, loaded when the pane appears.
    @State private var fontFamilies: [String] = []

    var body: some View {
        Form {
            Section {
                Picker("Font", selection: $fontName) {
                    Text("SF Mono (System)").tag("")
                    if !fontFamilies.isEmpty {
                        Divider()
                    }
                    ForEach(fontFamilies, id: \.self) { family in
                        Text(family).tag(family)
                    }
                    // Keep a font that is no longer installed selectable.
                    if !fontName.isEmpty && !fontFamilies.isEmpty && !fontFamilies.contains(fontName) {
                        Text(fontName).tag(fontName)
                    }
                }
                Stepper(value: $fontSize, in: AppSettings.minimumFontSize...AppSettings.maximumFontSize, step: 1) {
                    LabeledContent("Size") {
                        Text("\(Int(fontSize)) pt")
                            .monospacedDigit()
                    }
                }
                Picker("Line spacing", selection: $lineSpacing) {
                    Text("Tight").tag(1.0)
                    Text("Normal").tag(1.15)
                    Text("Relaxed").tag(1.3)
                    Text("Loose").tag(1.5)
                    Text("Double").tag(2.0)
                }
                Picker("Colours", selection: $themeName) {
                    ForEach(SyntaxColorTheme.allCases) { theme in
                        Text(theme.title).tag(theme.rawValue)
                    }
                }
                ThemeSample(fontName: fontName, fontSize: fontSize, theme: SyntaxColorTheme(rawValue: themeName) ?? .standard)
            } header: {
                Text("Font and Colours")
            } footer: {
                Text("Used by the Code editor, and for markup in the Visual editor. ⌘+ and ⌘− change the size.")
                    .foregroundStyle(.secondary)
            }

            Section("Display") {
                Toggle("Show line numbers", isOn: $showsLineNumbers)
                Toggle("Highlight the current line", isOn: $highlightsCurrentLine)
                Toggle("Wrap lines to the editor width", isOn: $wrapsLines)
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

            Section {
                Toggle("Collapse the preamble when opening a document", isOn: $foldsPreambleOnOpen)
                Toggle("Collapse figures and tables when opening a document", isOn: $foldsFloatsOnOpen)
            } header: {
                Text("Folding")
            } footer: {
                Text("Click the chevron beside a line number to collapse a section, environment, the preamble or a block of comments.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task {
            fontFamilies = FontCatalog.monospacedFamilies()
        }
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

/// A line of LaTeX in the chosen font and colours.
private struct ThemeSample: View {
    var fontName: String
    var fontSize: Double
    var theme: SyntaxColorTheme

    private static let parts: [(String, SyntaxKind?)] = [
        ("\\section", .command), ("{", nil), ("Results", .sectionTitle), ("} Let ", nil),
        ("$x^2 + y^2 = r^2$", .math), (" in ", nil), ("\\ref", .command), ("{", nil),
        ("eq:circle", .reference), ("}. ", nil), ("% checked", .comment),
    ]

    var body: some View {
        Self.parts.reduce(Text(verbatim: "")) { result, part in
            Text("\(result)\(styled(part.0, kind: part.1))")
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }

    private func styled(_ text: String, kind: SyntaxKind?) -> Text {
        let font = SyntaxTheme.codeFont(named: fontName, size: CGFloat(fontSize))
        let displayFont = kind == .sectionTitle
            ? NSFont(descriptor: font.fontDescriptor.withSymbolicTraits(.bold), size: font.pointSize) ?? font
            : font
        return Text(verbatim: text)
            .font(Font(displayFont as CTFont))
            .foregroundStyle(Color(nsColor: kind.map { theme.color(for: $0) } ?? .textColor))
    }
}

/// The fonts offered for the editor.
enum FontCatalog {
    /// Installed font families whose regular face is monospaced, as code fonts are.
    static func monospacedFamilies() -> [String] {
        let manager = NSFontManager.shared
        return manager.availableFontFamilies.filter { family in
            guard !family.hasPrefix("."),
                  let members = manager.availableMembers(ofFontFamily: family),
                  let first = members.first, let name = first.first as? String,
                  let font = NSFont(name: name, size: 12) else { return false }
            return font.isFixedPitch
        }
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
}

// MARK: - Visual editor

private struct VisualEditorSettings: View {
    @AppStorage(SettingsKey.defaultEditorMode) private var defaultEditorMode = AppSettings.defaultEditorMode
    @AppStorage(SettingsKey.visualTypeface) private var visualTypeface = AppSettings.visualTypeface
    @AppStorage(SettingsKey.visualFontSize) private var visualFontSize = AppSettings.visualFontSize
    @AppStorage(SettingsKey.visualLimitsLineWidth) private var limitsLineWidth = AppSettings.visualLimitsLineWidth
    @AppStorage(SettingsKey.visualLineWidth) private var lineWidth = AppSettings.visualLineWidth
    @AppStorage(SettingsKey.rendersMathInEditor) private var rendersMath = AppSettings.rendersMathInEditor
    @AppStorage(SettingsKey.showsImagesInline) private var showsImages = AppSettings.showsImagesInline
    @AppStorage(SettingsKey.collapsesPreambleInVisual) private var collapsesPreamble = AppSettings.collapsesPreambleInVisual
    @AppStorage(SettingsKey.texBinPath) private var texBinPath = AppSettings.texBinPath
    /// Whether formulas can be rendered with the TeX distribution; nil while checking.
    @State private var canRenderMath: Bool?

    var body: some View {
        Form {
            Section {
                Picker("Open documents in", selection: $defaultEditorMode) {
                    ForEach(EditorMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.systemImage).tag(mode.rawValue)
                    }
                }
            } footer: {
                Text("Each window remembers its own mode. Switch with the Code | Visual control in the toolbar, or ⌃⌘1 and ⌃⌘2. Bibliographies and packages always open as code.")
                    .foregroundStyle(.secondary)
            }

            Section("Text") {
                Picker("Typeface", selection: $visualTypeface) {
                    ForEach(VisualTypeface.allCases) { typeface in
                        Text(typeface.title).tag(typeface.rawValue)
                    }
                }
                Stepper(value: $visualFontSize, in: AppSettings.minimumFontSize...AppSettings.maximumFontSize, step: 1) {
                    LabeledContent("Size") {
                        Text("\(Int(visualFontSize)) pt")
                            .monospacedDigit()
                    }
                }
                Toggle("Limit the line length, like a page", isOn: $limitsLineWidth)
                LabeledContent("Line length") {
                    Slider(value: $lineWidth, in: 480...1100, step: 20) {
                        Text("Line length")
                    } minimumValueLabel: {
                        Image(systemName: "text.alignleft")
                            .imageScale(.small)
                    } maximumValueLabel: {
                        Image(systemName: "text.justify.left")
                    }
                    .labelsHidden()
                }
                .disabled(!limitsLineWidth)
            }

            Section {
                Toggle("Show formulas typeset", isOn: $rendersMath)
                Toggle("Show images in place of \\includegraphics", isOn: $showsImages)
                Toggle("Collapse the preamble", isOn: $collapsesPreamble)
            } header: {
                Text("Content")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Headings, lists, formatting, references and figures appear as they will look. Markup shows again wherever the insertion point is, so it can be edited.")
                    if rendersMath && canRenderMath == false {
                        Label("Typesetting formulas needs a TeX distribution with the preview package, which MacTeX includes.", systemImage: "exclamationmark.triangle")
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
        }
        .formStyle(.grouped)
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
