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
    case issues

    var id: String { rawValue }
}

/// The state of one document window: the editor, typesetting, the preview and statistics.
///
/// Each window owns a session. Views observe it, and menu commands reach the focused
/// window's session through `FocusedValues`.
@Observable
final class DocumentSession {
    let editor = EditorController()
    let preview = PreviewController()

    /// The document's location on disk, or nil while it is untitled.
    var fileURL: URL?
    /// The document's text encoding, used for the copy TeX reads.
    var encoding: String.Encoding = .utf8

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
    var issues: [Issue] = []
    /// The engine used for the latest typesetting, from a magic comment or Settings.
    var engine: TypesettingEngine = .pdfLaTeX
    /// Whether the document chooses its engine with `% !TEX program`.
    var engineFromMagicComment = false
    var lastTypesetDate: Date?
    var log = ""
    var console = ""

    // MARK: Project

    /// The project this document belongs to, once it has been saved in a folder.
    var project: ProjectSnapshot?
    var isShowingNewFileSheet = false
    /// The folder New File creates the file in.
    var newFileFolder: URL?

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
    var isShowingTableSheet = false
    var isShowingGoToLine = false
    var isExportingPDF = false

    // MARK: Private

    @ObservationIgnored private(set) var text = ""
    @ObservationIgnored var synctex: SyncTeXData?
    @ObservationIgnored var sourceMap: SourceMap?
    @ObservationIgnored var typesetTask: Task<Void, Never>?
    @ObservationIgnored var automaticTypesetTask: Task<Void, Never>?
    @ObservationIgnored var needsAnotherTypeset = false
    @ObservationIgnored var lastBuildDirectory: URL?
    @ObservationIgnored var issueCursor = -1
    @ObservationIgnored private var analysisTask: Task<Void, Never>?
    @ObservationIgnored private var flatOutline: [OutlineItem] = []
    @ObservationIgnored private var navigationObserver: NSObjectProtocol?
    @ObservationIgnored var mathCache: [String: MathImage] = [:]
    @ObservationIgnored var failedMathKeys: Set<String> = []
    /// The preamble and engine the cached formulas were typeset with.
    @ObservationIgnored var mathCacheSignature = ""
    @ObservationIgnored var mathRenderTask: Task<Void, Never>?
    @ObservationIgnored var needsAnotherMathRender = false
    @ObservationIgnored var hasScannedFolds = false
    @ObservationIgnored var projectRefreshTask: Task<Void, Never>?
    @ObservationIgnored var projectWatchers: [DirectoryWatcher] = []
    @ObservationIgnored var watchedFolders: [URL] = []
    @ObservationIgnored var projectObservers: [NSObjectProtocol] = []
    @ObservationIgnored var lastProjectKey = ""
    /// Identifies an untitled document's build folder.
    let sessionID = UUID()

    var documentDirectory: URL? {
        fileURL?.deletingLastPathComponent()
    }

    /// The document's name without its extension, as shown in the title bar.
    var displayName: String {
        fileURL?.deletingPathExtension().lastPathComponent ?? String(localized: "Untitled")
    }

    var isTypesetting: Bool {
        status == .running
    }

    var errorCount: Int {
        issues.filter { $0.severity == .error }.count
    }

    var warningCount: Int {
        issues.filter { $0.severity == .warning }.count
    }

    // MARK: - Lifecycle

    /// Called when the window appears with the document's initial contents.
    func start(text: String, encoding: String.Encoding, fileURL: URL?) {
        self.text = text
        self.encoding = encoding
        self.fileURL = fileURL
        if fileURL == nil {
            // An untitled document has no project yet.
            sidebarTab = .outline
        }
        configureLivePreview()
        analyze()
        observeNavigationRequests()
        startProject()
        if let fileURL, let line = SourceNavigator.takePendingLine(for: fileURL) {
            DispatchQueue.main.async { [weak self] in
                self?.editor.revealLine(line)
            }
        }
        if UserDefaults.standard.bool(forKey: SettingsKey.typesetsAutomatically) {
            typeset()
        }
    }

    /// Called when the window closes.
    func stop() {
        analysisTask?.cancel()
        mathRenderTask?.cancel()
        needsAnotherMathRender = false
        stopProject()
        automaticTypesetTask?.cancel()
        typesetTask?.cancel()
        needsAnotherTypeset = false
        if let navigationObserver {
            NotificationCenter.default.removeObserver(navigationObserver)
        }
        navigationObserver = nil
    }

    // MARK: - Editing

    func sourceDidChange(_ text: String) {
        self.text = text
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
        let path = projectFolder.map { PathUtilities.relativePath(of: url, from: $0) } ?? url.filePath
        let label = BuildNaming.jobName(for: url.deletingPathExtension().lastPathComponent).lowercased()
        editor.insert(Snippet(
            String(localized: "Figure"),
            before: "\\begin{figure}[htbp]\n\t\\centering\n\t\\includegraphics[width=0.8\\linewidth]{\(path)}\n\t\\caption{",
            after: "}\n\t\\label{fig:\(label)}\n\\end{figure}"
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
        PreviewController.print(pdfDocument, jobTitle: displayName, window: editor.textView?.window)
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

    private func analyze() {
        let count = WordCounter.count(in: text)
        if count != wordCount {
            wordCount = count
        }
        let newOutline = OutlineParser.parse(text)
        if newOutline != outline {
            outline = newOutline
            flatOutline = OutlineParser.flatten(newOutline)
            updateCurrentOutlineItem()
        }
        updateLivePreview()

        // Whether this is a main file or a part of one decides the project's main file.
        let projectKey = "\(ProjectIndex.isMainDocument(text))|\(MagicComments(text: text).root ?? "")"
        if projectKey != lastProjectKey {
            lastProjectKey = projectKey
            refreshProject()
        }
    }

    // MARK: - Navigation between windows

    private func observeNavigationRequests() {
        guard navigationObserver == nil else { return }
        navigationObserver = NotificationCenter.default.addObserver(
            forName: SourceNavigator.revealLineNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let path = notification.userInfo?[SourceNavigator.pathKey] as? String
            let line = notification.userInfo?[SourceNavigator.lineKey] as? Int
            MainActor.assumeIsolated {
                self?.handleRevealRequest(path: path, line: line)
            }
        }
    }

    private func handleRevealRequest(path: String?, line: Int?) {
        guard let path, let line, let fileURL, SourceMap.canonicalPath(fileURL) == path else { return }
        _ = SourceNavigator.takePendingLine(for: fileURL)
        editor.revealLine(line)
    }
}

/// Opens source files in their own windows and reveals a line in them.
enum SourceNavigator {
    nonisolated static let revealLineNotification = Notification.Name("TexLabRevealSourceLine")
    nonisolated static let pathKey = "path"
    nonisolated static let lineKey = "line"

    private static var pendingLines: [String: Int] = [:]

    /// Opens `url` in TexLab and moves its editor to `line`.
    static func open(_ url: URL, line: Int?) {
        let path = SourceMap.canonicalPath(url)
        if let line {
            pendingLines[path] = line
            NotificationCenter.default.post(
                name: revealLineNotification,
                object: nil,
                userInfo: [pathKey: path, lineKey: line]
            )
        }
        Task {
            _ = try? await NSDocumentController.shared.openDocument(withContentsOf: url, display: true)
        }
    }

    /// The line a newly opened window should reveal, if one was requested.
    static func takePendingLine(for url: URL) -> Int? {
        pendingLines.removeValue(forKey: SourceMap.canonicalPath(url))
    }
}
