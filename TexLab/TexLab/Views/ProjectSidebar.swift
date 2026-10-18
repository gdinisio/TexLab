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
                    Text("Save this document in a folder to see the other files of its project and add parts, figures, images and bibliographies.")
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
            newFile: { folder, kind in
                session.showNewFileSheet(kind, in: folder)
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
                    session.showNewFileSheet(in: project.folder)
                }
                Button("Add Images…") {
                    session.showNewFileSheet(.image, in: project.folder)
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
