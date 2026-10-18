//
//  TeXDocument.swift
//  TexLab
//

import AppKit
import CoreGraphics
import Foundation
import Observation
import UniformTypeIdentifiers

extension UTType {
    /// A LaTeX source file (`.tex`, `.ltx`, `.latex`).
    nonisolated static let latexSource = UTType(importedAs: "org.tug.tex", conformingTo: .plainText)

    /// A BibTeX bibliography database (`.bib`).
    nonisolated static let bibTeXDatabase = UTType(importedAs: "org.tug.bib", conformingTo: .plainText)

    /// A LaTeX package (`.sty`).
    nonisolated static let latexPackage = UTType(importedAs: "org.tug.sty", conformingTo: .plainText)

    /// A LaTeX document class (`.cls`).
    nonisolated static let latexClass = UTType(importedAs: "org.tug.cls", conformingTo: .plainText)
}

/// One text file of a project as a Mac document: the main file, a chapter, the
/// bibliography, a package.
///
/// The document system does what documents on the Mac do: changes are saved automatically
/// and kept as versions (File ▸ Revert To), a file changed by another app is read again, a
/// renamed or moved file is followed, and File ▸ Rename, Move To and Duplicate work as they
/// do everywhere else. A project window shows its documents one at a time, like an Xcode
/// project window, and is the window of the one it shows: its title, proxy icon and edited
/// dot are that file's.
///
/// The text keeps the encoding it was read in, so older sources written in Latin-1 or Mac
/// OS Roman are saved back exactly as they were found.
final class TeXDocument: NSDocument {
    /// The text, as the editor last reported it. The document system reads it in
    /// `read(from:ofType:)`, which isn't isolated to the main actor but runs on the main
    /// thread, as TeXDocument doesn't read concurrently; everything else is main-thread code.
    nonisolated(unsafe) var text = ""
    nonisolated(unsafe) var encoding: String.Encoding = .utf8
    /// What views show and follow: the name, the file and whether there are unsaved changes.
    let state = TeXDocumentState()
    /// The project window that has the document open.
    weak var projectWindow: ProjectWindowController?

    // Where the editor was, to come back to.
    var selection = NSRange(location: 0, length: 0)
    var scrollOrigin: CGPoint?
    var folds: [FoldableRegion] = []
    /// Whether the preamble and floats have been collapsed as Settings ask, once per file.
    var hasAppliedOpeningFolds = false

    nonisolated override class var autosavesInPlace: Bool {
        true
    }

    // MARK: - Identity

    /// The canonical path, or nil while the document is untitled.
    var path: String? {
        fileURL.map(SourceMap.canonicalPath)
    }

    func matches(_ url: URL) -> Bool {
        path == SourceMap.canonicalPath(url)
    }

    /// Follows the file: Save As, File ▸ Rename and Move To, and renames in the Finder or
    /// the project navigator.
    nonisolated override var fileURL: URL? {
        didSet {
            guard fileURL != oldValue else { return }
            onMainThread { document in
                document.refreshState()
                document.projectWindow?.documentDidMove(document)
            }
        }
    }

    /// Runs `body` on the main thread — at once if this is it — for changes the document
    /// system makes from its own queues, such as following a file another app moved.
    nonisolated private func onMainThread(_ body: @escaping @MainActor (TeXDocument) -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                body(self)
            }
        } else {
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    body(self)
                }
            }
        }
    }

    /// Brings what views show up to date.
    func refreshState() {
        if state.url != fileURL {
            state.url = fileURL
        }
        if state.name != displayName {
            state.name = displayName
        }
        if state.isEdited != isDocumentEdited {
            state.isEdited = isDocumentEdited
        }
    }

    // MARK: - Reading and writing

    nonisolated override func read(from data: Data, ofType typeName: String) throws {
        let decoded = try TextDecoding.decode(data)
        text = decoded.text
        encoding = decoded.encoding
    }

    override func data(ofType typeName: String) throws -> Data {
        // Text that can no longer be represented in the original encoding (an emoji typed
        // into a Latin-1 file) is saved as UTF-8 rather than losing characters.
        text.data(using: encoding) ?? Data(text.utf8)
    }

    /// Reads the file again — File ▸ Revert To, or a change another app made — and shows
    /// the text it has now.
    override func revert(toContentsOf url: URL, ofType typeName: String) throws {
        try super.revert(toContentsOf: url, ofType: typeName)
        textChangedElsewhere()
        refreshState()
        projectWindow?.documentDidRevert(self)
    }

    /// Forgets what depends on the text, after it changed without the editor.
    func textChangedElsewhere() {
        undoManager?.removeAllActions()
        folds = []
    }

    // MARK: - Unsaved changes

    override func updateChangeCount(_ change: NSDocument.ChangeType) {
        super.updateChangeCount(change)
        refreshState()
    }

    override func updateChangeCount(withToken changeCountToken: Any, for saveOperation: NSDocument.SaveOperationType) {
        super.updateChangeCount(withToken: changeCountToken, for: saveOperation)
        refreshState()
    }

    // MARK: - Windows

    /// Shows the document in its project's window: one already open with the project, or
    /// a new one.
    override func makeWindowControllers() {
        ProjectWindowController.open(self)
    }

    /// Opening a document that is open already shows it in its window.
    override func showWindows() {
        if let projectWindow {
            projectWindow.display(self)
        } else if windowControllers.isEmpty {
            makeWindowControllers()
        }
        super.showWindows()
    }

    override func close() {
        projectWindow?.documentWillClose(self)
        super.close()
    }
}

extension TeXDocument: Identifiable {}

/// What views show of a document, observed as it changes.
@Observable
final class TeXDocumentState {
    var name = String(localized: "Untitled")
    var url: URL?
    /// Changes not yet saved; the document saves them on its own soon after.
    var isEdited = false
}

/// The app's document controller. NSDocument apps get theirs by making it first.
final class TeXDocumentController: NSDocumentController {
    /// Files a project window opens for itself, which don't belong in Open Recent.
    private var quietlyOpening: Set<String> = []

    /// A new document starts from the Article template.
    override func makeUntitledDocument(ofType typeName: String) throws -> NSDocument {
        let document = try super.makeUntitledDocument(ofType: typeName)
        (document as? TeXDocument)?.text = DocumentTemplate.article.text
        return document
    }

    /// Text files without a type of their own — `.bst`, `.def`, `.cfg` — open as plain
    /// text, as the project navigator lists them.
    override func typeForContents(of url: URL) throws -> String {
        let type = try? super.typeForContents(of: url)
        if let type, documentClass(forType: type) != nil {
            return type
        }
        if ProjectFileKind(url: url, isDirectory: false).opensInTexLab {
            return UTType.plainText.identifier
        }
        if let type {
            return type
        }
        throw CocoaError(.fileReadUnknown)
    }

    override func noteNewRecentDocument(_ document: NSDocument) {
        if let url = document.fileURL, quietlyOpening.contains(SourceMap.canonicalPath(url)) {
            return
        }
        super.noteNewRecentDocument(document)
    }

    override func noteNewRecentDocumentURL(_ url: URL) {
        super.noteNewRecentDocumentURL(url)
        RecentDocuments.shared.refresh()
    }

    override func clearRecentDocuments(_ sender: Any?) {
        super.clearRecentDocuments(sender)
        RecentDocuments.shared.refresh()
    }

    /// Opens a file of a project for its window, which shows it itself. A file that is
    /// open already is the same document.
    static func openForProject(_ url: URL) async throws -> TeXDocument {
        let controller = NSDocumentController.shared
        if let open = controller.document(for: url) as? TeXDocument {
            return open
        }
        let path = SourceMap.canonicalPath(url)
        let ours = controller as? TeXDocumentController
        ours?.quietlyOpening.insert(path)
        defer {
            ours?.quietlyOpening.remove(path)
        }
        let (document, _) = try await controller.openDocument(withContentsOf: url, display: false)
        guard let document = document as? TeXDocument else {
            throw CocoaError(.fileReadUnknown)
        }
        return document
    }

    /// Opens a file in its project's window and shows `line` of it.
    static func open(_ url: URL, line: Int? = nil) {
        Task {
            do {
                let (document, _) = try await NSDocumentController.shared.openDocument(withContentsOf: url, display: true)
                if let document = document as? TeXDocument, let line {
                    document.projectWindow?.display(document, line: line)
                }
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    /// A new untitled document with a template's text, in a window of its own.
    static func newDocument(text: String) {
        let controller = NSDocumentController.shared
        do {
            let document = try controller.makeUntitledDocument(ofType: controller.defaultType ?? UTType.latexSource.identifier)
            (document as? TeXDocument)?.text = text
            controller.addDocument(document)
            document.makeWindowControllers()
            document.showWindows()
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

/// Decodes text files whose encoding isn't declared, preferring UTF-8.
nonisolated enum TextDecoding {
    nonisolated struct Result {
        var text: String
        var encoding: String.Encoding
    }

    static func decode(_ data: Data) throws -> Result {
        if let text = String(data: data, encoding: .utf8) {
            return Result(text: text, encoding: .utf8)
        }
        let hasUTF16ByteOrderMark = data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF])
        if hasUTF16ByteOrderMark, let text = String(data: data, encoding: .utf16) {
            return Result(text: text, encoding: .utf16)
        }
        // Legacy 8-bit encodings commonly used by LaTeX sources, most specific first.
        let fallbacks: [String.Encoding] = [.windowsCP1252, .isoLatin1, .macOSRoman]
        for encoding in fallbacks {
            if let text = String(data: data, encoding: encoding) {
                return Result(text: text, encoding: encoding)
            }
        }
        throw CocoaError(.fileReadInapplicableStringEncoding)
    }
}
