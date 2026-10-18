//
//  ProjectSidebar.swift
//  TexLab
//

import AppKit
import Foundation
import SwiftUI

/// The project navigator, like Xcode's. The Document section lists the main file and the
/// files it includes, in reading order and inside the file that includes them, each with
/// its first heading, then its bibliographies; Files lists the project folder. The list is
/// AppKit's sidebar outline (see `ProjectNavigatorOutline`); below it, + adds files and
/// folders and the filter field finds files by name.
struct ProjectSidebar: View {
    var session: DocumentSession

    @State private var filter = ""
    @State private var trashCandidates: [URL] = []
    @State private var errorMessage: String?
    /// A new folder, to name once the list shows it.
    @State private var folderToName: URL?

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
        .confirmationDialog(trashTitle, isPresented: Binding(get: { !trashCandidates.isEmpty }, set: { if !$0 { trashCandidates = [] } })) {
            Button("Move to Trash", role: .destructive) {
                session.moveToTrash(trashCandidates)
                trashCandidates = []
            }
        } message: {
            Text("You can put items back from the Trash in the Finder.")
        }
        .alert("The file couldn’t be changed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func navigator(_ project: ProjectSnapshot) -> some View {
        ProjectNavigatorOutline(
            session: session,
            project: project,
            filter: trimmedFilter,
            shownURL: session.fileURL,
            renameRequest: folderToName,
            actions: actions
        )
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar(project)
        }
    }

    private var actions: ProjectNavigatorActions {
        ProjectNavigatorActions(
            newFile: { folder in
                session.newFileFolder = folder
                session.isShowingNewFileSheet = true
            },
            newFolder: { folder in
                newFolder(in: folder)
            },
            moveToTrash: { urls in
                trashCandidates = urls
            },
            showError: { error in
                errorMessage = error.localizedDescription
            },
            didBeginRenaming: {
                folderToName = nil
            }
        )
    }

    /// Makes “untitled folder” and lets the list name it, as the Finder does.
    private func newFolder(in folder: URL) {
        do {
            folderToName = try session.createFolder(named: String(localized: "untitled folder"), in: folder)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private var trimmedFilter: String {
        filter.trimmingCharacters(in: .whitespaces)
    }

    private func bottomBar(_ project: ProjectSnapshot) -> some View {
        HStack(spacing: 8) {
            Menu {
                Button("New File…") {
                    session.newFileFolder = project.folder
                    session.isShowingNewFileSheet = true
                }
                Button("New Folder") {
                    newFolder(in: project.folder)
                }
            } label: {
                Image(systemName: "plus")
                    .accessibilityLabel("Add")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Add a file or folder to the project")

            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(trimmedFilter.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.accentColor))
                    .accessibilityHidden(true)
                TextField("Filter", text: $filter)
                    .textFieldStyle(.plain)
                if !filter.isEmpty {
                    Button {
                        filter = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear the filter")
                    .accessibilityLabel("Clear the filter")
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.background, in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.separator)
            }
            .help("Show only files whose name contains this text")
        }
        .font(.callout)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var trashTitle: String {
        trashCandidates.count == 1
            ? String(localized: "Move “\(trashCandidates[0].lastPathComponent)” to the Trash?")
            : String(localized: "Move \(trashCandidates.count) items to the Trash?")
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
            // One of the picker's own folders, so it shows the choice.
            let requested = session.newFileFolder ?? session.project?.folder
            folder = session.project?.tree.folders.first { item in
                requested.map { SourceMap.canonicalPath($0) == SourceMap.canonicalPath(item.url) } ?? false
            }?.url ?? session.project?.folder
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
