//
//  Typesetter.swift
//  TexLab
//

import Foundation

/// A source file that took part in typesetting.
nonisolated enum SourceFile: Hashable, Sendable {
    /// The document in the window, including unsaved changes.
    case currentDocument
    /// Another file on disk, such as a chapter or the `% !TEX root` file.
    case file(URL)
}

/// Relates the paths TeX reports (build copies, overlays, relative paths) to the files the
/// user edits.
nonisolated struct SourceMap: Sendable {
    /// The folder TeX ran in; relative paths in logs and SyncTeX data start here.
    var workingDirectory: URL
    /// The file given to TeX.
    var mainInput: URL
    /// What the main input stands for.
    var mainSource: SourceFile
    /// When typesetting a `% !TEX root` file, the folder holding a fresh copy of the
    /// current document at its path relative to the root.
    var overlayDirectory: URL?
    /// The current document's file, if it has been saved.
    var currentDocumentURL: URL?

    func resolve(_ texPath: String) -> SourceFile {
        let url = texPath.hasPrefix("/")
            ? URL(filePath: texPath)
            : workingDirectory.appending(path: texPath)
        let path = Self.canonicalPath(url)
        if path == Self.canonicalPath(mainInput) {
            return mainSource
        }
        if let overlayDirectory, path.hasPrefix(Self.canonicalPath(overlayDirectory) + "/") {
            return .currentDocument
        }
        if let currentDocumentURL, path == Self.canonicalPath(currentDocumentURL) {
            return .currentDocument
        }
        return .file(url.standardizedFileURL)
    }

    /// The path TeX uses for `source`, for looking it up in SyncTeX data.
    func texPaths(for source: SourceFile) -> [String] {
        switch source {
        case .currentDocument:
            var paths: [String] = []
            if mainSource == .currentDocument {
                paths.append(Self.canonicalPath(mainInput))
            }
            if let currentDocumentURL {
                paths.append(Self.canonicalPath(currentDocumentURL))
                if let overlayDirectory, let relative = Self.relativePath(of: currentDocumentURL, inside: workingDirectory) {
                    paths.append(Self.canonicalPath(overlayDirectory.appending(path: relative)))
                }
            }
            return paths
        case .file(let url):
            return [Self.canonicalPath(url)]
        }
    }

    static func canonicalPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().filePath
    }

    /// The path of `url` relative to `directory`, if it is inside it.
    static func relativePath(of url: URL, inside directory: URL) -> String? {
        let path = canonicalPath(url)
        let base = canonicalPath(directory)
        guard path.hasPrefix(base + "/") else { return nil }
        return String(path.dropFirst(base.count + 1))
    }
}

/// Everything needed to typeset a document once.
nonisolated struct TypesetRequest: Sendable {
    var source: String
    var encoding: String.Encoding
    /// The current document's file, or nil while untitled.
    var documentURL: URL?
    /// The `% !TEX root` file to typeset instead of the document, if any.
    var rootURL: URL?
    var engine: TypesettingEngine
    var distribution: TeXDistribution
    var usesLatexmk: Bool
    var allowsShellEscape: Bool
    var buildDirectory: URL
    /// The base name of TeX's output files.
    var jobName: String
}

/// The outcome of typesetting.
nonisolated struct TypesetResult: Sendable {
    nonisolated enum Status: Sendable, Equatable {
        /// A PDF was produced without errors.
        case succeeded
        /// TeX reported errors; a PDF may still have been produced.
        case failed
        case cancelled
        case timedOut
        /// The TeX tools couldn't be started.
        case couldNotStart(String)
    }

    var status: Status
    /// The PDF produced by this run, or nil if TeX didn't write a new one.
    var pdfURL: URL?
    var pdfData: Data?
    var synctex: SyncTeXData?
    var log: String
    var console: String
    var entries: [LogEntry]
    var sourceMap: SourceMap
    var duration: TimeInterval
    var usedLatexmk: Bool
}

/// Runs TeX on a document.
///
/// The document is typeset from a copy of the editor's text in a private build folder, so
/// the preview reflects unsaved changes and auxiliary files never clutter the user's
/// folders. TeX runs in the document's folder, so relative `\input`, `\includegraphics`
/// and bibliography paths work as they would from the command line.
nonisolated enum Typesetter {
    static func run(_ request: TypesetRequest) async -> TypesetResult {
        let start = Date()
        let fileManager = FileManager.default
        let build = request.buildDirectory
        let job = request.jobName

        var sourceMap = SourceMap(
            workingDirectory: request.documentURL?.deletingLastPathComponent() ?? build,
            mainInput: build.appending(path: "\(job).tex"),
            mainSource: .currentDocument,
            overlayDirectory: nil,
            currentDocumentURL: request.documentURL
        )

        func failure(_ status: TypesetResult.Status, console: String = "") -> TypesetResult {
            TypesetResult(
                status: status, pdfURL: nil, pdfData: nil, synctex: nil, log: "", console: console,
                entries: [], sourceMap: sourceMap, duration: Date().timeIntervalSince(start),
                usedLatexmk: false
            )
        }

        do {
            try fileManager.createDirectory(at: build, withIntermediateDirectories: true)
            if let root = request.rootURL {
                sourceMap.workingDirectory = root.deletingLastPathComponent()
                sourceMap.mainInput = root
                sourceMap.mainSource = .file(root)
                // Put the unsaved text where TeX will find it before the saved file.
                if let documentURL = request.documentURL,
                   let relative = SourceMap.relativePath(of: documentURL, inside: sourceMap.workingDirectory) {
                    let overlay = build.appending(path: "Overlay", directoryHint: .isDirectory)
                    try? fileManager.removeItem(at: overlay)
                    let copy = overlay.appending(path: relative)
                    try fileManager.createDirectory(at: copy.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try encodedSource(request).write(to: copy)
                    sourceMap.overlayDirectory = overlay
                }
            } else {
                try encodedSource(request).write(to: sourceMap.mainInput)
            }
        } catch {
            return failure(.couldNotStart(error.localizedDescription))
        }

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = request.distribution.searchPath
        environment["max_print_line"] = "10000"
        environment["error_line"] = "254"
        environment["half_error_line"] = "238"
        environment["TEXMFOUTPUT"] = build.filePath
        environment["BIBINPUTS"] = sourceMap.workingDirectory.filePath + ":"
        if let overlay = sourceMap.overlayDirectory {
            environment["TEXINPUTS"] = overlay.filePath + ":"
        }

        let pipeline = Pipeline(request: request, sourceMap: sourceMap, environment: environment)
        let usesLatexmk = request.usesLatexmk && request.distribution.canRunLatexmk
        let run: ProcessRunner.Result
        if usesLatexmk {
            run = await pipeline.runLatexmk()
        } else {
            run = await pipeline.runEngineDirectly()
        }

        if let launchError = run.launchError {
            return failure(.couldNotStart(launchError), console: run.output)
        }
        if run.wasCancelled {
            return failure(.cancelled, console: run.output)
        }

        let logData = (try? Data(contentsOf: build.appending(path: "\(job).log"))) ?? Data()
        let log = String(decoding: logData, as: UTF8.self)
        var entries = LaTeXLogParser.parse(log)

        let pdfURL = build.appending(path: "\(job).pdf")
        let pdfDate = (try? fileManager.attributesOfItem(atPath: pdfURL.filePath)[.modificationDate]) as? Date
        let isNewPDF = pdfDate.map { $0 >= start.addingTimeInterval(-1) } ?? false
        let pdfData: Data? = isNewPDF ? (try? Data(contentsOf: pdfURL)) : nil

        if run.timedOut {
            entries.insert(LogEntry(severity: .error, message: String(localized: "Typesetting took too long and was stopped"), file: nil, line: nil), at: 0)
        } else if !run.succeeded && pdfData == nil && !entries.contains(where: { $0.severity == .error }) {
            entries.insert(LogEntry(severity: .error, message: String(localized: "TeX stopped without producing a PDF. See the log for details"), file: nil, line: nil), at: 0)
        }

        let hasErrors = entries.contains { $0.severity == .error }
        let status: TypesetResult.Status = run.timedOut ? .timedOut : (pdfData != nil && !hasErrors ? .succeeded : .failed)
        let synctex = pdfData == nil ? nil : SyncTeXData.load(buildDirectory: build, jobName: job, workingDirectory: sourceMap.workingDirectory)

        return TypesetResult(
            status: status,
            pdfURL: pdfData == nil ? nil : pdfURL,
            pdfData: pdfData,
            synctex: synctex,
            log: log,
            console: run.output,
            entries: entries,
            sourceMap: sourceMap,
            duration: Date().timeIntervalSince(start),
            usedLatexmk: usesLatexmk
        )
    }

    private static func encodedSource(_ request: TypesetRequest) -> Data {
        request.source.data(using: request.encoding) ?? Data(request.source.utf8)
    }
}

/// The commands that turn a source file into a PDF.
nonisolated private struct Pipeline {
    let request: TypesetRequest
    let sourceMap: SourceMap
    let environment: [String: String]

    private var build: URL { request.buildDirectory }
    private var job: String { request.jobName }

    private var commonOptions: [String] {
        var options = ["-interaction=nonstopmode", "-file-line-error", "-synctex=-1"]
        if request.allowsShellEscape {
            options.append("-shell-escape")
        }
        return options
    }

    /// latexmk runs BibTeX or Biber, makeindex and repeated passes as needed. `-f` keeps
    /// going after recoverable errors so references stay up to date while writing.
    func runLatexmk() async -> ProcessRunner.Result {
        guard let latexmk = request.distribution.executable("latexmk") else {
            return ProcessRunner.Result(launchError: String(localized: "latexmk was not found"))
        }
        let arguments = ["-f", request.engine.latexmkOption] + commonOptions + [
            "-outdir=\(build.filePath)",
            "-jobname=\(job)",
            sourceMap.mainInput.filePath,
        ]
        return await ProcessRunner.run(
            latexmk,
            arguments: arguments,
            in: sourceMap.workingDirectory,
            environment: environment,
            outputFile: build.appending(path: "\(job).console.txt")
        )
    }

    /// Without latexmk, TexLab runs the engine, then BibTeX or Biber and makeindex when the
    /// document uses them, then the engine again until cross-references settle.
    func runEngineDirectly() async -> ProcessRunner.Result {
        guard let engine = request.distribution.executable(request.engine.executableName) else {
            return ProcessRunner.Result(launchError: String(localized: "\(request.engine.displayName) was not found in the TeX distribution"))
        }
        var transcript = ""
        var result = await runEngine(engine, transcript: &transcript)
        guard result.launchError == nil, !result.wasCancelled, !result.timedOut else { return result }

        var needsMorePasses = false
        let fileManager = FileManager.default
        let aux = (try? String(contentsOf: build.appending(path: "\(job).aux"), encoding: .utf8)) ?? ""
        if fileManager.fileExists(atPath: build.appending(path: "\(job).bcf").filePath),
           let biber = request.distribution.executable("biber") {
            let step = await runTool(biber, arguments: ["--output-directory", build.filePath, job], in: sourceMap.workingDirectory, transcript: &transcript)
            if step.wasCancelled { return step }
            needsMorePasses = true
        } else if aux.contains("\\bibdata"), let bibtex = request.distribution.executable("bibtex") {
            let step = await runTool(bibtex, arguments: [job], in: build, transcript: &transcript)
            if step.wasCancelled { return step }
            needsMorePasses = true
        }
        if fileManager.fileExists(atPath: build.appending(path: "\(job).idx").filePath),
           let makeindex = request.distribution.executable("makeindex") {
            let step = await runTool(makeindex, arguments: ["\(job).idx"], in: build, transcript: &transcript)
            if step.wasCancelled { return step }
            needsMorePasses = true
        }

        var passes = 1
        while passes < 4 && (needsMorePasses || logAsksForRerun()) {
            needsMorePasses = passes < 2 && needsMorePasses
            result = await runEngine(engine, transcript: &transcript)
            passes += 1
            guard result.launchError == nil, !result.wasCancelled, !result.timedOut else { break }
        }
        result.output = transcript
        return result
    }

    private func runEngine(_ engine: URL, transcript: inout String) async -> ProcessRunner.Result {
        let arguments = commonOptions + ["-output-directory=\(build.filePath)", "-jobname=\(job)", sourceMap.mainInput.filePath]
        return await runTool(engine, arguments: arguments, in: sourceMap.workingDirectory, transcript: &transcript)
    }

    private func runTool(_ tool: URL, arguments: [String], in directory: URL, transcript: inout String) async -> ProcessRunner.Result {
        let result = await ProcessRunner.run(
            tool,
            arguments: arguments,
            in: directory,
            environment: environment,
            outputFile: build.appending(path: "\(job).console.txt")
        )
        transcript += "$ \(tool.lastPathComponent) \(arguments.joined(separator: " "))\n\(result.output)\n"
        return result
    }

    private func logAsksForRerun() -> Bool {
        guard let data = try? Data(contentsOf: build.appending(path: "\(job).log")) else { return false }
        let log = String(decoding: data, as: UTF8.self)
        return log.contains("Rerun to get") || log.contains("Please rerun") || log.contains("Rerun LaTeX")
    }
}
