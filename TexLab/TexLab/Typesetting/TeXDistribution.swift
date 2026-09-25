//
//  TeXDistribution.swift
//  TexLab
//

import Foundation

/// An installed TeX distribution, such as MacTeX, BasicTeX or a Homebrew TeX Live.
///
/// Apps opened from the Finder don't inherit the shell's `PATH`, so TexLab looks for TeX
/// where Mac distributions install it.
nonisolated struct TeXDistribution: Hashable, Sendable {
    /// The folder containing `pdflatex` and friends.
    let binDirectory: URL

    func executable(_ name: String) -> URL? {
        let url = binDirectory.appending(path: name)
        return FileManager.default.isExecutableFile(atPath: url.filePath) ? url : nil
    }

    func supports(_ engine: TypesettingEngine) -> Bool {
        executable(engine.executableName) != nil
    }

    /// latexmk is a Perl script, so it also needs Perl.
    var canRunLatexmk: Bool {
        guard executable("latexmk") != nil else { return false }
        let perlLocations = ["/usr/bin/perl", "/opt/homebrew/bin/perl", "/usr/local/bin/perl", binDirectory.appending(path: "perl").filePath]
        return perlLocations.contains { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// The `PATH` for tools run from this distribution.
    var searchPath: String {
        ([binDirectory.filePath] + Self.systemPaths).joined(separator: ":")
    }

    private static let systemPaths = ["/usr/bin", "/bin", "/usr/sbin", "/sbin", "/opt/homebrew/bin", "/usr/local/bin"]

    // MARK: - Discovery

    /// Finds a distribution, preferring `customPath` (from Settings) when it contains one.
    static func locate(customPath: String) -> TeXDistribution? {
        for directory in candidateDirectories(customPath: customPath) {
            let distribution = TeXDistribution(binDirectory: URL(filePath: directory, directoryHint: .isDirectory))
            if TypesettingEngine.allCases.contains(where: distribution.supports) {
                return distribution
            }
        }
        return nil
    }

    private static func candidateDirectories(customPath: String) -> [String] {
        var directories: [String] = []
        let custom = (customPath.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).expandingTildeInPath
        if !custom.isEmpty {
            directories.append(custom)
        }
        directories.append("/Library/TeX/texbin")
        directories += texLiveDirectories()
        directories += ["/opt/homebrew/bin", "/usr/local/bin", "/opt/local/bin"]
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            directories += path.split(separator: ":").map(String.init)
        }
        var seen = Set<String>()
        return directories.filter { seen.insert($0).inserted }
    }

    /// `/usr/local/texlive/<year>/bin/<platform>`, newest year first.
    private static func texLiveDirectories() -> [String] {
        let root = "/usr/local/texlive"
        let fileManager = FileManager.default
        guard let years = try? fileManager.contentsOfDirectory(atPath: root) else { return [] }
        return years
            .filter { $0.allSatisfy(\.isNumber) }
            .sorted(by: >)
            .flatMap { year -> [String] in
                let bin = "\(root)/\(year)/bin"
                let platforms = (try? fileManager.contentsOfDirectory(atPath: bin)) ?? []
                return platforms.sorted().map { "\(bin)/\($0)" }
            }
    }

    /// The version line printed by the distribution's pdfTeX, for Settings.
    func versionDescription() async -> String? {
        guard let engine = TypesettingEngine.allCases.lazy.compactMap({ self.executable($0.executableName) }).first else {
            return nil
        }
        let output = FileManager.default.temporaryDirectory.appending(path: "TexLab-version-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: output) }
        let result = await ProcessRunner.run(
            engine,
            arguments: ["--version"],
            in: FileManager.default.temporaryDirectory,
            environment: ["PATH": searchPath],
            outputFile: output,
            timeout: 20
        )
        return result.output.split(separator: "\n").first.map(String.init)
    }
}
