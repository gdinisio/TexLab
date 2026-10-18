//
//  DocumentSession+Math.swift
//  TexLab
//

import AppKit
import Foundation

/// Live preview: finds the formulas, drawings, tables and foldable environments in the
/// source, and typesets the formulas, drawings and tables in the background so the editor
/// can show them rendered.
extension DocumentSession {
    /// Whether the TeX distribution at each bin directory has the `preview` package.
    private static var previewPackageAvailability: [String: Bool] = [:]

    /// The most formulas typeset in one run, so the first images appear quickly in a
    /// long document; the rest follow in later runs.
    private static let mathBatchSize = 150
    /// The most drawings and tables typeset in one run, which take longer than formulas.
    private static let blockBatchSize = 24

    /// Called when the editor attaches, before the first analysis.
    func configureLivePreview() {
        editor.setImageResolver { [weak self] path in
            self?.resolveGraphicsPath(path)
        }
    }

    /// Updates formulas and foldable environments from the current text.
    func updateLivePreview() {
        let regions = MathScanner.scan(text)
        editor.setMathRegions(regions)
        let string = text as NSString
        let whole = NSRange(location: 0, length: string.length)
        // Comments and verbatim text stay as source, like math.
        let scan = LaTeXTokenizer.scan(string, range: whole)
        let excluded = scan.regions.map(\.range) + scan.tokens.filter { $0.kind == .comment || $0.kind == .verbatim }.map(\.range)
        let elements = VisualScanner.scan(string, range: whole, excluding: excluded)
        updateInclusionPreviews(for: VisualScanner.inclusionPaths(in: elements))
        editor.setVisualElements(elements)
        editor.setFoldableRegions(FoldScanner.scan(text))

        if !hasScannedFolds {
            hasScannedFolds = true
            let defaults = UserDefaults.standard
            let visualCollapses = effectiveEditorMode == .visual && defaults.bool(forKey: SettingsKey.collapsesPreambleInVisual)
            if defaults.bool(forKey: SettingsKey.foldsPreambleOnOpen) || visualCollapses {
                editor.foldPreamble(beepsIfMissing: false)
            }
            if defaults.bool(forKey: SettingsKey.foldsFloatsOnOpen) {
                editor.foldFloats()
            }
        }
        renderMath(for: regions + includedBlocks)
    }

    /// Called when Render Math is turned on or off.
    func livePreviewSettingDidChange() {
        if rendersMathNow {
            renderMath(for: MathScanner.scan(text) + includedBlocks)
        } else {
            mathRenderTask?.cancel()
            needsAnotherMathRender = false
        }
    }

    // MARK: - Rendering formulas

    private func renderMath(for regions: [MathRegion]) {
        let defaults = UserDefaults.standard
        guard rendersMathNow, !regions.isEmpty,
              let distribution = TeXDistribution.locate(customPath: defaults.string(forKey: SettingsKey.texBinPath) ?? "") else { return }
        guard mathRenderTask == nil else {
            needsAnotherMathRender = true
            return
        }

        let (preamble, engine) = mathPreambleAndEngine()
        guard distribution.supports(engine) else { return }

        // Formulas depend on the document's macros, so a different preamble means
        // typesetting them again. The old images stay on screen until the new ones arrive.
        let signature = engine.rawValue + "\n" + (preamble ?? "")
        var keepsOldImages = false
        if signature != mathCacheSignature {
            keepsOldImages = !mathCache.isEmpty
            mathCacheSignature = signature
            failedMathKeys = []
            editor.setFailedRenderKeys([])
        }

        var missing: [String: MathRegion] = [:]
        var blockCount = 0
        for region in regions where missing.count < Self.mathBatchSize {
            let key = region.key
            guard keepsOldImages || mathCache[key] == nil, !failedMathKeys.contains(key) else { continue }
            if region.isBlock {
                guard blockCount < Self.blockBatchSize else { continue }
                blockCount += 1
            }
            missing[key] = region
        }
        guard !missing.isEmpty else {
            editor.setRenderedMath(mathCache)
            return
        }

        let binPath = distribution.binDirectory.filePath
        let knownAvailability = Self.previewPackageAvailability[binPath]
        let identity = fileURL.map(SourceMap.canonicalPath) ?? sessionID.uuidString
        let sourceDirectory = mathSourceDirectory
        let directory = BuildNaming.buildRoot.appending(path: "Math-" + BuildNaming.buildKey(for: identity), directoryHint: .isDirectory)

        mathRenderTask = Task { [weak self] in
            let work = Task.detached(priority: .utility) { () -> (available: Bool, results: [String: RenderedMath]) in
                let available: Bool
                if let knownAvailability {
                    available = knownAvailability
                } else {
                    available = await MathRenderer.isAvailable(in: distribution)
                }
                guard available else { return (false, [:]) }
                let results = await MathRenderer.render(missing, preamble: preamble, engine: engine, distribution: distribution, directory: directory, sourceDirectory: sourceDirectory)
                return (true, results)
            }
            let outcome = await withTaskCancellationHandler {
                await work.value
            } onCancel: {
                work.cancel()
            }
            self?.finishRenderingMath(
                outcome.results,
                requested: Set(missing.keys),
                signature: signature,
                replacesCache: keepsOldImages,
                binPath: binPath,
                previewAvailable: outcome.available,
                wasCancelled: Task.isCancelled
            )
        }
    }

    private func finishRenderingMath(
        _ results: [String: RenderedMath],
        requested: Set<String>,
        signature: String,
        replacesCache: Bool,
        binPath: String,
        previewAvailable: Bool,
        wasCancelled: Bool
    ) {
        mathRenderTask = nil
        Self.previewPackageAvailability[binPath] = previewAvailable
        guard !wasCancelled, previewAvailable else {
            needsAnotherMathRender = false
            return
        }

        if signature == mathCacheSignature {
            if replacesCache {
                mathCache = [:]
            }
            for (key, rendered) in results {
                if let image = MathImage(rendered) {
                    mathCache[key] = image
                }
            }
            // Don't try formulas TeX couldn't typeset again until the preamble changes.
            failedMathKeys.formUnion(requested.subtracting(results.keys))
            pruneMathCache()
            editor.setRenderedMath(mathCache)
            editor.setFailedRenderKeys(failedMathKeys)
        }

        // Render what changed meanwhile, and the next batch of a long document.
        needsAnotherMathRender = false
        renderMath(for: MathScanner.scan(text) + includedBlocks)
    }

    /// Drops images of formulas no longer in the document once the cache grows large,
    /// keeping recent ones so undo shows them straight away.
    private func pruneMathCache() {
        guard mathCache.count > 1000 else { return }
        let current = Set((MathScanner.scan(text) + includedBlocks).map(\.key))
        mathCache = mathCache.filter { current.contains($0.key) }
    }

    /// The preamble the formulas are typeset with: the document's own, or the root file's
    /// when a `% !TEX root` comment names one.
    private func mathPreambleAndEngine() -> (preamble: String?, engine: TypesettingEngine) {
        let magic = MagicComments(text: text)
        var engine = magic.program ?? defaultEngine
        if let preamble = Self.preamble(of: text) {
            return (preamble, engine)
        }
        // A part of a project uses its main file's preamble.
        let rootURL = magic.root.flatMap { documentDirectory?.appending(path: $0).standardizedFileURL }
            ?? project?.mainFile.flatMap { main in
                fileURL.map(SourceMap.canonicalPath) == SourceMap.canonicalPath(main) ? nil : main
            }
        if let url = rootURL, let rootText = textOfFile(url) {
            if let rootEngine = MagicComments(text: rootText).program {
                engine = rootEngine
            }
            return (Self.preamble(of: rootText), engine)
        }
        return (nil, engine)
    }

    private static func preamble(of text: String) -> String? {
        let string = text as NSString
        let begin = string.range(of: "\\begin{document}")
        guard begin.location != NSNotFound else { return nil }
        return string.substring(to: begin.location)
    }

    // MARK: - Included files

    /// The drawings and tables of the files the shown file includes, typeset with its
    /// formulas.
    private var includedBlocks: [MathRegion] {
        inclusionPreviews.values.compactMap(\.block)
    }

    /// Works out what each `\input` of the shown file shows: the part's heading, or the
    /// figure, drawing or table the included file holds.
    private func updateInclusionPreviews(for paths: Set<String>) {
        var previews: [String: InclusionPreview] = [:]
        for path in paths {
            previews[path] = inclusionPreview(for: path)
        }
        guard previews != inclusionPreviews else { return }
        inclusionPreviews = previews
        editor.setInclusionPreviews(previews)
    }

    private func inclusionPreview(for path: String) -> InclusionPreview {
        guard let url = includedFileURL(path) else { return .missing(path) }
        // An open file as it is here, unsaved changes included.
        if let text = textOfOpenFile(url) {
            return InclusionPreview.make(for: text, path: path)
        }
        let key = SourceMap.canonicalPath(url)
        let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        if let cached = inclusionPreviewCache[key], cached.date == date, cached.path == path {
            return cached.preview
        }
        let preview = ProjectIndex.contents(of: url).map { InclusionPreview.make(for: $0, path: path) } ?? .missing(path)
        inclusionPreviewCache[key] = (date, path, preview)
        return preview
    }

    /// The file an `\input` names, as TeX finds it: from the main file's folder, with .tex
    /// added unless the name has it.
    private func includedFileURL(_ path: String) -> URL? {
        guard let directory = mathSourceDirectory else { return nil }
        let base = path.hasPrefix("/") ? URL(filePath: path) : directory.appending(path: path)
        let candidates = base.pathExtension.lowercased() == "tex" ? [base] : [base.appendingPathExtension("tex"), base]
        return candidates.first { url in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.filePath, isDirectory: &isDirectory) && !isDirectory.boolValue
        }
    }

    // MARK: - Figures

    /// The folder TeX resolves relative paths against: the root file's, or the document's.
    private var mathSourceDirectory: URL? {
        if let root = MagicComments(text: text).root, let directory = documentDirectory {
            return directory.appending(path: root).standardizedFileURL.deletingLastPathComponent()
        }
        return projectFolder
    }

    /// The file an `\includegraphics` path refers to, for the thumbnail of a collapsed
    /// figure. TeX tries these extensions in this order when a path has none.
    private func resolveGraphicsPath(_ path: String) -> URL? {
        guard let directory = mathSourceDirectory else { return nil }
        let base = path.hasPrefix("/") ? URL(filePath: path) : directory.appending(path: path)
        let candidates = base.pathExtension.isEmpty
            ? ["pdf", "png", "jpg", "jpeg"].map { base.appendingPathExtension($0) }
            : [base]
        return candidates.first { FileManager.default.fileExists(atPath: $0.filePath) }
    }
}

// MARK: - Editor mode

extension DocumentSession {
    /// Whether formulas, drawings and tables are typeset for the editor: for the Visual
    /// editor to show them, when Settings allow it, or for the preview beside the source
    /// being edited, in either editor.
    var rendersMathNow: Bool {
        let defaults = UserDefaults.standard
        return (effectiveEditorMode == .visual && defaults.bool(forKey: SettingsKey.rendersMathInEditor))
            || defaults.bool(forKey: SettingsKey.previewsWhileEditing)
    }

    /// Switches between the Code and Visual editors.
    func toggleEditorMode() {
        setEditorMode(editorMode == .code ? .visual : .code)
    }

    /// The Visual editor keeps the preamble out of the way, as Overleaf's does; the Code
    /// editor shows everything.
    func editorModeDidChange() {
        if effectiveEditorMode == .visual {
            if UserDefaults.standard.bool(forKey: SettingsKey.collapsesPreambleInVisual) {
                editor.foldPreamble(beepsIfMissing: false)
            }
        } else {
            editor.unfoldPreamble()
        }
        livePreviewSettingDidChange()
    }
}
