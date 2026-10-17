//
//  EditorFile.swift
//  TexLab
//

import AppKit
import CoreGraphics
import Foundation
import Observation

/// A file a window's editor can show: the window's own document, or another text file of
/// its project — a chapter, the bibliography, a package — opened beside it, as files open
/// in one Xcode window.
///
/// Each file keeps its own text, undo history, insertion point, scroll position and folds,
/// so switching between them picks up where you left off. The window's document is saved
/// by the document system, like any Mac document; the other files are saved by the window
/// soon after each change.
@Observable
final class EditorFile: Identifiable {
    /// The canonical path, or a unique name while the window's document is untitled.
    private(set) var id: String
    private(set) var url: URL?
    /// Whether this is the document the window was opened with.
    let isWindowDocument: Bool

    @ObservationIgnored var text: String
    @ObservationIgnored var encoding: String.Encoding
    /// Changes not yet written to disk, for files other than the window's document.
    var hasUnsavedChanges = false
    /// When the file was last read or written, to notice changes made by other apps.
    @ObservationIgnored var modificationDate: Date?
    /// Whether a failure to save has been reported, so it is said once, not after every
    /// pause in typing.
    @ObservationIgnored var hasReportedSaveError = false

    /// Each file's undo history is its own, so undo never reaches into a file that isn't
    /// on screen.
    let undoManager = UndoManager()

    // Where the editor was, to come back to.
    @ObservationIgnored var selection = NSRange(location: 0, length: 0)
    @ObservationIgnored var scrollOrigin: CGPoint?
    @ObservationIgnored var folds: [FoldableRegion] = []
    /// Whether the preamble and floats have been collapsed as Settings ask, once per file.
    @ObservationIgnored var hasAppliedOpeningFolds = false

    init(url: URL?, text: String, encoding: String.Encoding, isWindowDocument: Bool) {
        self.url = url
        self.id = url.map(SourceMap.canonicalPath) ?? "untitled:" + UUID().uuidString
        self.text = text
        self.encoding = encoding
        self.isWindowDocument = isWindowDocument
    }

    /// The file's name, as shown in the file bar and window subtitle.
    var name: String {
        url?.lastPathComponent ?? String(localized: "Untitled")
    }

    /// Follows the file to a new place, after a rename or Save As.
    func move(to newURL: URL?) {
        url = newURL
        id = newURL.map(SourceMap.canonicalPath) ?? id
    }

    /// Forgets what depends on the text, after it changed while the file wasn't shown.
    func textChangedElsewhere() {
        undoManager.removeAllActions()
        folds = []
    }

    func matches(_ url: URL) -> Bool {
        id == SourceMap.canonicalPath(url)
    }

    /// Reads a text file in the encoding it was written in.
    static func load(_ url: URL) throws -> EditorFile {
        let data = try Data(contentsOf: url)
        let decoded = try TextDecoding.decode(data)
        let file = EditorFile(url: url, text: decoded.text, encoding: decoded.encoding, isWindowDocument: false)
        file.modificationDate = modificationDate(of: url)
        return file
    }

    static func modificationDate(of url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    /// Writes the text back in its own encoding, replacing the file safely so a failed
    /// write can't leave half a file, and keeping its permissions and Finder tags.
    func save() throws {
        guard let url, !isWindowDocument else { return }
        let data = text.data(using: encoding) ?? Data(text.utf8)
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { target in
            do {
                let scratch = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: target, create: true)
                let temporary = scratch.appending(path: target.lastPathComponent)
                try data.write(to: temporary)
                _ = try FileManager.default.replaceItemAt(target, withItemAt: temporary)
                try? FileManager.default.removeItem(at: scratch)
            } catch {
                writeError = error
            }
        }
        if let error = coordinationError ?? writeError {
            throw error
        }
        hasUnsavedChanges = false
        modificationDate = Self.modificationDate(of: url)
    }
}

/// Which window edits each file, so a file is only ever edited in one place: opening a
/// file another window shows brings that window forward instead.
final class EditorFileRegistry {
    static let shared = EditorFileRegistry()

    private final class WeakSession {
        weak var session: DocumentSession?
        init(_ session: DocumentSession) {
            self.session = session
        }
    }

    private var owners: [String: WeakSession] = [:]

    /// The window, other than `session`, that has the file at `path` open.
    func owner(of path: String, besides session: DocumentSession) -> DocumentSession? {
        guard let owner = owners[path]?.session, owner !== session else { return nil }
        return owner
    }

    func register(_ path: String, for session: DocumentSession) {
        owners[path] = WeakSession(session)
    }

    func unregister(_ path: String, for session: DocumentSession) {
        if owners[path]?.session === session || owners[path]?.session == nil {
            owners[path] = nil
        }
    }
}
