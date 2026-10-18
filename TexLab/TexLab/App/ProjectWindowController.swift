//
//  ProjectWindowController.swift
//  TexLab
//

import AppKit
import Foundation
import Observation
import SwiftUI

/// A project's window, like an Xcode project window: the navigators, the editor and the
/// preview, showing one of the project's documents at a time.
///
/// A file of a project that has a window opens there, from the Finder, File ▸ Open Recent,
/// the navigator, a search result or an issue alike. While the window shows a document it
/// is that document's window, the way AppKit means it: the title, proxy icon and edited dot
/// are the file's, and File ▸ Save, Rename, Move To, Duplicate and Revert To act on it. Each
/// document saves itself; closing the window closes the project's documents with it.
final class ProjectWindowController: NSWindowController, NSWindowDelegate {
    /// The open project windows, in the order they opened.
    private(set) static var all: [ProjectWindowController] = []

    private static let frameAutosaveName = "TexLabProjectWindow"
    private static let toolbarID = "TexLabEditor"
    private static let windowIdentifier = NSUserInterfaceItemIdentifier("TexLabProjectWindow")
    private static let openFilesKey = "TexLabOpenFiles"

    let session = DocumentSession()
    /// Which of the toolbar identifiers the window has (see `toolbarID(forSlot:)`).
    private let toolbarSlot: Int
    /// The project's folder and main file, known before the project has been scanned.
    private var folderHint: URL?
    private var mainFileHint: URL?
    private var isClosingWindow = false

    // MARK: - Opening

    /// Shows a document being opened: in the window of the project it belongs to, or in a
    /// new window.
    static func open(_ document: TeXDocument) {
        if let controller = window(for: document) {
            controller.display(document)
        } else {
            _ = ProjectWindowController(document: document)
        }
    }

    /// Shows a document in a new window, apart from its project's other windows.
    static func openSeparately(_ document: TeXDocument) {
        let controller = ProjectWindowController(document: document)
        controller.showWindow(nil)
    }

    /// The open window a document belongs in. A complete document, or a part naming or
    /// included by one, belongs with its main file; a bibliography or package with the
    /// project whose folder has it, the innermost if projects are nested.
    private static func window(for document: TeXDocument) -> ProjectWindowController? {
        guard let url = document.fileURL else { return nil }
        if let main = ProjectIndex.projectRoot(forFileAt: url, text: document.text).mainFile {
            let path = SourceMap.canonicalPath(main)
            if let controller = all.first(where: { $0.mainFilePath == path }) {
                return controller
            }
            // A complete document of its own opens in a window of its own.
            if SourceMap.canonicalPath(url) == path {
                return nil
            }
        }
        return all
            .filter { $0.holds(url) }
            .max { ($0.projectFolder?.pathComponents.count ?? 0) < ($1.projectFolder?.pathComponents.count ?? 0) }
    }

    /// The folder the project lives in.
    var projectFolder: URL? {
        session.project?.folder ?? folderHint
    }

    private var mainFilePath: String? {
        (session.project?.mainFile ?? mainFileHint).map(SourceMap.canonicalPath)
    }

    /// Whether `url` is inside the project's folder.
    func holds(_ url: URL) -> Bool {
        guard let projectFolder else { return false }
        return SourceMap.relativePath(of: url, inside: projectFolder) != nil
    }

    // MARK: - Creating

    private init(document: TeXDocument) {
        let slot = Self.freeToolbarSlot()
        toolbarSlot = slot
        let window = ProjectWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        window.identifier = Self.windowIdentifier
        window.minSize = NSSize(width: 640, height: 400)
        window.toolbarStyle = .unified
        window.tabbingIdentifier = Self.frameAutosaveName
        window.isReleasedWhenClosed = false
        super.init(window: window)

        if let url = document.fileURL {
            let root = ProjectIndex.projectRoot(forFileAt: url, text: document.text)
            folderHint = root.folder
            mainFileHint = root.mainFile
        }
        window.delegate = self
        session.windowController = self
        session.prepare(with: document)
        associate(document)

        Self.seedToolbarConfiguration(forSlot: slot)
        let host = NSHostingController(rootView: ProjectWindowView(session: session, toolbarID: Self.toolbarID(forSlot: slot)))
        // SwiftUI's minimum sizes limit the window; the user sizes it.
        host.sizingOptions = [.minSize]
        // The toolbar comes from the SwiftUI view; the title is the document's.
        host.sceneBridgingOptions = [.toolbars]
        window.contentViewController = host
        window.setContentSize(NSSize(width: 1280, height: 820))
        if let previous = Self.all.last?.window {
            window.setFrameTopLeftPoint(window.cascadeTopLeft(from: NSPoint(x: previous.frame.minX, y: previous.frame.maxY)))
        } else if !window.setFrameUsingName(Self.frameAutosaveName) {
            window.center()
        }
        window.setFrameAutosaveName(Self.frameAutosaveName)
        Self.all.append(self)
        WelcomeWindow.dismiss()
    }

    required init?(coder: NSCoder) {
        fatalError("Project windows are made in code")
    }

    // MARK: - Toolbars

    // AppKit treats toolbars with the same identifier as one family and copies every item
    // one of them inserts into the others. SwiftUI inserts a hosted window's items one by
    // one, so a second window with the first one's identifier would put each item into the
    // first window's toolbar again, and AppKit stops at the duplicate. Each open window
    // therefore has an identifier of its own: the first the usual one, the others numbered,
    // starting from the first window's customization.

    /// The lowest toolbar slot no open window has.
    private static func freeToolbarSlot() -> Int {
        let used = Set(all.map(\.toolbarSlot))
        var slot = 0
        while used.contains(slot) {
            slot += 1
        }
        return slot
    }

    private static func toolbarID(forSlot slot: Int) -> String {
        slot == 0 ? toolbarID : "\(toolbarID)-\(slot + 1)"
    }

    /// Gives a numbered toolbar the first window's customization, which AppKit keeps in the
    /// user defaults under the toolbar's identifier.
    private static func seedToolbarConfiguration(forSlot slot: Int) {
        guard slot > 0,
              let primary = all.first(where: { $0.toolbarSlot == 0 })?.window?.toolbar?.identifier,
              primary.contains(toolbarID) else { return }
        let identifier = primary.replacingOccurrences(of: toolbarID, with: toolbarID(forSlot: slot))
        let defaults = UserDefaults.standard
        if let configuration = defaults.dictionary(forKey: "NSToolbar Configuration \(primary)") {
            defaults.set(configuration, forKey: "NSToolbar Configuration \(identifier)")
        }
    }

    // MARK: - Showing documents

    /// Shows one of the project's documents, adding it to the window if it isn't open here
    /// yet, at `line` if given.
    func display(_ document: TeXDocument, line: Int? = nil) {
        session.show(document, line: line)
    }

    /// Makes the window the document's: its title, proxy icon and edited dot, and the
    /// document File ▸ Save and the other document commands act on. The session calls this
    /// as it shows a document.
    func associate(_ document: TeXDocument) {
        document.projectWindow = self
        guard self.document !== document else { return }
        (self.document as? NSDocument)?.removeWindowController(self)
        document.addWindowController(self)
        setDocumentEdited(document.isDocumentEdited)
        document.refreshState()
        invalidateRestorableState()
    }

    /// Adds a document to the window without showing it, as when reopening the window.
    func add(_ document: TeXDocument) {
        document.projectWindow = self
        session.add(document)
        invalidateRestorableState()
    }

    /// A document of this window was renamed, moved or saved for the first time.
    func documentDidMove(_ document: TeXDocument) {
        session.documentDidMove(document)
        invalidateRestorableState()
    }

    /// A document of this window was read again from its file.
    func documentDidRevert(_ document: TeXDocument) {
        session.documentDidRevert(document)
    }

    // MARK: - Closing

    /// Closes a document of the window. It saves itself first; for an untitled document, or
    /// when saving fails, the usual sheet asks what to do. The last document closes the
    /// window.
    func close(_ document: TeXDocument) {
        guard session.documents.count > 1 else {
            window?.performClose(nil)
            return
        }
        DocumentCloser.close(document) { _ in }
    }

    /// A document of this window is closing: the window shows another of them, or closes
    /// with its last one.
    func documentWillClose(_ document: TeXDocument) {
        document.projectWindow = nil
        if !isClosingWindow, document === session.currentDocument, let other = session.documentToShow(insteadOf: document) {
            // Leaving the document first keeps the window open when it closes.
            session.show(other)
        }
        session.forget(document)
        invalidateRestorableState()
    }

    /// The close button and File ▸ Close: every document of the project closes — each saves
    /// itself — and the window with them. Cancelling a document's sheet keeps the window.
    fileprivate func closeWindowAndDocuments() {
        guard !isClosingWindow else { return }
        isClosingWindow = true
        let current = session.currentDocument
        let others = session.documents.filter { $0 !== current }
        // The shown document last: closing it closes the window.
        closeNext(others + [current].compactMap { $0 })
    }

    private func closeNext(_ documents: [TeXDocument]) {
        guard let document = documents.first else {
            if window?.isVisible == true {
                close()
            }
            return
        }
        DocumentCloser.close(document) { [weak self] closed in
            guard let self else { return }
            if closed {
                self.closeNext(Array(documents.dropFirst()))
            } else {
                self.isClosingWindow = false
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        let leftover = session.documents
        session.stop()
        Self.all.removeAll { $0 === self }
        ActiveSession.shared.windowWillClose(self)
        guard !isClosingWindow else { return }
        // Documents the window still had, when it closed some other way: they save and
        // close, rather than staying open without a window.
        for document in leftover where document.projectWindow === self {
            document.projectWindow = nil
            DocumentCloser.close(document) { _ in }
        }
    }

    // MARK: - Restoring

    /// The other files open in the window, so they are open again when TexLab reopens it.
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        let paths = session.documents
            .filter { $0 !== session.currentDocument }
            .compactMap { $0.fileURL?.path(percentEncoded: false) }
        coder.encode(paths as NSArray, forKey: Self.openFilesKey)
    }

    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        guard let paths = coder.decodeObject(of: [NSArray.self, NSString.self], forKey: Self.openFilesKey) as? [String] else { return }
        for path in paths {
            let url = URL(filePath: path)
            guard FileManager.default.fileExists(atPath: path) else { continue }
            Task { [weak self] in
                guard let document = try? await TeXDocumentController.openForProject(url), document.projectWindow == nil else { return }
                self?.add(document)
            }
        }
    }
}

/// The project window: its close button and File ▸ Close close the whole project.
final class ProjectWindow: NSWindow {
    override func performClose(_ sender: Any?) {
        if let controller = windowController as? ProjectWindowController, controller.session.documents.count > 1 {
            controller.closeWindowAndDocuments()
        } else {
            super.performClose(sender)
        }
    }
}

/// Asks a document whether it can close — it saves itself, or asks what to do — and
/// closes it if so.
final class DocumentCloser: NSObject {
    private static let shared = DocumentCloser()
    private var completions: [ObjectIdentifier: (Bool) -> Void] = [:]

    static func close(_ document: NSDocument, completion: @escaping (Bool) -> Void) {
        shared.completions[ObjectIdentifier(document)] = completion
        document.canClose(
            withDelegate: shared,
            shouldClose: #selector(DocumentCloser.document(_:shouldClose:contextInfo:)),
            contextInfo: nil
        )
    }

    @objc private func document(_ document: NSDocument, shouldClose: Bool, contextInfo: UnsafeMutableRawPointer?) {
        let completion = completions.removeValue(forKey: ObjectIdentifier(document))
        if shouldClose {
            document.close()
        }
        completion?(shouldClose)
    }
}

/// The session of the main project window, which the menu bar's commands act on.
@Observable
final class ActiveSession {
    static let shared = ActiveSession()

    private(set) var session: DocumentSession?
    @ObservationIgnored private var observer: NSObjectProtocol?

    func startObserving() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: NSWindow.didBecomeMainNotification, object: nil, queue: .main) { notification in
            let window = notification.object as? NSWindow
            MainActor.assumeIsolated {
                ActiveSession.shared.mainWindowDidChange(window)
            }
        }
    }

    private func mainWindowDidChange(_ window: NSWindow?) {
        let session = (window?.windowController as? ProjectWindowController)?.session
        if session !== self.session {
            self.session = session
        }
    }

    func windowWillClose(_ controller: ProjectWindowController) {
        if session === controller.session {
            session = nil
        }
    }
}
