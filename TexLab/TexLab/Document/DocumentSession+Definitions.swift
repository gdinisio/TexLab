//
//  DocumentSession+Definitions.swift
//  TexLab
//

import AppKit
import Foundation

/// Where Jump to Definition takes the editor.
enum DefinitionDestination {
    /// A range of this document.
    case here(NSRange)
    /// A line of another text file, opened in TexLab.
    case line(Int, file: URL)
    /// A file opened as a whole: a chapter, a bibliography, an image.
    case file(URL)
}

/// Jump to Definition, like Xcode's: from a reference to its `\label`, from a citation to
/// its bibliography entry, from `\input` or `\includegraphics` to the file, from a command
/// to its `\newcommand`, and between the `\begin` and `\end` of an environment.
extension DocumentSession {
    /// What Jump to Definition at `location` goes to, and where that is, if it can be
    /// found.
    func definition(at location: Int) -> (target: DefinitionTarget, destination: DefinitionDestination)? {
        let string = text as NSString
        guard let target = DefinitionFinder.target(at: location, in: string),
              let destination = destination(of: target, in: string) else { return nil }
        return (target, destination)
    }

    /// Jumps to the definition of what is at `location`. Returns false if there is nothing
    /// there with a definition TexLab can find.
    @discardableResult
    func jumpToDefinition(at location: Int) -> Bool {
        guard let destination = definition(at: location)?.destination else { return false }
        go(to: destination)
        return true
    }

    /// Navigate ▸ Jump to Definition: jumps from the insertion point, or beeps.
    func jumpToDefinitionAtSelection() {
        if !jumpToDefinition(at: editor.selectedRange.location) {
            NSSound.beep()
        }
    }

    func go(to destination: DefinitionDestination) {
        switch destination {
        case .here(let range):
            editor.reveal(location: range.location, length: range.length)
        case .line(let line, let url):
            open(url, line: line)
        case .file(let url):
            openProjectFile(url)
        }
    }

    private func destination(of target: DefinitionTarget, in string: NSString) -> DefinitionDestination? {
        switch target {
        case .label(let key):
            if let range = DefinitionFinder.labelRange(for: key, in: string) {
                return .here(range)
            }
            if let label = project?.labels.first(where: { $0.key == key }), let file = label.file {
                return .line(label.line, file: file)
            }
            return nil
        case .citation(let key):
            if let entry = project?.bibEntries.first(where: { $0.key == key }), let file = entry.file {
                return .line(entry.line, file: file)
            }
            return DefinitionFinder.bibItemRange(for: key, in: string).map { .here($0) }
        case .file(let path, let extensions):
            return resolveFile(path, extensions: extensions).map { .file($0) }
        case .command(let name):
            if let range = DefinitionFinder.commandDefinitionRange(for: name, in: string) {
                return .here(range)
            }
            if let definition = project?.commands.first(where: { $0.name == name }), let file = definition.file {
                return .line(definition.line, file: file)
            }
            return nil
        case .environment(_, let partner, _):
            return .here(partner)
        }
    }

    /// The file a path in the document names, the way TeX looks for it: relative to the
    /// main file's folder, trying the usual extensions when the path has none.
    private func resolveFile(_ path: String, extensions: [String]) -> URL? {
        let expanded = (path as NSString).expandingTildeInPath
        let base: URL
        if expanded.hasPrefix("/") {
            base = URL(filePath: expanded)
        } else if let folder = projectFolder {
            base = folder.appending(path: expanded)
        } else {
            return nil
        }
        var candidates = [base]
        if !extensions.contains(base.pathExtension.lowercased()) {
            candidates = extensions.map { base.appendingPathExtension($0) } + [base]
        }
        return candidates.first { url in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory) && !isDirectory.boolValue
        }
    }
}
