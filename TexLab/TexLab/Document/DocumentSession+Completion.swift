//
//  DocumentSession+Completion.swift
//  TexLab
//

import Foundation

/// What the completion list offers: the labels, bibliography entries, files, commands and
/// environments of the file on screen and the rest of its project.
extension DocumentSession {
    private static let bibliographyPattern = try! NSRegularExpression(
        pattern: #"\\(?:bibliography|addbibresource|addglobalbib)\s*(?:\[[^\]]*\])?\s*\{([^{}]+)\}"#
    )

    func completionSources() -> CompletionSources {
        var sources = CompletionSources()

        let ownLabels = ReferenceScanner.labels(in: text, file: nil).map { label in
            CompletionSources.Label(key: label.key, context: label.context, fileName: nil, kind: label.kind)
        }
        let projectLabels = (project?.labels ?? []).map { label in
            CompletionSources.Label(key: label.key, context: label.context, fileName: label.file?.lastPathComponent, kind: label.kind)
        }
        sources.labels = ownLabels + projectLabels

        sources.citations = (project?.bibEntries ?? []) + ReferenceScanner.bibItems(in: text) + bibliographiesOutsideProject()

        if let project {
            sources.files = project.tree.files.filter { !$0.isFolder }.map { file in
                CompletionSources.File(
                    path: PathUtilities.relativePath(of: file.url, from: project.folder),
                    pathExtension: file.url.pathExtension.lowercased()
                )
            }
        }

        let ownCommands = DefinitionFinder.commandDefinitions(in: text, file: nil)
        sources.commands = (ownCommands + (project?.commands ?? [])).map { command in
            CompletionSources.Command(name: command.name, argumentCount: command.argumentCount, fileName: command.file?.lastPathComponent)
        }
        sources.environments = DefinitionFinder.environmentDefinitions(in: text).union(project?.environments ?? [])
        return sources
    }

    /// Entries of bibliographies the document names that aren't in the project folder, such
    /// as `\bibliography{../shared/references}`.
    private func bibliographiesOutsideProject() -> [BibEntry] {
        guard let folder = projectFolder else { return [] }
        var texts = [text]
        if let main = project?.mainFile, !isMainFile, let mainText = textOfFile(main) {
            texts.append(mainText)
        }
        var entries: [BibEntry] = []
        var seen: Set<String> = []
        for source in texts {
            let string = source as NSString
            for match in Self.bibliographyPattern.matches(in: source, range: NSRange(location: 0, length: string.length)) {
                for name in string.substring(with: match.range(at: 1)).split(separator: ",") {
                    var path = name.trimmingCharacters(in: .whitespaces)
                    if !path.lowercased().hasSuffix(".bib") {
                        path += ".bib"
                    }
                    let url = path.hasPrefix("/") ? URL(filePath: path) : folder.appending(path: path)
                    let canonical = SourceMap.canonicalPath(url)
                    // Files in the project are in its index already.
                    guard seen.insert(canonical).inserted, SourceMap.relativePath(of: url, inside: folder) == nil,
                          let database = ProjectIndex.contents(of: url) else { continue }
                    entries += ReferenceScanner.bibEntries(in: database, file: url)
                }
            }
        }
        return entries
    }
}
