//
//  DocumentToolbar.swift
//  TexLab
//

import Foundation
import SwiftUI

/// Typeset: click to typeset, or hold for the engine and Stop.
struct TypesetToolbarButton: View {
    var session: DocumentSession

    var body: some View {
        Menu {
            Button("Stop Typesetting", systemImage: "stop.fill") {
                session.stopTypesetting()
            }
            .disabled(!session.isTypesetting)
            Divider()
            EnginePicker(session: session)
        } label: {
            Label("Typeset", systemImage: "play.fill")
        } primaryAction: {
            session.typeset()
        }
        .help("Typeset the document (⌘R). Hold for the engine.")
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
