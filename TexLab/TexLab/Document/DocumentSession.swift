//
//  DocumentSession.swift
//  TexLab
//

import AppKit
import Foundation
import Observation
import PDFKit
import SwiftUI

/// The views the sidebar can show.
nonisolated enum SidebarTab: String, CaseIterable, Identifiable {
    case project
    case outline
    case find
    case references
    case issues

    var id: String { rawValue }
}

/// The state of one project window: the editor, typesetting, the preview and statistics.
///
/// Each project window owns a session. Views observe it, and menu commands reach the main
/// window's session through `ActiveSession`.
@Observable
final class DocumentSession {
    let editor = EditorController()
    let preview = PreviewController()

    /// Where the document the editor shows is on disk; nil while it is untitled.
    var fileURL: URL?
    /// The shown document's text encoding, used for the copy TeX reads.
    var encoding: String.Encoding = .utf8

    // MARK: Documents

    /// The documents open in this window, in the order they were opened: the file the
    /// window opened with, then the ones opened from the navigator, a search result, an
    /// issue or Jump to Definition.
    var documents: [TeXDocument] = []
    /// The document the editor shows.
    var currentDocument: TeXDocument?
    /// The documents shown, oldest first, for Go Back and Go Forward.
    var fileHistory: [ObjectIdentifier] = []
    var fileHistoryIndex = -1
    /// The window, which becomes the window of each document it shows.
    @ObservationIgnored weak var windowController: ProjectWindowController?
    @ObservationIgnored var fileObservers: [NSObjectProtocol] = []
    @ObservationIgnored var isStarted = false

    // MARK: Editing

    private(set) var caretLine = 1
    private(set) var caretColumn = 1
    private(set) var selectionLength = 0
    private(set) var wordCount = 0
    /// The document's headings, frames and floats.
    private(set) var outline: [OutlineItem] = []
    /// The outline item containing the insertion point.
    private(set) var currentOutlineItemID: OutlineItem.ID?

    // MARK: Typesetting

    var status: TypesetStatus = .idle
    /// Issues from the latest typesetting.
    var issues: [Issue] = []
    /// Issues found while typing, before typesetting.
    var liveIssues: [Issue] = []
    /// The engine used for the latest typesetting, from a magic comment or Settings.
    var engine: TypesettingEngine = .pdfLaTeX
    /// Whether the document chooses its engine with `% !TEX program`.
    var engineFromMagicComment = false
    var lastTypesetDate: Date?
    var log = ""
    var console = ""

    // MARK: Editor mode

    /// Code or Visual, chosen per window. Change it with `setEditorMode(_:)`.
    private(set) var editorMode: EditorMode = EditorMode(rawValue: UserDefaults.standard.string(forKey: SettingsKey.defaultEditorMode) ?? "") ?? .visual

    func setEditorMode(_ mode: EditorMode) {
        guard mode != editorMode else { return }
        editorMode = mode
        editorModeDidChange()
    }

    /// The mode the editor shows. Bibliographies, packages and other files that aren't
    /// documents are always shown as code.
    var effectiveEditorMode: EditorMode {
        supportsVisualEditor ? editorMode : .code
    }

    /// Whether this file is a LaTeX document the Visual editor can present.
    var supportsVisualEditor: Bool {
        guard let fileURL else { return true }
        return ProjectFileKind(url: fileURL, isDirectory: false) == .latex
    }

    // MARK: Project

    /// The project this document belongs to, once it has been saved in a folder.
    var project: ProjectSnapshot?
    var isShowingNewFileSheet = false

    // MARK: Find in project

    var findQuery = ""
    var findOptions = SearchOptions()
    var findResults: [SearchFileResult] = []
    var isSearchingProject = false
    /// Incremented to move the focus to the Find navigator's search field.
    var findFieldFocusRequest = 0
    /// The folder New File creates the file in.
    var newFileFolder: URL?
    /// The kind of file New File starts with, such as images from Add Images…, instead of
    /// the kind chosen last time.
    var requestedNewFileKind: NewFileKind?

    // MARK: Preview

    /// The latest successfully produced PDF.
    var pdfDocument: PDFDocument?
    /// A copy of the PDF named after the document, for sharing and exporting.
    var pdfFileURL: URL?

    // MARK: Presentation

    var columnVisibility: NavigationSplitViewVisibility = .all
    var sidebarTab: SidebarTab = .project
    var isPreviewVisible = true
    var isShowingLog = false
    var isShowingSymbols = false
    var isImportingImage = false
    var imageImportPurpose: ImageImportPurpose = .figure
    var isShowingTableSheet = false
    var isShowingGoToLine = false
    var isExportingPDF = false

    // MARK: Private

    /// The shown file's text, as the editor has it.
    @ObservationIgnored var text = ""
    @ObservationIgnored var synctex: SyncTeXData?
    @ObservationIgnored var sourceMap: SourceMap?
    @ObservationIgnored var typesetTask: Task<Void, Never>?
    @ObservationIgnored var automaticTypesetTask: Task<Void, Never>?
    @ObservationIgnored var needsAnotherTypeset = false
    @ObservationIgnored var lastBuildDirectory: URL?
    @ObservationIgnored var issueCursor = -1
    @ObservationIgnored private var analysisTask: Task<Void, Never>?
    @ObservationIgnored private var flatOutline: [OutlineItem] = []
    @ObservationIgnored var mathCache: [String: MathImage] = [:]
    @ObservationIgnored var failedMathKeys: Set<String> = []
    /// The preamble and engine the cached formulas were typeset with.
    @ObservationIgnored var mathCacheSignature = ""
    @ObservationIgnored var mathRenderTask: Task<Void, Never>?
    /// What each `\input` of the shown file shows in the Visual editor, by its path.
    @ObservationIgnored var inclusionPreviews: [String: InclusionPreview] = [:]
    /// Previews of included files that aren't open, with the date the file had.
    @ObservationIgnored var inclusionPreviewCache: [String: (date: Date?, path: String, preview: InclusionPreview)] = [:]
    @ObservationIgnored var needsAnotherMathRender = false
    @ObservationIgnored var hasScannedFolds = false
    @ObservationIgnored var projectRefreshTask: Task<Void, Never>?
    @ObservationIgnored var projectWatchers: [DirectoryWatcher] = []
    @ObservationIgnored var watchedFolders: [URL] = []
    @ObservationIgnored var projectObservers: [NSObjectProtocol] = []
    @ObservationIgnored var lastProjectKey = ""
    @ObservationIgnored var findTask: Task<Void, Never>?
    @ObservationIgnored var liveIssuesTask: Task<Void, Never>?
    @ObservationIgnored var recordedProjectID: String?
    /// Identifies an untitled document's build folder.
    let sessionID = UUID()

    var documentDirectory: URL? {
        fileURL?.deletingLastPathComponent()
    }

    /// The shown file's name without its extension.
    var displayName: String {
        fileURL?.deletingPathExtension().lastPathComponent ?? String(localized: "Untitled")
    }

    /// The name of the typeset PDF: the document's, not the chapter's on screen.
    var pdfName: String {
        pdfFileURL?.deletingPathExtension().lastPathComponent ?? displayName
    }

    var isTypesetting: Bool {
        status == .running
    }

    /// Errors from typesetting and found while typing.
    var errorCount: Int {
        allIssues.filter { $0.severity == .error }.count
    }

    /// Warnings from typesetting and found while typing.
    var warningCount: Int {
        allIssues.filter { $0.severity == .warning }.count
    }

    /// Live issues first, as they describe the text as it is now, then TeX's.
    var allIssues: [Issue] {
        liveIssues + issues
    }

    // MARK: - Lifecycle

    /// Called as the window is made, with the document it opens with.
    func prepare(with document: TeXDocument) {
        documents = [document]
        currentDocument = document
        fileURL = document.fileURL
        text = document.text
        encoding = document.encoding
        hasScannedFolds = document.hasAppliedOpeningFolds
        recordInHistory(document)
        if fileURL == nil {
            // An untitled document has no project yet.
            sidebarTab = .outline
        }
    }

    /// Called when the window appears, once its editor is in place.
    func start() {
        guard !isStarted else { return }
        isStarted = true
        observeFileEvents()
        configureLivePreview()
        analyze()
        startProject()
        if UserDefaults.standard.bool(forKey: SettingsKey.typesetsAutomatically) {
            typeset()
        }
    }

    /// Called when the window closes.
    func stop() {
        analysisTask?.cancel()
        liveIssuesTask?.cancel()
        stopObservingFileEvents()
        mathRenderTask?.cancel()
        needsAnotherMathRender = false
        stopProject()
        automaticTypesetTask?.cancel()
        typesetTask?.cancel()
        needsAnotherTypeset = false
    }

    // MARK: - Editing

    /// Called for each change made in the editor.
    func sourceDidChange(_ text: String) {
        self.text = text
        // The document saves it; its edited state follows its undo history.
        currentDocument?.text = text
        scheduleAnalysis()
        scheduleAutomaticTypeset()
    }

    func selectionDidChange() {
        let position = editor.caretPosition
        let length = editor.selectedRange.length
        if caretLine != position.line {
            caretLine = position.line
            updateCurrentOutlineItem()
        }
        if caretColumn != position.column {
            caretColumn = position.column
        }
        if selectionLength != length {
            selectionLength = length
        }
    }

    /// Inserts a figure for an image file, with a path relative to the document and the
    /// insertion point in the caption.
    func insertFigure(for url: URL) {
        ensurePackages(["graphicx"])
        editor.insert(Snippet(
            String(localized: "Figure"),
            before: "\\begin{figure}[htbp]\n\t\\centering\n\t\\includegraphics[width=0.8\\linewidth]{\(graphicsPath(of: url))}\n\t\\caption{",
            after: "}\n\t\\label{fig:\(figureLabel(for: url))}\n\\end{figure}"
        ))
    }

    // MARK: - Output

    /// The typeset PDF as TeX wrote it, for File ▸ Export PDF.
    var pdfExportDocument: PDFFileDocument? {
        guard let pdfFileURL, let data = try? Data(contentsOf: pdfFileURL) else { return nil }
        return PDFFileDocument(data: data)
    }

    /// Prints the typeset PDF, as a sheet on the document window.
    func printPDF() {
        guard let pdfDocument else {
            NSSound.beep()
            return
        }
        PreviewController.print(pdfDocument, jobTitle: pdfName, window: editor.textView?.window)
    }

    // MARK: - Outline

    func outlineItem(withID id: OutlineItem.ID) -> OutlineItem? {
        flatOutline.first { $0.id == id }
    }

    /// Moves the editor to an outline item and shows it in the preview too.
    func revealOutlineItem(_ item: OutlineItem) {
        editor.revealLine(item.line)
        if canSynchronize && isPreviewVisible {
            revealInPreview(line: item.line)
        }
    }

    /// Moves the editor to an item of the whole document's outline, in whichever file it
    /// is, and shows it in the preview too.
    func revealOutlineEntry(_ entry: DocumentOutlineEntry) {
        var line = entry.line
        if let fileURL, SourceMap.canonicalPath(fileURL) == SourceMap.canonicalPath(entry.file) {
            // The project's outline of the shown file may be a few edits old; find the
            // heading where it is now.
            let matches = flatOutline.filter { $0.kind == entry.kind && $0.title == entry.title }
            if let nearest = matches.min(by: { abs($0.line - entry.line) < abs($1.line - entry.line) }) {
                line = nearest.line
            }
        }
        open(entry.file, line: line)
        // Not when the file opened in a window of its own.
        if canSynchronize && isPreviewVisible, let fileURL, SourceMap.canonicalPath(fileURL) == SourceMap.canonicalPath(entry.file) {
            revealInPreview(line: line)
        }
    }

    private func updateCurrentOutlineItem() {
        let current = flatOutline.last { $0.line <= caretLine }?.id
        if current != currentOutlineItemID {
            currentOutlineItemID = current
        }
    }

    /// Shows the Issues list in the sidebar.
    func showIssues() {
        sidebarTab = .issues
        if columnVisibility == .detailOnly {
            columnVisibility = .all
        }
    }

    /// Text inserted when files are dropped on the editor: graphics become
    /// `\includegraphics`, sources `\input` and bibliographies `\bibliography`.
    func textForDroppedFiles(_ urls: [URL]) -> String {
        urls.map { url in
            // Relative to the main file, which is where TeX looks.
            let path = projectFolder.map { PathUtilities.relativePath(of: url, from: $0) } ?? url.filePath
            let pathWithoutExtension = String(path.dropLast(url.pathExtension.isEmpty ? 0 : url.pathExtension.count + 1))
            switch url.pathExtension.lowercased() {
            case "pdf", "png", "jpg", "jpeg", "eps":
                return "\\includegraphics[width=\\linewidth]{\(path)}"
            case "tex":
                return "\\input{\(pathWithoutExtension)}"
            case "bib":
                return "\\bibliography{\(pathWithoutExtension)}"
            default:
                return path
            }
        }
        .joined(separator: "\n")
    }

    // MARK: - Analysis

    private func scheduleAnalysis() {
        analysisTask?.cancel()
        analysisTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self?.analyze()
        }
    }

    func analyze() {
        let count = WordCounter.count(in: text)
        if count != wordCount {
            wordCount = count
        }
        let newOutline = OutlineParser.parse(text)
        if newOutline != outline {
            let newFlatOutline = OutlineParser.flatten(newOutline)
            let headingsChanged = newFlatOutline.map { "\($0.kind.rawValue) \($0.title)" } != flatOutline.map { "\($0.kind.rawValue) \($0.title)" }
            outline = newOutline
            flatOutline = newFlatOutline
            updateCurrentOutlineItem()
            // The whole document's outline and the chapters' headings come from the project.
            if headingsChanged, (project?.parts.count ?? 0) > 1 {
                refreshProject()
            }
        }
        updateLivePreview()
        checkLiveIssues()

        // Whether this is a main file or a part of one decides the project's main file.
        let projectKey = "\(ProjectIndex.isMainDocument(text))|\(MagicComments(text: text).root ?? "")"
        if projectKey != lastProjectKey {
            lastProjectKey = projectKey
            refreshProject()
        }
    }
}
