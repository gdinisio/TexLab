//
//  TypesetModels.swift
//  TexLab
//

import Foundation

/// A problem found while typesetting, attached to a source file and line when known.
nonisolated struct Issue: Identifiable, Hashable, Sendable {
    let id: Int
    var severity: LogEntry.Severity
    var message: String
    var source: SourceFile?
    var line: Int?

    /// The file name shown next to the message.
    var fileName: String? {
        switch source {
        case .file(let url): url.lastPathComponent
        case .currentDocument, nil: nil
        }
    }

    /// The message with TeX's `quotes' shown as typographic quotes.
    var displayMessage: String {
        message
            .replacingOccurrences(of: "`", with: "\u{2018}")
            .replacingOccurrences(of: "'", with: "\u{2019}")
    }

    var systemImage: String {
        switch severity {
        case .error: "xmark.octagon.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .badBox: "rectangle.badge.xmark"
        }
    }
}

/// Where typesetting stands, as shown in the window subtitle and the preview.
nonisolated enum TypesetStatus: Equatable, Sendable {
    /// The document hasn't been typeset in this window yet.
    case idle
    case running
    case succeeded(pages: Int)
    /// TeX reported errors. A PDF may still have been produced.
    case failed(errors: Int, producedPDF: Bool)
    case cancelled
    case timedOut
    /// No TeX distribution was found. `sandboxed` is true when the App Sandbox is the
    /// likely reason.
    case texNotFound(sandboxed: Bool)
    case couldNotStart(String)

    var summary: String {
        switch self {
        case .idle:
            ""
        case .running:
            String(localized: "Typesetting…")
        case .succeeded(let pages):
            pages == 1
                ? String(localized: "Typeset · 1 page")
                : String(localized: "Typeset · \(pages) pages")
        case .failed(let errors, true):
            errors == 1
                ? String(localized: "Typeset with 1 error")
                : String(localized: "Typeset with \(errors) errors")
        case .failed:
            String(localized: "Typesetting Failed")
        case .cancelled:
            String(localized: "Typesetting Stopped")
        case .timedOut:
            String(localized: "Typesetting Timed Out")
        case .texNotFound:
            String(localized: "TeX Not Found")
        case .couldNotStart:
            String(localized: "Couldn’t Typeset")
        }
    }
}

/// Stable names derived from a document for typesetting.
nonisolated enum BuildNaming {
    /// A TeX-safe job name: letters, digits, hyphens and underscores only.
    static func jobName(for displayName: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        let mapped = String(displayName.map { allowed.contains($0) ? $0 : "_" })
        return mapped.trimmingCharacters(in: CharacterSet(charactersIn: "_")).isEmpty ? "document" : mapped
    }

    /// A short, stable folder name for a file path (64-bit FNV-1a).
    static func buildKey(for path: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in path.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return String(hash, radix: 16)
    }

    /// The folder holding TexLab's typesetting output.
    static var buildRoot: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return caches
            .appending(path: Bundle.main.bundleIdentifier ?? "TexLab", directoryHint: .isDirectory)
            .appending(path: "Typeset", directoryHint: .isDirectory)
    }

    /// Whether TexLab runs in the App Sandbox, which blocks access to TeX installations.
    static var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }
}
