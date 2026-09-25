//
//  LaTeXLogParser.swift
//  TexLab
//

import Foundation

/// An error, warning or bad box reported in a TeX log.
nonisolated struct LogEntry: Hashable, Sendable {
    nonisolated enum Severity: Int, Comparable, Sendable {
        case badBox = 0
        case warning = 1
        case error = 2

        static func < (lhs: Severity, rhs: Severity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    var severity: Severity
    var message: String
    /// The file as the log names it: relative to the working directory, or absolute.
    var file: String?
    var line: Int?
}

/// Extracts errors, warnings and bad boxes from TeX logs.
///
/// TexLab typesets with `-file-line-error` and `max_print_line=10000`, so errors carry
/// their file and line and nothing is wrapped. Warnings and bad boxes are attributed to
/// the innermost file open at that point, tracked from the log's parentheses.
nonisolated enum LaTeXLogParser {
    static func parse(_ log: String) -> [LogEntry] {
        let lines = log.components(separatedBy: "\n").map { line in
            line.hasSuffix("\r") ? String(line.dropLast()) : line
        }
        var entries: [LogEntry] = []
        var seen = Set<LogEntry>()
        var files = FileStack()
        var index = 0
        var inBoxDetail = false

        func add(_ entry: LogEntry) {
            if seen.insert(entry).inserted {
                entries.append(entry)
            }
        }

        while index < lines.count {
            let line = lines[index]

            // The lines after a bad box show the box contents; they end at a blank line.
            if inBoxDetail {
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    inBoxDetail = false
                }
                index += 1
                continue
            }

            if let error = fileLineError(in: line) {
                if !isConsequentialNoise(error.message) {
                    let message = refineError(error.message, context: lines, after: index)
                    add(LogEntry(severity: .error, message: message, file: error.file, line: error.line))
                }
                index += 1
                continue
            }

            if line.hasPrefix("! ") {
                let message = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !isConsequentialNoise(message) {
                    add(LogEntry(
                        severity: .error,
                        message: refineError(message, context: lines, after: index),
                        file: files.current,
                        line: contextLineNumber(in: lines, after: index)
                    ))
                }
                index += 1
                continue
            }

            if let warning = warning(startingAt: index, in: lines) {
                if !isNoiseWarning(warning.message, source: warning.source) {
                    add(LogEntry(severity: .warning, message: warning.message, file: files.current, line: warning.line))
                }
                index = warning.nextIndex
                continue
            }

            if line.hasPrefix("Overfull \\") || line.hasPrefix("Underfull \\") {
                add(LogEntry(severity: .badBox, message: boxMessage(line), file: files.current, line: firstNumber(in: line, after: "line")))
                inBoxDetail = true
                index += 1
                continue
            }

            files.update(with: line)
            index += 1
        }
        return entries
    }

    // MARK: - Errors

    private nonisolated struct FileLineError {
        var file: String
        var line: Int
        var message: String
    }

    private static let fileLineErrorPattern = try! NSRegularExpression(pattern: #"^(.+?):(\d+): (.*)$"#)

    private static func fileLineError(in line: String) -> FileLineError? {
        let string = line as NSString
        guard let match = fileLineErrorPattern.firstMatch(in: line, range: NSRange(location: 0, length: string.length)) else {
            return nil
        }
        let file = string.substring(with: match.range(at: 1))
        guard FileStack.looksLikeFile(file), let number = Int(string.substring(with: match.range(at: 2))) else {
            return nil
        }
        return FileLineError(file: file, line: number, message: string.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespaces))
    }

    /// Errors that only restate an earlier one.
    private static func isConsequentialNoise(_ message: String) -> Bool {
        message.hasPrefix("==> Fatal error occurred")
            || message == "Emergency stop."
            || message.hasPrefix("Emergency stop")
    }

    private static let contextLinePattern = try! NSRegularExpression(pattern: #"^l\.(\d+) ?(.*)$"#)

    /// The `l.123 …` line TeX prints below an error.
    private static func contextLine(in lines: [String], after index: Int) -> (number: Int, text: String)? {
        let end = min(index + 12, lines.count)
        guard index + 1 < end else { return nil }
        for candidate in lines[(index + 1)..<end] {
            let string = candidate as NSString
            if let match = contextLinePattern.firstMatch(in: candidate, range: NSRange(location: 0, length: string.length)),
               let number = Int(string.substring(with: match.range(at: 1))) {
                return (number, string.substring(with: match.range(at: 2)))
            }
        }
        return nil
    }

    private static func contextLineNumber(in lines: [String], after index: Int) -> Int? {
        contextLine(in: lines, after: index)?.number
    }

    private static let commandPattern = try! NSRegularExpression(pattern: #"\\[A-Za-z@]+\*?|\\.$"#)

    private static func refineError(_ message: String, context lines: [String], after index: Int) -> String {
        var message = message
        let latexErrorPrefix = "LaTeX Error: "
        if message.hasPrefix(latexErrorPrefix) {
            message.removeFirst(latexErrorPrefix.count)
        }
        // Name the undefined command, which TeX only shows in the context line.
        if message.hasPrefix("Undefined control sequence"), let context = contextLine(in: lines, after: index) {
            let text = context.text as NSString
            let matches = commandPattern.matches(in: context.text, range: NSRange(location: 0, length: text.length))
            if let last = matches.last {
                message = "Undefined control sequence \(text.substring(with: last.range))"
            }
        }
        return trimTrailingPeriod(message)
    }

    // MARK: - Warnings

    private nonisolated struct Warning {
        var message: String
        var source: String
        var line: Int?
        var nextIndex: Int
    }

    private static let warningPattern = try! NSRegularExpression(
        pattern: #"^(LaTeX Font|LaTeX|Package ([^\s]+)|Class ([^\s]+)|Module ([^\s]+)|pdfTeX|XeTeX|LuaTeX) [Ww]arning(?: \([^)]*\))?: (.*)$"#
    )
    private static let continuationPattern = try! NSRegularExpression(pattern: #"^\(([^)\s]+)\)\s+(.*)$"#)
    private static let inputLinePattern = try! NSRegularExpression(pattern: #"\s*on input line (\d+)\.?"#)

    private static func warning(startingAt index: Int, in lines: [String]) -> Warning? {
        let line = lines[index]
        let string = line as NSString
        guard let match = warningPattern.firstMatch(in: line, range: NSRange(location: 0, length: string.length)) else {
            return nil
        }
        var source = string.substring(with: match.range(at: 1))
        for group in 2...4 where match.range(at: group).location != NSNotFound {
            source = string.substring(with: match.range(at: group))
        }
        let continuationLabel = source == "LaTeX Font" ? "Font" : source
        var message = string.substring(with: match.range(at: 5))

        // Package warnings continue on lines prefixed with "(package)".
        var next = index + 1
        while next < lines.count {
            let candidate = lines[next] as NSString
            guard let continuation = continuationPattern.firstMatch(in: lines[next], range: NSRange(location: 0, length: candidate.length)),
                  candidate.substring(with: continuation.range(at: 1)) == continuationLabel else { break }
            message += " " + candidate.substring(with: continuation.range(at: 2))
            next += 1
        }

        var lineNumber: Int?
        let messageString = message as NSString
        if let inputLine = inputLinePattern.firstMatch(in: message, range: NSRange(location: 0, length: messageString.length)) {
            lineNumber = Int(messageString.substring(with: inputLine.range(at: 1)))
            message = messageString.replacingCharacters(in: inputLine.range, with: "")
        }
        let prefix = source.hasPrefix("LaTeX") || source.hasSuffix("TeX") ? "" : "\(source): "
        return Warning(message: prefix + trimTrailingPeriod(message), source: source, line: lineNumber, nextIndex: next)
    }

    /// Summaries of warnings already listed individually, and rerun notices that the
    /// typesetting pipeline handles itself.
    private static func isNoiseWarning(_ message: String, source: String) -> Bool {
        source == "rerunfilecheck"
            || message.hasPrefix("There were undefined references")
            || message.hasPrefix("There were multiply-defined labels")
            || message.hasPrefix("Label(s) may have changed")
    }

    // MARK: - Bad boxes

    private static let boxPattern = try! NSRegularExpression(pattern: #"^((?:Over|Under)full \\[hv]box \([^)]*\))"#)

    private static func boxMessage(_ line: String) -> String {
        let string = line as NSString
        guard let match = boxPattern.firstMatch(in: line, range: NSRange(location: 0, length: string.length)) else {
            return line
        }
        return string.substring(with: match.range(at: 1))
    }

    private static func firstNumber(in line: String, after word: String) -> Int? {
        guard let range = line.range(of: word) else { return nil }
        let digits = line[range.upperBound...].drop { !$0.isNumber }.prefix { $0.isNumber }
        return Int(digits)
    }

    private static func trimTrailingPeriod(_ message: String) -> String {
        var message = message.trimmingCharacters(in: .whitespaces)
        if message.hasSuffix(".") && !message.hasSuffix("..") {
            message.removeLast()
        }
        return message
    }
}

/// Tracks which file TeX was reading, from the parentheses in its log.
nonisolated private struct FileStack {
    private var stack: [String?] = []

    var current: String? {
        stack.last { $0 != nil } ?? nil
    }

    mutating func update(with line: String) {
        var index = line.startIndex
        while index < line.endIndex {
            let character = line[index]
            if character == "(" {
                let start = line.index(after: index)
                var end = start
                while end < line.endIndex, !line[end].isWhitespace, line[end] != "(", line[end] != ")" {
                    end = line.index(after: end)
                }
                let token = String(line[start..<end])
                stack.append(Self.looksLikeFile(token) ? token : nil)
                index = end
                continue
            }
            if character == ")" && !stack.isEmpty {
                stack.removeLast()
            }
            index = line.index(after: index)
        }
    }

    private static let filePattern = try! NSRegularExpression(pattern: #"^[^\s]*\.[A-Za-z][A-Za-z0-9]{0,5}$"#)

    static func looksLikeFile(_ token: String) -> Bool {
        guard !token.isEmpty else { return false }
        if token.hasPrefix("/") || token.hasPrefix("./") || token.hasPrefix("../") {
            return true
        }
        let string = token as NSString
        return filePattern.firstMatch(in: token, range: NSRange(location: 0, length: string.length)) != nil
    }
}
