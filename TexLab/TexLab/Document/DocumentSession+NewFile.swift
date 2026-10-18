//
//  DocumentSession+NewFile.swift
//  TexLab
//

import AppKit
import Foundation

/// What New File in Project makes, as the sheet gathers it.
struct NewFileRequest {
    var kind: NewFileKind
    /// The name without its extension, or with one for an empty file.
    var name: String
    var folder: URL
    /// Whether to use the file: from the main file, or where you are writing.
    var usesFile: Bool
    var caption = ""
    /// Pictures from the Mac: a figure's picture, or the images to add.
    var images: [URL] = []
    var rows = 3
    var columns = 3
    var template: DocumentTemplate = .article
}

/// New File in Project: parts of the document, figures, tables and drawings, images from
/// the Mac, whole documents, bibliographies and packages — each set up to be used, so a
/// figure is in a figure environment, captioned, labelled and input where you're writing.
extension DocumentSession {
    /// Whether figures and tables can go in where you're writing: the editor shows a LaTeX
    /// file.
    var acceptsFloats: Bool {
        editor.isAvailable && supportsVisualEditor
    }

    /// Makes what `request` describes. A new file opens once made; images stay where you
    /// are, with their figures inserted. Returns the file made, if one was.
    @discardableResult
    func createProjectFile(_ request: NewFileRequest) throws -> URL? {
        if request.kind == .image {
            try addImages(request.images, to: request.folder, insertingFigures: request.usesFile)
            return nil
        }
        let url = try newFileURL(for: request)
        let mainFile = project?.mainFile
        var options = NewFileOptions(name: url.deletingPathExtension().lastPathComponent)
        if [.chapter, .figure, .table, .drawing].contains(request.kind), let mainFile {
            // Typesetting the file typesets the whole project.
            options.rootPath = PathUtilities.relativePath(of: mainFile, from: request.folder)
        }
        options.mainText = (mainFile ?? fileURL).flatMap(textOfFile)
        options.caption = request.caption
        options.rows = request.rows
        options.columns = request.columns
        options.template = request.template
        if request.kind == .figure, let image = request.images.first {
            let picture = try projectCopy(of: image, in: request.folder)
            options.imagePath = graphicsPath(of: picture)
        }
        try Data(request.kind.contents(options).utf8).write(to: url, options: .withoutOverwriting)

        if request.usesFile {
            switch request.kind.reference {
            case .mainFile where request.kind != .empty || ProjectFileKind(url: url, isDirectory: false) == .latex:
                addReferenceInMainFile(to: url, kind: request.kind)
            case .insertionPoint where acceptsFloats:
                let path = graphicsPath(of: url)
                ensurePackages(request.kind.packages)
                insertBlock("\\input{\(path.dropLast(url.pathExtension.count + 1))}", at: floatInsertionLocation, actionName: String(localized: "Insert \(request.kind.title)"))
            default:
                break
            }
        }
        refreshProject()
        openProjectFile(url)
        return url
    }

    /// The new file's place, which mustn't be taken. An empty file keeps an extension it was
    /// given; everything else has its kind's.
    private func newFileURL(for request: NewFileRequest) throws -> URL {
        var url = request.folder.appending(path: request.name)
        if request.kind != .empty || url.pathExtension.isEmpty {
            url = url.appendingPathExtension(request.kind.fileExtension)
        }
        guard !FileManager.default.fileExists(atPath: url.filePath) else {
            throw ProjectError.fileExists(url.lastPathComponent)
        }
        return url
    }

    // MARK: - Images

    /// Adds pictures to the project — copied into `folder` unless they're in the project
    /// already — and, if asked, a figure for each where you're writing, with the insertion
    /// point in the first caption.
    func addImages(_ images: [URL], to folder: URL, insertingFigures: Bool) throws {
        let pictures = try images.map { try projectCopy(of: $0, in: folder) }
        refreshProject()
        guard insertingFigures, acceptsFloats, !pictures.isEmpty else { return }
        ensurePackages(["graphicx"])
        let figures = pictures.map { picture in
            NewFileKind.figureText(imagePath: graphicsPath(of: picture), caption: "", label: figureLabel(for: picture))
        }
        insertFigures(figures)
    }

    /// A picture inside the project: as it is if the project has it, or else copied into
    /// `folder`, numbered if the name is taken, as the Finder does.
    func projectCopy(of image: URL, in folder: URL) throws -> URL {
        let isAccessing = image.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                image.stopAccessingSecurityScopedResource()
            }
        }
        if let projectFolder, SourceMap.relativePath(of: image, inside: projectFolder) != nil {
            return image
        }
        let base = image.deletingPathExtension().lastPathComponent
        var destination = folder.appending(path: image.lastPathComponent)
        var number = 2
        while FileManager.default.fileExists(atPath: destination.filePath) {
            destination = folder.appending(path: "\(base) \(number)").appendingPathExtension(image.pathExtension)
            number += 1
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: image, to: destination)
        return destination
    }

    /// The project's folder for pictures: a Figures, Images or Graphics folder if it has
    /// one, or else the project folder.
    var figuresFolder: URL? {
        guard let project else { return projectFolder }
        let folders = (project.tree.children ?? []).filter(\.isFolder)
        for name in ["figures", "images", "graphics", "img", "pictures"] {
            if let folder = folders.first(where: { $0.name.lowercased() == name }) {
                return folder.url
            }
        }
        return project.folder
    }

    /// A file's path as TeX finds it: from the main file's folder, where it runs.
    func graphicsPath(of file: URL) -> String {
        projectFolder.map { PathUtilities.relativePath(of: file, from: $0) } ?? file.filePath
    }

    /// The label of a picture's figure, from its name.
    func figureLabel(for picture: URL) -> String {
        let key = NewFileKind.labelKey(for: picture.deletingPathExtension().lastPathComponent)
        return key.isEmpty ? NewFileKind.figure.defaultName : key
    }

    /// Inserts figures where you're writing, on lines of their own, with the insertion
    /// point in the first caption and Tab going on to the next.
    func insertFigures(_ figures: [String]) {
        // Indented with the editor's own indentation.
        let block = figures
            .map { $0.trimmingCharacters(in: .newlines).replacingOccurrences(of: "\n  ", with: "\n\t") }
            .joined(separator: "\n\n")
        let parts = block.components(separatedBy: "\\caption{}")
        let (leading, trailing) = blockPadding(at: floatInsertionLocation)
        editor.select(NSRange(location: floatInsertionLocation, length: 0))
        let title = figures.count == 1 ? String(localized: "Figure") : String(localized: "Figures")
        guard parts.count > 1 else {
            editor.insertText(leading + block + trailing, actionName: String(localized: "Insert \(title)"))
            return
        }
        // Named “Insert Figure” in the Edit menu.
        editor.insert(Snippet(
            title,
            before: leading + parts[0] + "\\caption{",
            after: "}" + parts.dropFirst().joined(separator: "\\caption{\(Snippet.stop)}") + trailing
        ))
    }

    // MARK: - Inserting

    /// Where a figure or table goes: the insertion point, or the end of the selection,
    /// which stays — or, when that's in the preamble or after the document, as it is in a
    /// main file just opened, after the body's last part, ahead of the bibliography.
    var floatInsertionLocation: Int {
        let string = text as NSString
        let location = min(NSMaxRange(editor.selectedRange), string.length)
        let begin = string.range(of: "\\begin{document}")
        guard begin.location != NSNotFound else { return location }
        let end = string.range(of: "\\end{document}", options: .backwards)
        if location < NSMaxRange(begin) || (end.location != NSNotFound && location > end.location) {
            return ProjectReferences.partInsertionPoint(in: string)
        }
        return location
    }

    /// The line breaks that put text inserted at `location` on lines of its own.
    private func blockPadding(at location: Int) -> (leading: String, trailing: String) {
        let string = text as NSString
        let leading = location > 0 && string.character(at: location - 1) != Char.newline ? "\n" : ""
        let trailing = location >= string.length || string.character(at: location) != Char.newline ? "\n" : ""
        return (leading, trailing)
    }

    /// Inserts `text` at `location` on lines of its own, as one undoable edit, leaving the
    /// insertion point after it.
    func insertBlock(_ text: String, at location: Int, actionName: String) {
        let (leading, trailing) = blockPadding(at: location)
        editor.select(NSRange(location: location, length: 0))
        editor.insertText(leading + text + trailing, actionName: actionName)
    }
}
