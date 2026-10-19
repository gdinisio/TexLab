//
//  EditorToolbar.swift
//  TexLab
//

import AppKit
import Foundation
import SwiftUI

/// The document window's toolbar, customisable with View ▸ Customize Toolbar.
///
/// It reads left to right as the window does: what's for writing over the editor, what's
/// for the PDF over the preview.
///
/// - Writing: Code | Visual, then what's inserted most — headings, figures, tables, math
///   and symbols. References and citations are a few keystrokes with completion, so they
///   wait in the palette with theorems, lists, formatting and slides.
/// - The project: Add Package.
/// - Output, over the preview: Typeset — which turns into Stop while TeX runs — beside
///   the Preview button, the two things done to the PDF most.
/// - Share, last, as in every Mac document window.
///
/// Every item stays in the window's toolbar proper, never over the sidebar, so hiding the
/// sidebar never hides a tool. With Liquid Glass, items side by side share one capsule
/// and a space starts a new one: the default set is in four groups, and dragging Space
/// from the palette between any two items separates them, while items dragged next to
/// each other join.
struct EditorToolbar: CustomizableToolbarContent {
    var session: DocumentSession

    var body: some CustomizableToolbarContent {
        WritingToolbarItems(session: session)
        ToolbarSpacer(.fixed)
        ProjectToolbarItems(session: session)
        ToolbarSpacer(.fixed)
        OutputToolbarItems(session: session)
        ToolbarSpacer(.fixed)
        DocumentToolbarItems(session: session)
    }
}

// MARK: - Groups

/// Over the editor: how the source is shown, and what's inserted into it.
private struct WritingToolbarItems: CustomizableToolbarContent {
    var session: DocumentSession

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "editorMode") {
            EditorModePicker(session: session)
        }
        ToolbarSpacer(.fixed)
        StructureToolbarItems(session: session)
        ContentToolbarItems(session: session)
        MathToolbarItems(session: session)
        ReferenceToolbarItems(session: session)
        FormattingToolbarItems(session: session)
        PresentationToolbarItems(session: session)
    }
}

/// Over the preview: typesetting and the PDF.
private struct OutputToolbarItems: CustomizableToolbarContent {
    var session: DocumentSession

    var body: some CustomizableToolbarContent {
        TypesettingToolbarItems(session: session)
        ViewToolbarItems(session: session)
    }
}

/// Typesetting and issues.
private struct TypesettingToolbarItems: CustomizableToolbarContent {
    var session: DocumentSession

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "typeset") {
            TypesetToolbarButton(session: session)
        }
        ToolbarItem(id: "stopTypesetting", showsByDefault: false) {
            ToolButton("Stop", systemImage: "stop.fill", help: "Stop typesetting (⌘.)") {
                session.stopTypesetting()
            }
            .disabled(!session.isTypesetting)
        }
        ToolbarItem(id: "typesetAutomatically", showsByDefault: false) {
            AutoTypesetToggle()
        }
        ToolbarItem(id: "engine", showsByDefault: false) {
            Menu {
                EnginePicker(session: session)
            } label: {
                Label("Engine", systemImage: "gearshape.2")
            }
            .help("Choose the TeX engine for this document")
        }
        ToolbarItem(id: "issues", showsByDefault: false) {
            ControlGroup {
                Button {
                    session.revealAdjacentIssue(forward: false)
                } label: {
                    Label("Previous Issue", systemImage: "chevron.up")
                }
                Button {
                    session.revealAdjacentIssue(forward: true)
                } label: {
                    Label("Next Issue", systemImage: "chevron.down")
                }
            } label: {
                Label("Issues", systemImage: "exclamationmark.triangle")
            }
            .disabled(session.allIssues.isEmpty)
            .help("Move through errors and warnings (⌘' and ⇧⌘')")
        }
        ToolbarItem(id: "issueCount", showsByDefault: false) {
            IssueCountToolbarButton(session: session)
        }
        ToolbarItem(id: "log", showsByDefault: false) {
            ToolButton("Log", systemImage: "doc.plaintext", help: "Show the typesetting log (⇧⌘L)") {
                session.isShowingLog = true
            }
        }
        ToolbarItem(id: "cleanBuildFiles", showsByDefault: false) {
            ToolButton("Clean", systemImage: "trash", help: "Delete auxiliary files from previous runs (⇧⌘K)") {
                session.cleanBuildFiles()
            }
        }
    }
}

/// Headings, all together or one by one.
private struct StructureToolbarItems: CustomizableToolbarContent {
    var session: DocumentSession

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "heading") {
            Menu {
                ForEach(SnippetCatalog.headings) { snippet in
                    SnippetButton(session: session, snippet: snippet)
                }
            } label: {
                Label("Heading", systemImage: "textformat.size")
            }
            .help("Insert a chapter, section or other heading")
        }
        ToolbarItem(id: "chapter", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.chapter, help: "Insert a chapter")
        }
        ToolbarItem(id: "section", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.section, help: "Insert a section")
        }
        ToolbarItem(id: "subsection", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.subsection, help: "Insert a subsection")
        }
        ToolbarItem(id: "subsubsection", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.subsubsection, help: "Insert a subsubsection")
        }
        ToolbarItem(id: "paragraphHeading", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.paragraphHeading, help: "Insert a paragraph heading")
        }
    }
}

/// Figures, images, tables, lists and other content.
private struct ContentToolbarItems: CustomizableToolbarContent {
    var session: DocumentSession

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "figure") {
            ToolButton("Figure", systemImage: "photo.badge.plus", help: "Insert a figure from an image file, with a caption and label") {
                session.importImage(as: .figure)
            }
        }
        ToolbarItem(id: "image", showsByDefault: false) {
            ToolButton("Image", systemImage: "photo", help: "Insert an image with \\includegraphics") {
                session.importImage(as: .graphic)
            }
        }
        ToolbarItem(id: "table") {
            ToolButton("Table", systemImage: "tablecells", help: "Insert a table of any size") {
                session.isShowingTableSheet = true
            }
        }
        ToolbarItem(id: "bulletedList", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.bulletedList, title: "Bullets", help: "Insert a bulleted list")
        }
        ToolbarItem(id: "numberedList", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.numberedList, title: "Numbers", help: "Insert a numbered list")
        }
        ToolbarItem(id: "descriptionList", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.descriptionList, title: "Description", help: "Insert a description list")
        }
        ToolbarItem(id: "footnote", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.footnote, help: "Insert a footnote")
        }
        ToolbarItem(id: "link", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.link, packages: ["hyperref"], help: "Insert a link with \\href")
        }
        ToolbarItem(id: "quotation", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.quotation, title: "Quote", help: "Insert a quotation")
        }
        ToolbarItem(id: "codeListing", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.codeListing, title: "Code", packages: ["listings"], help: "Insert a code listing")
        }
    }
}

/// Math, theorems and symbols.
private struct MathToolbarItems: CustomizableToolbarContent {
    var session: DocumentSession

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "math") {
            Menu {
                ForEach(SnippetCatalog.math) { snippet in
                    SnippetButton(session: session, snippet: snippet)
                }
            } label: {
                Label("Math", systemImage: "x.squareroot")
            }
            .help("Insert inline math, equations, fractions, matrices and more")
        }
        ToolbarItem(id: "inlineMath", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.inlineMath, title: "Inline", help: "Insert inline math: $…$")
        }
        ToolbarItem(id: "displayMath", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.displayMath, title: "Display", help: "Insert display math: \\[…\\]")
        }
        ToolbarItem(id: "equation", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.equation, title: "Equation", help: "Insert a numbered equation with a label")
        }
        ToolbarItem(id: "align", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.align, title: "Align", help: "Insert equations aligned at =")
        }
        ToolbarItem(id: "matrix", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.matrix, help: "Insert a matrix")
        }
        ToolbarItem(id: "fraction", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.fraction, help: "Insert a fraction; a selection becomes the numerator")
        }
        ToolbarItem(id: "theorem", showsByDefault: false) {
            Menu {
                ForEach(TheoremKind.allCases) { kind in
                    Button(kind.title) {
                        session.insertTheorem(kind)
                    }
                }
            } label: {
                Label("Theorem", systemImage: "checkmark.seal")
            }
            .help("Insert a theorem, lemma, definition or proof; TexLab defines it in the preamble if needed")
        }
        ToolbarItem(id: "symbols") {
            SymbolsToolbarButton(session: session)
        }
    }
}

/// Citations and cross-references.
private struct ReferenceToolbarItems: CustomizableToolbarContent {
    var session: DocumentSession

    var body: some CustomizableToolbarContent {
        // \cite and \ref are quick to type, with completion, so these are there to add.
        ToolbarItem(id: "cite", showsByDefault: false) {
            CiteToolbarButton(session: session)
        }
        ToolbarItem(id: "reference", showsByDefault: false) {
            ReferenceToolbarButton(session: session)
        }
        ToolbarItem(id: "label", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.label, help: "Insert a label to refer to")
        }
        ToolbarItem(id: "insertMenu", showsByDefault: false) {
            InsertToolbarMenu(session: session)
        }
    }
}

/// Text styles, comments and indentation.
private struct FormattingToolbarItems: CustomizableToolbarContent {
    var session: DocumentSession

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "textStyle", showsByDefault: false) {
            ControlGroup {
                FormatButton(session: session, format: .bold, systemImage: "bold")
                FormatButton(session: session, format: .italic, systemImage: "italic")
                FormatButton(session: session, format: .underline, systemImage: "underline")
            } label: {
                Label("Text Style", systemImage: "textformat")
            }
            .help("Bold, italic and underline (⌘B, ⌘I, ⌘U)")
        }
        ToolbarItem(id: "bold", showsByDefault: false) {
            FormatButton(session: session, format: .bold, systemImage: "bold")
        }
        ToolbarItem(id: "italic", showsByDefault: false) {
            FormatButton(session: session, format: .italic, systemImage: "italic")
        }
        ToolbarItem(id: "emphasis", showsByDefault: false) {
            FormatButton(session: session, format: .emphasis, systemImage: "character.cursor.ibeam")
        }
        ToolbarItem(id: "monospace", showsByDefault: false) {
            FormatButton(session: session, format: .monospace, systemImage: "chevron.left.forwardslash.chevron.right")
        }
        ToolbarItem(id: "smallCaps", showsByDefault: false) {
            FormatButton(session: session, format: .smallCaps, systemImage: "textformat.abc")
        }
        ToolbarItem(id: "comment", showsByDefault: false) {
            ToolButton("Comment", systemImage: "percent", help: "Comment or uncomment the selected lines (⌘/)") {
                session.editor.toggleComment()
            }
        }
        ToolbarItem(id: "indentation", showsByDefault: false) {
            ControlGroup {
                Button {
                    session.editor.shiftLeft()
                } label: {
                    Label("Shift Left", systemImage: "decrease.indent")
                }
                Button {
                    session.editor.shiftRight()
                } label: {
                    Label("Shift Right", systemImage: "increase.indent")
                }
            } label: {
                Label("Indentation", systemImage: "increase.indent")
            }
            .help("Shift the selected lines left or right (⌘[ and ⌘])")
        }
    }
}

/// Beamer slides.
private struct PresentationToolbarItems: CustomizableToolbarContent {
    var session: DocumentSession

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "frame", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.frame, title: "Slide", help: "Insert a Beamer frame")
        }
        ToolbarItem(id: "columns", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.columns, help: "Insert two columns on a slide")
        }
        ToolbarItem(id: "block", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.block, help: "Insert a Beamer block")
        }
        ToolbarItem(id: "pause", showsByDefault: false) {
            SnippetButton(session: session, snippet: SnippetCatalog.pause, help: "Reveal what follows on the next click")
        }
    }
}

/// The preview, navigation and folding.
private struct ViewToolbarItems: CustomizableToolbarContent {
    var session: DocumentSession

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "preview") {
            PreviewToolbarToggle(session: session)
        }
        ToolbarItem(id: "showInPDF", showsByDefault: false) {
            ToolButton("Show in PDF", systemImage: "doc.viewfinder", help: "Show the insertion point in the preview (⇧⌘J)") {
                session.revealSelectionInPreview()
            }
            .disabled(!session.canSynchronize)
        }
        ToolbarItem(id: "zoom", showsByDefault: false) {
            ControlGroup {
                Button {
                    session.preview.zoomOut()
                } label: {
                    Label("Zoom Out", systemImage: "minus.magnifyingglass")
                }
                Button {
                    session.preview.zoomIn()
                } label: {
                    Label("Zoom In", systemImage: "plus.magnifyingglass")
                }
            } label: {
                Label("Zoom", systemImage: "magnifyingglass")
            }
            .disabled(session.pdfDocument == nil)
            .help("Zoom the preview (⌘< and ⌘>)")
        }
        ToolbarItem(id: "zoomToFit", showsByDefault: false) {
            ToolButton("Fit", systemImage: "arrow.up.left.and.arrow.down.right", help: "Fit the page to the preview (⌘9)") {
                session.preview.zoomToFit()
            }
            .disabled(session.pdfDocument == nil)
        }
        ToolbarItem(id: "twoPages", showsByDefault: false) {
            TwoPagesToggle()
        }
        ToolbarItem(id: "folding", showsByDefault: false) {
            ControlGroup {
                Button {
                    session.editor.foldAtSelection()
                } label: {
                    Label("Fold", systemImage: "rectangle.compress.vertical")
                }
                Button {
                    session.editor.unfoldAll()
                } label: {
                    Label("Unfold All", systemImage: "rectangle.expand.vertical")
                }
            } label: {
                Label("Folding", systemImage: "rectangle.compress.vertical")
            }
            .help("Collapse the environment or section at the insertion point, or expand everything")
        }
        ToolbarItem(id: "find", showsByDefault: false) {
            ToolButton("Find", systemImage: "magnifyingglass", help: "Find and replace in this document (⌘F)") {
                session.editor.showFind()
            }
        }
        ToolbarItem(id: "goToLine", showsByDefault: false) {
            ToolButton("Go to Line", systemImage: "arrow.right.to.line", help: "Go to a line (⌘L)") {
                session.isShowingGoToLine = true
            }
        }
        ToolbarItem(id: "wordCount", showsByDefault: false) {
            Text("^[\(session.wordCount) word](inflect: true)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .help("Words in the document, not counting markup")
        }
    }
}

/// Sharing and exporting the PDF.
private struct DocumentToolbarItems: CustomizableToolbarContent {
    var session: DocumentSession

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "share") {
            ShareToolbarButton(session: session)
        }
        ToolbarItem(id: "exportPDF", showsByDefault: false) {
            ToolButton("Export", systemImage: "arrow.down.doc", help: "Export the typeset PDF (⇧⌘E)") {
                session.isExportingPDF = true
            }
            .disabled(session.pdfFileURL == nil)
        }
        ToolbarItem(id: "print", showsByDefault: false) {
            ToolButton("Print", systemImage: "printer", help: "Print the typeset PDF (⌘P)") {
                session.printPDF()
            }
            .disabled(session.pdfDocument == nil)
        }
    }
}

/// The document's packages and the project's files.
private struct ProjectToolbarItems: CustomizableToolbarContent {
    var session: DocumentSession

    var body: some CustomizableToolbarContent {
        ToolbarItem(id: "addPackage") {
            AddPackageToolbarButton(session: session)
        }
        ToolbarItem(id: "newFile", showsByDefault: false) {
            ToolButton("New File", systemImage: "doc.badge.plus", help: "Add a part, figure, table, image or other file to the project (⌥⌘N)") {
                session.showNewFileSheet()
            }
            .disabled(session.project == nil)
        }
        ToolbarItem(id: "showInFinder", showsByDefault: false) {
            ToolButton("Show in Finder", systemImage: "folder", help: "Show this document in the Finder") {
                if let fileURL = session.fileURL {
                    session.showInFinder([fileURL])
                }
            }
            .disabled(session.fileURL == nil)
        }
    }
}

// MARK: - Controls

/// A toolbar button with a title and symbol, as the customisation palette shows it.
private struct ToolButton: View {
    var title: LocalizedStringKey
    var systemImage: String
    var help: LocalizedStringKey
    var action: () -> Void

    init(_ title: LocalizedStringKey, systemImage: String, help: LocalizedStringKey, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.help = help
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .help(help)
    }
}

/// Inserts a snippet, with the packages it needs.
private struct SnippetButton: View {
    var session: DocumentSession
    var snippet: Snippet
    var title: String?
    var packages: [String] = []
    var help: String?

    var body: some View {
        Button {
            session.insert(snippet, requiring: packages + SnippetCatalog.packages(for: snippet))
        } label: {
            Label(title ?? snippet.title, systemImage: snippet.systemImage ?? "text.insert")
        }
        .help(help ?? snippet.title)
    }
}

/// Wraps the selection in a text style command, or unwraps it.
private struct FormatButton: View {
    var session: DocumentSession
    var format: FormatCommand
    var systemImage: String

    var body: some View {
        Button {
            session.editor.toggleWrap(prefix: format.prefix, suffix: format.suffix, actionName: format.title)
        } label: {
            Label(format.title, systemImage: systemImage)
        }
        .help("\(format.title): \\\(format.command){…}")
    }
}

/// Code | Visual.
struct EditorModePicker: View {
    var session: DocumentSession

    var body: some View {
        Picker("Editor", selection: Binding(get: { session.displayedEditorMode }, set: { session.setEditorMode($0) })) {
            ForEach(EditorMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .fixedSize()
        .disabled(!session.hasVisualEditor)
        .help(session.isBibliography
            ? "Code shows the BibTeX; Visual shows its entries as a table to read and edit (⌃⌘1, ⌃⌘2)"
            : "Code shows the LaTeX source; Visual shows it close to the typeset document (⌃⌘1, ⌃⌘2)")
    }
}

private struct AutoTypesetToggle: View {
    @AppStorage(SettingsKey.typesetsAutomatically) private var typesetsAutomatically = AppSettings.typesetsAutomatically

    var body: some View {
        Toggle(isOn: $typesetsAutomatically) {
            Label("Auto Typeset", systemImage: "bolt")
        }
        .help(typesetsAutomatically ? "Typesetting automatically after a pause in typing" : "Typeset only with ⌘R")
    }
}

private struct TwoPagesToggle: View {
    @AppStorage(SettingsKey.previewShowsTwoPages) private var previewShowsTwoPages = AppSettings.previewShowsTwoPages

    var body: some View {
        Toggle(isOn: $previewShowsTwoPages) {
            Label("Two Pages", systemImage: "book")
        }
        .help("Show two preview pages side by side")
    }
}

/// Add Package: pick a package to load, with what it's for.
private struct AddPackageToolbarButton: View {
    var session: DocumentSession
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Label("Add Package", systemImage: "shippingbox")
        }
        .help("Load a package in the preamble, such as amssymb or tikz")
        .disabled(!session.supportsVisualEditor)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            PackagePicker(session: session) {
                isPresented = false
            }
        }
    }
}

/// Errors and warnings, counted; click to see them in the Issues navigator.
private struct IssueCountToolbarButton: View {
    var session: DocumentSession

    var body: some View {
        Button {
            session.showIssues()
        } label: {
            Label {
                Text("^[\(session.errorCount + session.warningCount) Issue](inflect: true)")
            } icon: {
                Image(systemName: session.errorCount > 0 ? "xmark.octagon.fill" : session.warningCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.circle")
                    .symbolRenderingMode(.multicolor)
            }
        }
        .help(issueSummary)
    }

    private var issueSummary: String {
        let errors = session.errorCount == 1 ? String(localized: "1 error") : String(localized: "\(session.errorCount) errors")
        let warnings = session.warningCount == 1 ? String(localized: "1 warning") : String(localized: "\(session.warningCount) warnings")
        return String(localized: "\(errors) and \(warnings): show them in the Issues navigator")
    }
}

/// Cite: pick entries from the project's bibliographies.
private struct CiteToolbarButton: View {
    var session: DocumentSession
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Label("Cite", systemImage: "quote.bubble")
        }
        .help("Cite entries from the project’s bibliographies")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            CitationPicker(session: session) {
                isPresented = false
            }
        }
    }
}

/// Reference: pick a label to refer to.
private struct ReferenceToolbarButton: View {
    var session: DocumentSession
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Label("Reference", systemImage: "arrow.turn.down.right")
        }
        .help("Refer to a labelled section, figure, table or equation")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            ReferencePicker(session: session) {
                isPresented = false
            }
        }
    }
}
