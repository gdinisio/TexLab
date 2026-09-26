//
//  ProjectSidebar.swift
//  TexLab
//

import AppKit
import Foundation
import SwiftUI

/// The project navigator: the files of the document's folder, like Xcode's. Double-click a
/// file to open it in a tab, drag it into the editor to reference it, and use the context
/// menu or the + button to add, rename and remove files.
struct ProjectSidebar: View {
    var session: DocumentSession

    @State private var selection: Set<URL> = []
    @State private var renamingURL: URL?
    @State private var newFolderParent: URL?
    @State private var enteredName = ""
    @State private var trashCandidates: [URL] = []
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let project = session.project {
                navigator(project)
            } else if session.fileURL == nil {
                ContentUnavailableView {
                    Label("No Project", systemImage: "folder")
                } description: {
                    Text("Save this document in a folder to see the other files of its project and add chapters, bibliographies and packages.")
                } actions: {
                    Button("Save…") {
                        NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: nil)
                    }
                }
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .alert("Rename", isPresented: isPresenting($renamingURL)) {
            TextField("Name", text: $enteredName)
            Button("Rename") {
                if let url = renamingURL {
                    perform { try session.renameProjectFile(url, to: enteredName) }
                }
            }
            .disabled(!isValidName(enteredName))
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Other files that reference it aren’t changed.")
        }
        .alert("New Folder", isPresented: isPresenting($newFolderParent)) {
            TextField("Name", text: $enteredName)
            Button("Create") {
                if let parent = newFolderParent {
                    perform { try session.createFolder(named: enteredName, in: parent) }
                }
            }
            .disabled(!isValidName(enteredName))
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(trashTitle, isPresented: Binding(get: { !trashCandidates.isEmpty }, set: { if !$0 { trashCandidates = [] } })) {
            Button("Move to Trash", role: .destructive) {
                session.moveToTrash(trashCandidates)
                trashCandidates = []
            }
        } message: {
            Text("You can put items back from the Trash in the Finder.")
        }
        .alert("The file couldn’t be changed", isPresented: isPresenting($errorMessage)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func navigator(_ project: ProjectSnapshot) -> some View {
        List(project.tree.children ?? [], children: \.children, selection: $selection) { file in
            ProjectRow(file: file, isMain: isMain(file, in: project), isCurrent: isCurrent(file))
                .draggable(file.url)
        }
        .listStyle(.sidebar)
        .contextMenu(forSelectionType: URL.self) { urls in
            menu(for: Array(urls), in: project)
        } primaryAction: { urls in
            for url in urls where !isFolder(url, in: project) {
                session.openProjectFile(url)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar(project)
        }
        .onAppear {
            if selection.isEmpty, let fileURL = session.fileURL {
                selection = [fileURL.standardizedFileURL]
            }
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private func menu(for urls: [URL], in project: ProjectSnapshot) -> some View {
        let files = urls.filter { !isFolder($0, in: project) }
        if !files.isEmpty {
            Button(files.count == 1 ? "Open" : "Open \(files.count) Files") {
                files.forEach { session.openProjectFile($0) }
            }
            if files.count == 1, let file = files.first, ProjectFileKind(url: file, isDirectory: false).opensInTexLab {
                Button("Open in New Window") {
                    session.openProjectFile(file, inNewWindow: true)
                }
            }
            if files.count == 1, let file = files.first, !isCurrentURL(file),
               session.projectFolder.flatMap({ ProjectReferences.reference(to: file, from: $0) }) != nil {
                Button("Insert Reference at Insertion Point") {
                    session.insertReference(to: file)
                }
            }
            if files.count == 1, let file = files.first, ProjectFileKind(url: file, isDirectory: false) == .latex,
               !isCurrentURL(file), project.mainFile.map({ SourceMap.canonicalPath($0) != SourceMap.canonicalPath(file) }) ?? true {
                Button("Use as Main File for This Document") {
                    session.useAsMainFile(file)
                }
            }
            Divider()
        }
        Button("New File…") {
            session.newFileFolder = targetFolder(for: urls, in: project)
            session.isShowingNewFileSheet = true
        }
        Button("New Folder…") {
            enteredName = String(localized: "untitled folder")
            newFolderParent = targetFolder(for: urls, in: project)
        }
        if !urls.isEmpty {
            Divider()
            Button(urls.count == 1 ? "Copy Path" : "Copy Paths") {
                Pasteboard.copy(urls.map { PathUtilities.relativePath(of: $0, from: project.folder) }.joined(separator: "\n"))
            }
            .help("The path from the main file’s folder, as \\includegraphics and \\input expect it")
            Button(urls.count == 1 ? "Copy Full Path" : "Copy Full Paths") {
                Pasteboard.copy(urls.map(\.filePath).joined(separator: "\n"))
            }
            let references = urls.compactMap { ProjectReferences.reference(to: $0, from: project.folder) }
            if !references.isEmpty {
                Button(references.count == 1 ? "Copy LaTeX Reference" : "Copy LaTeX References") {
                    Pasteboard.copy(references.joined(separator: "\n"))
                }
                .help("The command that uses the file, such as \\includegraphics{…} or \\input{…}")
            }
            Divider()
            Button("Show in Finder") {
                session.showInFinder(urls)
            }
            if urls.count == 1, let url = urls.first {
                Button("Rename…") {
                    enteredName = url.lastPathComponent
                    renamingURL = url
                }
            }
            Divider()
            Button("Move to Trash…", role: .destructive) {
                trashCandidates = urls
            }
        }
    }

    private func bottomBar(_ project: ProjectSnapshot) -> some View {
        HStack(spacing: 8) {
            Menu {
                Button("New File…") {
                    session.newFileFolder = project.folder
                    session.isShowingNewFileSheet = true
                }
                Button("New Folder…") {
                    enteredName = String(localized: "untitled folder")
                    newFolderParent = project.folder
                }
            } label: {
                Image(systemName: "plus")
                    .accessibilityLabel("Add")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Add a file or folder to the project")

            Spacer(minLength: 4)

            if let main = project.mainFile {
                Label(main.lastPathComponent, systemImage: "doc.richtext")
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
                    .help(session.isMainFile ? "This document is the main file" : "Typesetting this document typesets \(main.lastPathComponent)")
            }
        }
        .font(.callout)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    // MARK: - Helpers

    private func isMain(_ file: ProjectFile, in project: ProjectSnapshot) -> Bool {
        guard let main = project.mainFile else { return false }
        return SourceMap.canonicalPath(main) == SourceMap.canonicalPath(file.url)
    }

    private func isCurrent(_ file: ProjectFile) -> Bool {
        isCurrentURL(file.url)
    }

    private func isCurrentURL(_ url: URL) -> Bool {
        guard let fileURL = session.fileURL else { return false }
        return SourceMap.canonicalPath(fileURL) == SourceMap.canonicalPath(url)
    }

    private func isFolder(_ url: URL, in project: ProjectSnapshot) -> Bool {
        project.tree.folders.contains { $0.url == url }
    }

    /// The folder a new item goes in: the selected folder, or the selected file's folder.
    private func targetFolder(for urls: [URL], in project: ProjectSnapshot) -> URL {
        guard let url = urls.first else { return project.folder }
        return isFolder(url, in: project) ? url : url.deletingLastPathComponent()
    }

    private func isValidName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && !trimmed.contains("/") && !trimmed.hasPrefix(".")
    }

    private var trashTitle: String {
        trashCandidates.count == 1
            ? String(localized: "Move “\(trashCandidates[0].lastPathComponent)” to the Trash?")
            : String(localized: "Move \(trashCandidates.count) items to the Trash?")
    }

    private func perform(_ change: () throws -> Void) {
        do {
            try change()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func isPresenting<Value>(_ value: Binding<Value?>) -> Binding<Bool> {
        Binding(get: { value.wrappedValue != nil }, set: { if !$0 { value.wrappedValue = nil } })
    }
}

private struct ProjectRow: View {
    var file: ProjectFile
    var isMain: Bool
    var isCurrent: Bool

    var body: some View {
        Label {
            HStack(spacing: 6) {
                Text(file.name)
                    .fontWeight(isCurrent ? .semibold : .regular)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if isMain {
                    Text("Main")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                        .accessibilityLabel("Main file")
                }
            }
        } icon: {
            Image(systemName: file.kind.systemImage)
                .foregroundStyle(file.isFolder ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
        }
        .help(file.url.filePath)
    }
}

/// File ▸ New File in Project: a chapter, bibliography, package or document, created in a
/// folder of the project and, if you like, referenced from the main file.
struct NewProjectFileSheet: View {
    var session: DocumentSession
    @Environment(\.dismiss) private var dismiss

    @State private var kind: NewFileKind = .chapter
    @State private var name = NewFileKind.chapter.defaultName
    @State private var folder: URL?
    @State private var addsReference = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New File")
                .font(.headline)
            Form {
                Picker("Kind", selection: $kind) {
                    ForEach(NewFileKind.allCases) { kind in
                        Label(kind.title, systemImage: kind.systemImage).tag(kind)
                    }
                }
                TextField("Name", text: $name, prompt: Text(kind.defaultName))
                if let project = session.project {
                    Picker("Folder", selection: $folder) {
                        ForEach(project.tree.folders, id: \.url) { item in
                            Text(folderTitle(item.url, in: project)).tag(Optional(item.url))
                        }
                    }
                    if kind.canBeReferenced, let main = project.mainFile {
                        Toggle(kind.referenceDescription(mainFileName: main.lastPathComponent), isOn: $addsReference)
                    }
                }
            }
            .formStyle(.columns)
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Create") {
                    create()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear {
            folder = session.newFileFolder ?? session.project?.folder
        }
        .onChange(of: kind) { oldKind, newKind in
            // Keep a name the user typed; replace the suggestion.
            if name.isEmpty || name == oldKind.defaultName {
                name = newKind.defaultName
            }
        }
    }

    private var trimmedName: String {
        var trimmed = name.trimmingCharacters(in: .whitespaces)
        let suffix = "." + kind.fileExtension
        if trimmed.lowercased().hasSuffix(suffix) {
            trimmed = String(trimmed.dropLast(suffix.count))
        }
        return trimmed
    }

    private var isValid: Bool {
        !trimmedName.isEmpty && !trimmedName.contains("/") && !trimmedName.hasPrefix(".") && folder != nil
    }

    private func folderTitle(_ url: URL, in project: ProjectSnapshot) -> String {
        if url.standardizedFileURL == project.folder.standardizedFileURL {
            return String(localized: "\(project.folder.lastPathComponent) (project folder)")
        }
        return PathUtilities.relativePath(of: url, from: project.folder)
    }

    private func create() {
        guard let folder else { return }
        do {
            try session.createProjectFile(kind: kind, name: trimmedName, in: folder, addsReference: addsReference && kind.canBeReferenced)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
