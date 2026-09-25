//
//  DocumentSession+Math.swift
//  TexLab
//

import AppKit
import Foundation

/// Live preview: finds the formulas and foldable environments in the source, and typesets
/// the formulas in the background so the editor can show them rendered.
extension DocumentSession {
    /// Whether the TeX distribution at each bin directory has the `preview` package.
    private static var previewPackageAvailability: [String: Bool] = [:]

    /// The most formulas typeset in one run, so the first images appear quickly in a
    /// long document; the rest follow in later runs.
    private static let mathBatchSize = 150

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
        editor.setVisualElements(VisualScanner.scan(string, range: whole, excluding: excluded))
        editor.setFoldableRegions(FoldScanner.scan(text))

        if !hasScannedFolds {
            hasScannedFolds = true
            let defaults = UserDefaults.standard
            if defaults.bool(forKey: SettingsKey.foldsPreambleOnOpen) {
                editor.foldPreamble(beepsIfMissing: false)
            }
            if defaults.bool(forKey: SettingsKey.foldsFloatsOnOpen) {
                editor.foldFloats()
            }
        }
        renderMath(for: regions)
    }

    /// Called when Render Math is turned on or off.
    func livePreviewSettingDidChange() {
        if AppSettings.rendersMathNow {
            renderMath(for: MathScanner.scan(text))
        } else {
            mathRenderTask?.cancel()
            needsAnotherMathRender = false
        }
    }

    // MARK: - Rendering formulas

    private func renderMath(for regions: [MathRegion]) {
        let defaults = UserDefaults.standard
        guard AppSettings.rendersMathNow, !regions.isEmpty,
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
        }

        var missing: [String: MathRegion] = [:]
        for region in regions where missing.count < Self.mathBatchSize {
            let key = region.key
            guard keepsOldImages || mathCache[key] == nil, !failedMathKeys.contains(key) else { continue }
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
        }

        // Render what changed meanwhile, and the next batch of a long document.
        needsAnotherMathRender = false
        renderMath(for: MathScanner.scan(text))
    }

    /// Drops images of formulas no longer in the document once the cache grows large,
    /// keeping recent ones so undo shows them straight away.
    private func pruneMathCache() {
        guard mathCache.count > 1000 else { return }
        let current = Set(MathScanner.scan(text).map(\.key))
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
            ?? (project?.mainFileIsDetected == true ? project?.mainFile : nil)
        if let url = rootURL, let data = try? Data(contentsOf: url), let rootText = try? TextDecoding.decode(data).text {
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
