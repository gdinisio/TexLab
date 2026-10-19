//
//  DocumentToolbar.swift
//  TexLab
//

import Foundation
import SwiftUI

/// Typeset, like Xcode's Run: click to typeset, and while TeX runs it's Stop. Hold it for
/// the engine, automatic typesetting, the log and a clean start.
struct TypesetToolbarButton: View {
    var session: DocumentSession
    @AppStorage(SettingsKey.typesetsAutomatically) private var typesetsAutomatically = AppSettings.typesetsAutomatically

    var body: some View {
        Menu {
            if session.isTypesetting {
                Button("Stop Typesetting", systemImage: "stop.fill") {
                    session.stopTypesetting()
                }
            } else {
                Button("Typeset", systemImage: "play.fill") {
                    session.typeset()
                }
            }
            Divider()
            EnginePicker(session: session)
            Divider()
            Toggle("Typeset Automatically", isOn: $typesetsAutomatically)
            Button("Show Log") {
                session.isShowingLog = true
            }
            Button("Clean Build Files") {
                session.cleanBuildFiles()
            }
        } label: {
            if session.isTypesetting {
                Label("Stop", systemImage: "stop.fill")
            } else {
                Label("Typeset", systemImage: "play.fill")
            }
        } primaryAction: {
            if session.isTypesetting {
                session.stopTypesetting()
            } else {
                session.typeset()
            }
        }
        .help(session.isTypesetting
            ? "Stop typesetting (⌘.)"
            : "Typeset the document (⌘R). Hold for the engine and more.")
    }
}

/// How typesetting went, like Xcode's activity view: the outcome, which shows the log when
/// clicked, then the errors and warnings, which show the Issues navigator.
struct TypesetStatusView: View {
    var session: DocumentSession

    var body: some View {
        HStack(spacing: 10) {
            Button {
                session.isShowingLog = true
            } label: {
                HStack(spacing: 6) {
                    icon
                        .frame(width: 16, height: 16)
                    Text(verbatim: title)
                        .lineLimit(1)
                }
            }
            .help(statusHelp)

            if session.errorCount > 0 || session.warningCount > 0 {
                Button {
                    session.showIssues()
                } label: {
                    HStack(spacing: 6) {
                        if session.errorCount > 0 {
                            count(session.errorCount, systemImage: "xmark.octagon.fill")
                        }
                        if session.warningCount > 0 {
                            count(session.warningCount, systemImage: "exclamationmark.triangle.fill")
                        }
                    }
                }
                .help(Self.issueSummary(errors: session.errorCount, warnings: session.warningCount))
            }
        }
        .buttonStyle(.plain)
        .font(.callout)
        .padding(.horizontal, 6)
        .frame(minWidth: 140, alignment: .leading)
    }

    @ViewBuilder
    private var icon: some View {
        if session.isTypesetting {
            ProgressView()
                .controlSize(.small)
        } else {
            Image(systemName: symbolName)
                .foregroundStyle(symbolColor)
        }
    }

    private var symbolName: String {
        switch session.status {
        case .idle: "doc.text"
        case .running: "hourglass"
        case .succeeded: "checkmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        case .cancelled: "stop.circle"
        case .timedOut: "clock.badge.exclamationmark"
        case .empty: "doc"
        case .texNotFound, .couldNotStart: "exclamationmark.triangle.fill"
        }
    }

    private var symbolColor: Color {
        switch session.status {
        case .succeeded: .green
        case .failed: .red
        case .timedOut: .orange
        case .texNotFound, .couldNotStart: .yellow
        case .idle, .running, .cancelled, .empty: .secondary
        }
    }

    /// The outcome in a few words; the issue counts beside it say how many errors.
    private var title: String {
        switch session.status {
        case .idle: String(localized: "Ready")
        case .failed(_, true): String(localized: "Typeset with Errors")
        default: session.status.summary
        }
    }

    private var statusHelp: String {
        var lines = [title]
        if case .couldNotStart(let reason) = session.status {
            lines.append(reason)
        }
        if let date = session.lastTypesetDate, !session.isTypesetting {
            lines.append(String(localized: "Last typeset at \(date.formatted(date: .omitted, time: .shortened)) with \(session.engine.displayName)."))
        }
        lines.append(String(localized: "Click to see the log."))
        return lines.joined(separator: "\n")
    }

    private func count(_ number: Int, systemImage: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.multicolor)
            Text(number, format: .number)
                .monospacedDigit()
        }
    }

    /// "2 errors and 1 warning: …", for the counts' help.
    static func issueSummary(errors: Int, warnings: Int) -> String {
        let errorText = errors == 1 ? String(localized: "1 error") : String(localized: "\(errors) errors")
        let warningText = warnings == 1 ? String(localized: "1 warning") : String(localized: "\(warnings) warnings")
        return String(localized: "\(errorText) and \(warningText): show them in the Issues navigator")
    }
}

/// Chooses the engine by writing a `% !TEX program` comment into the document, or
/// removing it to use the default from Settings.
struct EnginePicker: View {
    var session: DocumentSession

    var body: some View {
        Picker("Engine", selection: selection) {
            Text("Default (\(session.defaultEngine.displayName))").tag(TypesettingEngine?.none)
            ForEach(TypesettingEngine.allCases) { engine in
                Text(engine.displayName).tag(TypesettingEngine?.some(engine))
            }
        }
        .pickerStyle(.inline)
    }

    private var selection: Binding<TypesettingEngine?> {
        Binding {
            session.engineFromMagicComment ? session.engine : nil
        } set: { engine in
            session.setEngine(engine)
        }
    }
}

/// Insert: headings, lists, floats, math, references, environments and symbols.
struct InsertToolbarMenu: View {
    var session: DocumentSession

    var body: some View {
        Menu {
            InsertMenuContent(session: session)
        } label: {
            Label("Insert", systemImage: "plus")
        }
        .help("Insert headings, lists, figures, math and more")
    }
}

/// The contents of the Insert menu, shared by the toolbar and the menu bar.
struct InsertMenuContent: View {
    var session: DocumentSession?

    var body: some View {
        Group {
            snippetMenu("Heading", systemImage: "textformat.size", snippets: SnippetCatalog.headings)
            snippetMenu("List", systemImage: "list.bullet", snippets: SnippetCatalog.lists)
            Divider()
            ForEach(SnippetCatalog.floats) { snippet in
                snippetButton(snippet)
            }
            Button("Figure from Image…", systemImage: "photo.badge.plus") {
                session?.importImage(as: .figure)
            }
            Button("Image…", systemImage: "photo") {
                session?.importImage(as: .graphic)
            }
            Button("Table…", systemImage: "tablecells.badge.ellipsis") {
                session?.isShowingTableSheet = true
            }
        }
        Divider()
        Group {
            snippetMenu("Math", systemImage: "x.squareroot", snippets: SnippetCatalog.math)
            Menu {
                ForEach(TheoremKind.allCases) { kind in
                    Button(kind.title) {
                        session?.insertTheorem(kind)
                    }
                }
            } label: {
                Label("Theorem", systemImage: "checkmark.seal")
            }
            snippetMenu("References", systemImage: "link", snippets: SnippetCatalog.references)
            snippetMenu("Environment", systemImage: "curlybraces", snippets: SnippetCatalog.environments)
            snippetMenu("Presentation", systemImage: "rectangle.on.rectangle", snippets: SnippetCatalog.presentation)
            snippetMenu("Spacing and Breaks", systemImage: "arrow.down.to.line", snippets: SnippetCatalog.breaks)
        }
        Divider()
        Button("Symbol…", systemImage: "function") {
            session?.isShowingSymbols = true
        }
        Button("Package…", systemImage: "shippingbox") {
            session?.isShowingPackagePicker = true
        }
        .disabled(session?.supportsVisualEditor != true)
    }

    private func snippetMenu(_ title: LocalizedStringKey, systemImage: String, snippets: [Snippet]) -> some View {
        Menu {
            ForEach(snippets) { snippet in
                snippetButton(snippet)
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
    }

    @ViewBuilder
    private func snippetButton(_ snippet: Snippet) -> some View {
        if let systemImage = snippet.systemImage {
            Button(snippet.title, systemImage: systemImage) {
                insert(snippet)
            }
        } else {
            Button(snippet.title) {
                insert(snippet)
            }
        }
    }

    /// Inserts a snippet with the packages it needs.
    private func insert(_ snippet: Snippet) {
        var packages = SnippetCatalog.packages(for: snippet)
        if snippet.id == SnippetCatalog.figure.id {
            packages.append("graphicx")
        } else if snippet.id == SnippetCatalog.link.id || snippet.id == SnippetCatalog.url.id {
            packages.append("hyperref")
        } else if snippet.id == SnippetCatalog.codeListing.id {
            packages.append("listings")
        }
        session?.insert(snippet, requiring: packages)
    }
}

/// Symbols: opens the symbol palette.
struct SymbolsToolbarButton: View {
    @Bindable var session: DocumentSession

    var body: some View {
        Button {
            session.isShowingSymbols.toggle()
        } label: {
            Label("Symbols", systemImage: "function")
        }
        .help("Insert a math or text symbol")
        .popover(isPresented: $session.isShowingSymbols, arrowEdge: .bottom) {
            SymbolPalette(session: session)
        }
    }
}

/// Preview: shows or hides the PDF beside the editor.
struct PreviewToolbarToggle: View {
    @Bindable var session: DocumentSession

    var body: some View {
        Toggle(isOn: $session.isPreviewVisible) {
            Label("Preview", systemImage: "sidebar.trailing")
        }
        .help(session.isPreviewVisible ? "Hide the PDF preview" : "Show the PDF preview")
    }
}

/// Share: sends the typeset PDF, named after the document.
struct ShareToolbarButton: View {
    var session: DocumentSession

    var body: some View {
        if let url = session.pdfFileURL {
            ShareLink(item: url) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .help("Share the typeset PDF")
        } else {
            Button {} label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .disabled(true)
            .help("Typeset the document to share it as a PDF")
        }
    }
}
