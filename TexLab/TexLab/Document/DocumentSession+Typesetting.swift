//
//  DocumentSession+Typesetting.swift
//  TexLab
//

import AppKit
import Foundation
import PDFKit

extension DocumentSession {
    // MARK: - Engine

    /// The engine chosen in Settings, used when a document doesn't name one.
    var defaultEngine: TypesettingEngine {
        TypesettingEngine(rawValue: UserDefaults.standard.string(forKey: SettingsKey.defaultEngine) ?? "") ?? .pdfLaTeX
    }

    /// The engine named by the document's `% !TEX program` comment, if any.
    var magicCommentEngine: TypesettingEngine? {
        MagicComments(text: text).program
    }

    /// Chooses the engine by writing a `% !TEX program` comment at the top of the document,
    /// or removes the comment to use the default engine. The choice travels with the file,
    /// and other TeX editors understand it too.
    func setEngine(_ newEngine: TypesettingEngine?) {
        let magic = MagicComments(text: text)
        let actionName = String(localized: "Change Typesetting Engine")
        let line = newEngine.map(MagicComments.programLine(for:)) ?? ""
        if let range = magic.programLineRange {
            editor.replace(range, with: line, actionName: actionName)
        } else if !line.isEmpty {
            editor.replace(NSRange(location: 0, length: 0), with: line, actionName: actionName)
        }
        engine = newEngine ?? defaultEngine
        engineFromMagicComment = newEngine != nil
    }

    // MARK: - Typesetting

    /// Typesets the document, or queues another run if one is in progress.
    func typeset() {
        automaticTypesetTask?.cancel()
        guard !isTypesetting else {
            needsAnotherTypeset = true
            return
        }

        let defaults = UserDefaults.standard
        guard let distribution = TeXDistribution.locate(customPath: defaults.string(forKey: SettingsKey.texBinPath) ?? "") else {
            status = .texNotFound(sandboxed: BuildNaming.isSandboxed)
            return
        }

        // A `% !TEX root` comment typesets the main file of a multi-file project instead.
        let magic = MagicComments(text: text)
        var rootURL: URL?
        var rootEngine: TypesettingEngine?
        if let root = magic.root, let directory = documentDirectory {
            let url = directory.appending(path: root).standardizedFileURL
            if SourceMap.canonicalPath(url) != fileURL.map(SourceMap.canonicalPath) {
                guard FileManager.default.fileExists(atPath: url.filePath) else {
                    issues = [Issue(
                        id: 0,
                        severity: .error,
                        message: String(localized: "The root file “\(root)” named by % !TEX root wasn’t found"),
                        source: .currentDocument,
                        line: 1
                    )]
                    status = .failed(errors: 1, producedPDF: false)
                    return
                }
                rootURL = url
                if let data = try? Data(contentsOf: url), let rootText = try? TextDecoding.decode(data).text {
                    rootEngine = MagicComments(text: rootText).program
                }
            }
        }

        let engine = rootEngine ?? magic.program ?? defaultEngine
        self.engine = engine
        engineFromMagicComment = rootEngine != nil || magic.program != nil
        guard distribution.supports(engine) else {
            status = .couldNotStart(String(localized: "\(engine.displayName) isn’t installed in the TeX distribution at \(distribution.binDirectory.filePath)."))
            return
        }

        let mainName = rootURL?.deletingPathExtension().lastPathComponent ?? displayName
        let identity = (rootURL ?? fileURL).map(SourceMap.canonicalPath) ?? sessionID.uuidString
        let buildDirectory = BuildNaming.buildRoot.appending(path: BuildNaming.buildKey(for: identity), directoryHint: .isDirectory)
        lastBuildDirectory = buildDirectory

        let request = TypesetRequest(
            source: text,
            encoding: encoding,
            documentURL: fileURL,
            rootURL: rootURL,
            engine: engine,
            distribution: distribution,
            usesLatexmk: defaults.bool(forKey: SettingsKey.usesLatexmk),
            allowsShellEscape: defaults.bool(forKey: SettingsKey.allowsShellEscape),
            buildDirectory: buildDirectory,
            jobName: BuildNaming.jobName(for: mainName)
        )

        status = .running
        typesetTask = Task { [weak self] in
            let work = Task.detached(priority: .userInitiated) {
                await Typesetter.run(request)
            }
            let result = await withTaskCancellationHandler {
                await work.value
            } onCancel: {
                work.cancel()
            }
            self?.finishTypesetting(result, exportName: mainName)
        }
    }

    /// Stops typesetting, keeping the last preview.
    func stopTypesetting() {
        needsAnotherTypeset = false
        automaticTypesetTask?.cancel()
        typesetTask?.cancel()
    }

    /// Typesets after a pause in typing, when automatic typesetting is on.
    func scheduleAutomaticTypeset() {
        automaticTypesetTask?.cancel()
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: SettingsKey.typesetsAutomatically) else { return }
        let delay = max(defaults.double(forKey: SettingsKey.autoTypesetDelay), 0.3)
        automaticTypesetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.typeset()
        }
    }

    /// Deletes the auxiliary files from previous runs, for a fresh start after a package
    /// or class misbehaves.
    func cleanBuildFiles() {
        stopTypesetting()
        if let lastBuildDirectory {
            try? FileManager.default.removeItem(at: lastBuildDirectory)
        }
        pdfFileURL = nil
        synctex = nil
    }

    private func finishTypesetting(_ result: TypesetResult, exportName: String) {
        typesetTask = nil
        lastTypesetDate = Date()
        log = result.log
        console = result.console

        switch result.status {
        case .cancelled:
            status = .cancelled
        case .couldNotStart(let message):
            status = BuildNaming.isSandboxed ? .texNotFound(sandboxed: true) : .couldNotStart(message)
        case .succeeded, .failed, .timedOut:
            sourceMap = result.sourceMap
            issues = makeIssues(from: result.entries, sourceMap: result.sourceMap)
            if fileURL == nil, issues.contains(where: { $0.severity == .error && $0.message.contains("not found") }) {
                // Untitled documents have no folder, so relative files can't be found yet.
                issues.insert(Issue(
                    id: -1,
                    severity: .warning,
                    message: String(localized: "Save the document so TeX can find the files next to it"),
                    source: nil,
                    line: nil
                ), at: 0)
            }
            issueCursor = -1
            if let data = result.pdfData, let document = PDFDocument(data: data) {
                pdfDocument = document
                synctex = result.synctex
                pdfFileURL = exportCopy(of: result.pdfURL, named: exportName)
            }
            if result.status == .succeeded {
                status = .succeeded(pages: pdfDocument?.pageCount ?? 0)
            } else if result.status == .timedOut {
                status = .timedOut
            } else {
                status = .failed(errors: max(errorCount, 1), producedPDF: result.pdfData != nil)
            }
            updateIssueMarkers()
        }

        if needsAnotherTypeset {
            needsAnotherTypeset = false
            typeset()
        }
    }

    private func makeIssues(from entries: [LogEntry], sourceMap: SourceMap) -> [Issue] {
        entries.enumerated()
            .map { index, entry in
                Issue(id: index, severity: entry.severity, message: entry.message, source: entry.file.map(sourceMap.resolve), line: entry.line)
            }
            .sorted { lhs, rhs in
                lhs.severity != rhs.severity ? lhs.severity > rhs.severity : lhs.id < rhs.id
            }
    }

    /// A copy of the PDF named after the document, for Share and Export. APFS clones the
    /// file, so this costs nothing even for large documents.
    private func exportCopy(of pdfURL: URL?, named name: String) -> URL? {
        guard let pdfURL else { return nil }
        let fileManager = FileManager.default
        let folder = pdfURL.deletingLastPathComponent().appending(path: "Export", directoryHint: .isDirectory)
        let destination = folder.appending(path: "\(name).pdf")
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        try? fileManager.removeItem(at: destination)
        guard (try? fileManager.copyItem(at: pdfURL, to: destination)) != nil else { return nil }
        return destination
    }

    // MARK: - Issues

    func updateIssueMarkers() {
        var markers: [Int: IssueMarker] = [:]
        for issue in issues where issue.source == .currentDocument {
            guard let line = issue.line else { continue }
            let marker: IssueMarker
            switch issue.severity {
            case .error: marker = .error
            case .warning: marker = .warning
            case .badBox: continue
            }
            markers[line] = max(markers[line] ?? marker, marker)
        }
        editor.setIssueMarkers(markers)
    }

    /// Shows the source of an issue: in this window, in the file's own window, or in the
    /// log when TeX didn't say where it happened.
    func reveal(_ issue: Issue) {
        switch issue.source {
        case .currentDocument?:
            if let line = issue.line {
                editor.revealLine(line)
            } else {
                isShowingLog = true
            }
        case .file(let url)?:
            SourceNavigator.open(url, line: issue.line)
        case nil:
            isShowingLog = true
        }
    }

    /// Moves through the issues in order, like Xcode's Jump to Next Issue.
    func revealAdjacentIssue(forward: Bool) {
        let showsBadBoxes = UserDefaults.standard.bool(forKey: SettingsKey.showsBadBoxes)
        let navigable = issues.filter { showsBadBoxes || $0.severity != .badBox }
        guard !navigable.isEmpty else {
            NSSound.beep()
            return
        }
        let step = forward ? 1 : -1
        issueCursor = ((issueCursor + step) % navigable.count + navigable.count) % navigable.count
        reveal(navigable[issueCursor])
    }
}
