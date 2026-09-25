//
//  MathRenderer.swift
//  TexLab
//

import CoreGraphics
import Foundation
import PDFKit

/// A formula typeset for display in the editor.
nonisolated struct RenderedMath: Sendable {
    /// A one-page PDF of the formula, black on a transparent background.
    var pdfData: Data
    /// The page size in PDF points, for 10 pt text.
    var size: CGSize
    /// How far the formula reaches below the baseline, in PDF points.
    var depth: CGFloat
}

/// Typesets formulas with the user's TeX distribution, all in one run, so the editor can
/// show them exactly as they will look in the PDF — with the document's own macros.
///
/// Each formula becomes one page through the `preview` package (part of MacTeX), whose
/// `auctex` option reports every formula's height, depth and width in the log.
nonisolated enum MathRenderer {
    /// Whether the distribution has the `preview` package.
    static func isAvailable(in distribution: TeXDistribution) async -> Bool {
        guard let kpsewhich = distribution.executable("kpsewhich") else { return false }
        let output = FileManager.default.temporaryDirectory.appending(path: "TexLab-kpsewhich-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: output) }
        let result = await ProcessRunner.run(
            kpsewhich,
            arguments: ["preview.sty"],
            in: FileManager.default.temporaryDirectory,
            environment: ["PATH": distribution.searchPath, "HOME": NSHomeDirectory()],
            outputFile: output,
            timeout: 20
        )
        return result.succeeded && result.output.contains("preview.sty")
    }

    /// Renders `snippets` (keyed by `MathRegion.key`). Formulas TeX couldn't typeset are
    /// left out of the result. Files the preamble inputs are looked for in `sourceDirectory`.
    static func render(
        _ snippets: [String: MathRegion],
        preamble: String?,
        engine: TypesettingEngine,
        distribution: TeXDistribution,
        directory: URL,
        sourceDirectory: URL?
    ) async -> [String: RenderedMath] {
        guard !snippets.isEmpty, let executable = distribution.executable(engine.executableName) else { return [:] }
        let ordered = snippets.sorted { $0.key < $1.key }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Try the document's own preamble first, so its macros and packages work. If it
        // doesn't typeset at all (a preamble written for another class, say), fall back to
        // standard math packages.
        let preambles = [preamble.map(sanitized), minimalPreamble].compactMap { $0 }
        for candidate in preambles {
            if Task.isCancelled { return [:] }
            if let results = await run(ordered, preamble: candidate, executable: executable, distribution: distribution, directory: directory, sourceDirectory: sourceDirectory) {
                return results
            }
        }
        return [:]
    }

    // MARK: - Running TeX

    private static let minimalPreamble = "\\usepackage{amsmath}\n\\usepackage{amssymb}\n"

    private static func run(
        _ snippets: [(key: String, value: MathRegion)],
        preamble: String,
        executable: URL,
        distribution: TeXDistribution,
        directory: URL,
        sourceDirectory: URL?
    ) async -> [String: RenderedMath]? {
        var source = "\\documentclass{article}\n" + preamble + "\n"
        source += "\\usepackage[active,tightpage,auctex]{preview}\n\\setlength\\PreviewBorder{1pt}\n\\pagestyle{empty}\n\\begin{document}\n"
        for (_, region) in snippets {
            let math = region.isDisplay ? "\\displaystyle " + region.snippet : region.snippet
            source += "\\begin{preview}$" + math + "$\\end{preview}\n"
        }
        source += "\\end{document}\n"

        let texFile = directory.appending(path: "math.tex")
        do {
            try Data(source.utf8).write(to: texFile)
        } catch {
            return nil
        }
        for name in ["math.pdf", "math.log", "math.aux"] {
            try? FileManager.default.removeItem(at: directory.appending(path: name))
        }

        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = distribution.searchPath
        environment["max_print_line"] = "10000"
        if let sourceDirectory {
            // The trailing separator keeps the distribution's own search path.
            environment["TEXINPUTS"] = sourceDirectory.filePath + ":"
        }
        let result = await ProcessRunner.run(
            executable,
            arguments: ["-interaction=nonstopmode", "-file-line-error", "-output-directory=\(directory.filePath)", texFile.filePath],
            in: directory,
            environment: environment,
            outputFile: directory.appending(path: "math.console.txt"),
            timeout: 60
        )
        guard result.launchError == nil, !result.wasCancelled, !result.timedOut,
              let document = PDFDocument(url: directory.appending(path: "math.pdf")),
              document.pageCount == snippets.count else { return nil }

        let logData = (try? Data(contentsOf: directory.appending(path: "math.log"))) ?? Data()
        let report = PreviewReport(log: String(decoding: logData, as: UTF8.self))

        var rendered: [String: RenderedMath] = [:]
        for (index, snippet) in snippets.enumerated() {
            let number = index + 1
            guard !report.failedSnippets.contains(number),
                  let page = document.page(at: index),
                  let data = page.dataRepresentation else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let depth = report.depths[number].map { $0 + report.bottomBorder } ?? report.bottomBorder
            rendered[snippet.key] = RenderedMath(pdfData: data, size: bounds.size, depth: depth)
        }
        return rendered
    }

    /// The document preamble without its class, which the renderer supplies.
    private static func sanitized(_ preamble: String) -> String {
        let string = preamble as NSString
        let classPattern = try! NSRegularExpression(pattern: #"\\documentclass\s*(?:\[[^\]]*\])?\s*\{[^{}]*\}"#)
        var result = classPattern.stringByReplacingMatches(in: preamble, range: NSRange(location: 0, length: string.length), withTemplate: "")
        if !result.contains("amsmath") && !result.contains("mathtools") {
            result += "\n\\usepackage{amsmath}"
        }
        if !result.contains("amssymb") && !result.contains("unicode-math") && !result.contains("amsfonts") {
            result += "\n\\usepackage{amssymb}"
        }
        return result
    }
}

/// What the `preview` package reports in the log.
nonisolated private struct PreviewReport {
    /// Depth below the baseline of each formula (1-based), in PDF points.
    var depths: [Int: CGFloat] = [:]
    /// Formulas with errors.
    var failedSnippets: Set<Int> = []
    /// The margin `tightpage` adds below each formula, in PDF points.
    var bottomBorder: CGFloat = 1

    private static let scaledPointsPerPoint = 65781.76
    private static let endedPattern = try! NSRegularExpression(pattern: #"Preview: Snippet (\d+) ended\.\((-?\d+)\+(-?\d+)x(-?\d+)\)"#)
    private static let startedPattern = try! NSRegularExpression(pattern: #"Preview: Snippet (\d+) started"#)
    private static let tightpagePattern = try! NSRegularExpression(pattern: #"Preview: Tightpage (-?\d+) (-?\d+) (-?\d+) (-?\d+)"#)
    private static let errorPattern = try! NSRegularExpression(pattern: #"^(?:\S+:\d+: |! )(.*)$"#)

    init(log: String) {
        var current: Int?
        for line in log.components(separatedBy: "\n") {
            let string = line as NSString
            let range = NSRange(location: 0, length: string.length)
            if let match = Self.tightpagePattern.firstMatch(in: line, range: range),
               let bottom = Double(string.substring(with: match.range(at: 2))) {
                bottomBorder = CGFloat(-bottom / Self.scaledPointsPerPoint)
            } else if let match = Self.startedPattern.firstMatch(in: line, range: range) {
                current = Int(string.substring(with: match.range(at: 1)))
            } else if let match = Self.endedPattern.firstMatch(in: line, range: range),
                      let number = Int(string.substring(with: match.range(at: 1))),
                      let depth = Double(string.substring(with: match.range(at: 3))) {
                depths[number] = CGFloat(depth / Self.scaledPointsPerPoint)
                current = nil
            } else if let current, let match = Self.errorPattern.firstMatch(in: line, range: range),
                      !string.substring(with: match.range(at: 1)).hasPrefix("Preview:") {
                failedSnippets.insert(current)
            }
        }
    }
}
