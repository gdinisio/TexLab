//
//  BibliographyLog.swift
//  TexLab
//

import Foundation

/// What Biber and BibTeX reported, from their logs (`.blg`), and why a bibliography is
/// empty. TeX itself only asks for them to be run, so without this a Biber that isn't
/// installed, or a mistake in a `.bib` file, leaves every citation undefined with nothing
/// to say why.
nonisolated enum BibliographyLog {
    /// Issues for the bibliography of a typesetting run whose final TeX log is `log`, and
    /// whose console output — latexmk's, or TexLab's own transcript — is `console`.
    static func entries(log: String, console: String, buildDirectory: URL, jobName: String, distribution: TeXDistribution) -> [LogEntry] {
        // Only for a document with a bibliography: TeX names the .bbl it read or missed,
        // so an old .blg in the build folder doesn't speak for a document without one.
        guard log.contains("\(jobName).bbl") else { return [] }
        var entries: [LogEntry] = []
        if let data = try? Data(contentsOf: buildDirectory.appending(path: "\(jobName).blg")) {
            let text = String(decoding: data, as: UTF8.self)
            entries = text.contains("INFO - This is Biber") ? biberEntries(text) : bibTeXEntries(text)
            // BibTeX reports a bad name once for each time its style reads it.
            var seen: Set<LogEntry> = []
            entries = entries.filter { seen.insert($0).inserted }
        }
        guard !entries.contains(where: { $0.severity == .error }) else { return entries }
        // TeX still asks for the tool, and its log doesn't say what went wrong.
        for (tool, executable) in [("Biber", "biber"), ("BibTeX", "bibtex")] where log.contains("Please (re)run \(tool)") {
            if distribution.executable(executable) == nil {
                let message = String(localized: "The bibliography is empty because \(tool) isn’t installed in the TeX distribution at \(distribution.binDirectory.filePath). Install it with TeX Live Utility, or in Terminal with “sudo tlmgr install \(executable)”.")
                entries.insert(LogEntry(severity: .error, message: message, file: nil, line: nil), at: 0)
            } else if let reason = failure(of: executable, in: console) {
                // It couldn't start, or stopped before writing its log. Its path says which
                // program ran, in case another one answers to its name.
                let path = distribution.executable(executable)?.filePath ?? executable
                var message = String(localized: "The bibliography is empty because \(tool) (\(path)) couldn’t run: \(reason)")
                if reason.localizedCaseInsensitiveContains("Bad CPU type") {
                    message += " " + String(localized: "This \(tool) is built for Intel Macs; install Rosetta in Terminal with “softwareupdate --install-rosetta”.")
                }
                entries.insert(LogEntry(severity: .error, message: message, file: nil, line: nil, fix: .showOutput), at: 0)
            } else {
                let message = String(localized: "The bibliography may be empty or out of date: TeX still asks for \(tool) to be run.")
                entries.insert(LogEntry(severity: .warning, message: message, file: nil, line: nil, fix: .showOutput), at: 0)
            }
        }
        return entries
    }

    // MARK: - The console

    /// What `tool` printed as it failed, from latexmk's console — between "Running 'biber"
    /// and "Error return from 'biber" — or TexLab's own transcript, after "$ biber". A tool
    /// that couldn't start leaves only that: "biber: command not found", "Bad CPU type in
    /// executable".
    static func failure(of tool: String, in console: String) -> String? {
        let lines = console.components(separatedBy: "\n")
        if let errorIndex = lines.lastIndex(where: { $0.hasPrefix("Latexmk: Error return from '\(tool)") }) {
            let start = lines[..<errorIndex].lastIndex(where: { $0.hasPrefix("Running '\(tool)") }).map { $0 + 1 } ?? errorIndex
            return reason(in: lines[start..<errorIndex])
        }
        if let start = lines.lastIndex(where: { $0.hasPrefix("$ \(tool) ") }) {
            let end = lines[(start + 1)...].firstIndex(where: { $0.hasPrefix("$ ") }) ?? lines.endIndex
            return reason(in: lines[(start + 1)..<end])
        }
        return nil
    }

    /// The line that says what went wrong: the first that reads like an error, else the
    /// first of a usage message — which names its program there and lists options after
    /// it, so the end of the output says nothing — else the first the tool printed.
    private static func reason(in lines: ArraySlice<String>) -> String? {
        let said = lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("---") && !$0.contains("INFO - ") }
        guard let first = said.first else { return nil }
        func firstLine(containing words: [String]) -> String? {
            said.first { line in
                let lowercased = line.lowercased()
                return words.contains { lowercased.contains($0) }
            }
        }
        let line = firstLine(containing: failureWords) ?? firstLine(containing: ["usage:"]) ?? first
        return line.count > 300 ? String(line.prefix(300)) + "…" : line
    }

    private static let failureWords = [
        "error", "not found", "no such file", "cannot", "can't", "can’t", "could not",
        "couldn't", "failed", "bad cpu type", "permission denied", "killed", "abort",
    ]

    // MARK: - Biber

    private static let dataSourcePattern = try! NSRegularExpression(pattern: #"(?:Found \w+ data source|Looking for \w+ file) '([^']+)'"#)
    private static let subsystemPattern = try! NSRegularExpression(pattern: #"^BibTeX subsystem: .+?, line (\d+), (.+)$"#)
    private static let cannotFindPattern = try! NSRegularExpression(pattern: #"^Cannot find (?:file )?'([^']+)'!?$"#)

    /// Biber's errors and warnings. Its lines read `[time] Module.pm:line> LEVEL - message`;
    /// a mistake in a `.bib` file names a temporary copy, so it's put down to the data
    /// source Biber said it was reading.
    static func biberEntries(_ text: String) -> [LogEntry] {
        var entries: [LogEntry] = []
        var dataSource: String?
        for line in text.components(separatedBy: "\n") {
            if let source = firstCapture(dataSourcePattern, in: line) {
                dataSource = source
                continue
            }
            let severity: LogEntry.Severity
            let marker: Range<String.Index>
            if let range = line.range(of: "> ERROR - ") {
                severity = .error
                marker = range
            } else if let range = line.range(of: "> WARN - ") {
                severity = .warning
                marker = range
            } else {
                continue
            }
            let message = String(line[marker.upperBound...]).trimmingCharacters(in: .whitespaces)
            // LaTeX reports each undefined citation where it's cited.
            guard !message.hasPrefix("I didn't find a database entry") else { continue }
            if let match = captures(subsystemPattern, in: message) {
                var detail = match[2]
                if detail.hasPrefix("warning: ") {
                    detail.removeFirst("warning: ".count)
                }
                entries.append(LogEntry(severity: severity, message: String(localized: "Biber: \(detail)"), file: dataSource, line: Int(match[1])))
            } else if let name = firstCapture(cannotFindPattern, in: message) {
                let advice = name.lowercased().hasSuffix(".bib")
                    ? String(localized: "Biber can’t find “\(name)”. \\addbibresource takes its path from the main file’s folder.")
                    : String(localized: "Biber can’t find “\(name)”. \\addbibresource needs the file’s extension, as in \\addbibresource{\(name).bib}.")
                entries.append(LogEntry(severity: .error, message: advice, file: nil, line: nil))
            } else {
                entries.append(LogEntry(severity: severity, message: String(localized: "Biber: \(message)"), file: nil, line: nil))
            }
        }
        return entries
    }

    // MARK: - BibTeX

    private static let locationPattern = try! NSRegularExpression(pattern: #"^(.*)---line (\d+) of file (.+)$"#)

    /// BibTeX's errors and warnings. A mistake in a `.bib` file reads "message---line 7 of
    /// file refs.bib"; one found while running the style says "while executing" there, the
    /// message itself on the line before.
    static func bibTeXEntries(_ text: String) -> [LogEntry] {
        var entries: [LogEntry] = []
        var previous = ""
        var previousWasReported = false
        var couldNotOpenDatabase = false
        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            var reported = false
            defer {
                previous = line
                previousWasReported = reported
            }
            if let match = captures(locationPattern, in: line) {
                var message = match[1].trimmingCharacters(in: .whitespaces)
                if message.isEmpty || message == "while executing" {
                    guard !previousWasReported else { continue }
                    message = previous
                }
                guard !message.isEmpty else { continue }
                let file = match[3]
                let isDatabase = file.lowercased().hasSuffix(".bib")
                entries.append(LogEntry(severity: .error, message: String(localized: "BibTeX: \(message)"), file: isDatabase ? file : nil, line: isDatabase ? Int(match[2]) : nil))
                reported = true
            } else if line.hasPrefix("I couldn't open") || line.hasPrefix("I found no ") {
                let message = line.components(separatedBy: "---while reading").first ?? line
                if message.hasPrefix("I couldn't open database") {
                    couldNotOpenDatabase = true
                } else if message == "I found no database files" && couldNotOpenDatabase {
                    continue
                }
                // Nothing cited yet leaves the bibliography empty, but nothing is wrong.
                let severity: LogEntry.Severity = message.hasPrefix("I found no \\citation") ? .warning : .error
                entries.append(LogEntry(severity: severity, message: String(localized: "BibTeX: \(message)"), file: nil, line: nil))
                reported = true
            } else if line.hasPrefix("Warning--") {
                let message = String(line.dropFirst("Warning--".count))
                guard !message.hasPrefix("I didn't find a database entry") else { continue }
                entries.append(LogEntry(severity: .warning, message: String(localized: "BibTeX: \(message)"), file: nil, line: nil))
                reported = true
            }
        }
        return entries
    }

    // MARK: - Matching

    /// The pattern's capture groups in `line`, the whole match first.
    private static func captures(_ pattern: NSRegularExpression, in line: String) -> [String]? {
        let string = line as NSString
        guard let result = pattern.firstMatch(in: line, range: NSRange(location: 0, length: string.length)) else { return nil }
        return (0..<result.numberOfRanges).map { index in
            let range = result.range(at: index)
            return range.location == NSNotFound ? "" : string.substring(with: range)
        }
    }

    private static func firstCapture(_ pattern: NSRegularExpression, in line: String) -> String? {
        captures(pattern, in: line).map { $0[1] }
    }
}
