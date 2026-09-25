//
//  PathUtilities.swift
//  TexLab
//

import Foundation

extension URL {
    /// The file system path, without percent encoding.
    nonisolated var filePath: String {
        path(percentEncoded: false)
    }
}

nonisolated enum PathUtilities {
    /// The path of `url` relative to `directory`, using `../` where needed, as LaTeX
    /// expects in `\input` and `\includegraphics`. Falls back to the absolute path when the
    /// two share nothing but the root.
    static func relativePath(of url: URL, from directory: URL) -> String {
        let target = url.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        let base = directory.standardizedFileURL.resolvingSymlinksInPath().pathComponents
        var shared = 0
        while shared < min(target.count, base.count) && target[shared] == base[shared] {
            shared += 1
        }
        guard shared > 1 else { return url.filePath }
        let ups = Array(repeating: "..", count: base.count - shared)
        return (ups + target[shared...]).joined(separator: "/")
    }
}
