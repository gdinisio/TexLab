//
//  EditorFileBar.swift
//  TexLab
//

import AppKit
import Foundation
import SwiftUI

/// The bar above the editor, like Xcode's jump bar: Go Back and Go Forward through the
/// files shown, the file the editor shows with a menu of the window's open documents, and
/// a way back to the main file from a chapter.
struct EditorFileBar: View {
    var session: DocumentSession

    var body: some View {
        HStack(spacing: 2) {
            Button {
                session.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 20, height: 20)
            }
            .disabled(!session.canGoBack)
            .help("Go Back (⌃⌘←)")
            .accessibilityLabel("Go Back")
            Button {
                session.goForward()
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 20, height: 20)
            }
            .disabled(!session.canGoForward)
            .help("Go Forward (⌃⌘→)")
            .accessibilityLabel("Go Forward")

            Divider()
                .frame(height: 14)
                .padding(.horizontal, 4)

            Menu {
                filesMenu
            } label: {
                fileLabel
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("The file the editor shows. Click for the other files open in this window.")

            Spacer(minLength: 8)

            if let main = session.project?.mainFile, !session.isMainFile {
                Button {
                    session.showMainFile()
                } label: {
                    Label(ProjectFileKind.displayName(of: main), systemImage: "doc.text")
                        .labelStyle(.titleAndIcon)
                }
                .help("Show the main file, which typesets the whole document (⌃⌘↑)")
            }
        }
        .buttonStyle(.borderless)
        .font(.callout)
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var fileLabel: some View {
        HStack(spacing: 5) {
            Image(systemName: icon(for: session.currentDocument))
                .foregroundStyle(tint(for: session.currentDocument))
            Text(verbatim: path(of: session.currentDocument))
                .lineLimit(1)
                .truncationMode(.head)
            if session.currentDocument?.state.isEdited == true {
                Circle()
                    .fill(.secondary)
                    .frame(width: 6, height: 6)
                    .accessibilityLabel("Not yet saved")
            }
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var filesMenu: some View {
        Section("Open in This Window") {
            ForEach(session.documents) { document in
                Toggle(isOn: Binding(
                    get: { session.currentDocument === document },
                    set: { isOn in
                        if isOn {
                            session.show(document)
                        }
                    }
                )) {
                    Text(verbatim: path(of: document) + (document.state.isEdited ? " •" : ""))
                }
            }
        }
        Divider()
        if let current = session.currentDocument, session.documents.count > 1 {
            Button("Close “\(path(of: current))”") {
                session.closeDocument(current)
            }
        }
        Button("Show in Project Navigator") {
            session.showNavigator(.project)
        }
        .disabled(session.project == nil)
        if let url = session.fileURL {
            Button("Show in Finder") {
                session.showInFinder([url])
            }
        }
    }

    /// The document's path from the project folder, or its name, without the extension its
    /// icon stands for.
    private func path(of document: TeXDocument?) -> String {
        guard let document, let url = document.state.url else { return document?.state.name ?? String(localized: "Untitled") }
        guard let folder = session.project?.folder else { return ProjectFileKind.displayName(of: url) }
        return ProjectFileKind.displayPath(of: url, from: folder)
    }

    private func icon(for document: TeXDocument?) -> String {
        guard let url = document?.state.url else { return "doc.text" }
        return ProjectFileKind.systemImage(for: url)
    }

    private func tint(for document: TeXDocument?) -> Color {
        guard let url = document?.state.url else { return ProjectFileKind.latex.tintColor }
        return ProjectFileKind(url: url, isDirectory: false).tintColor
    }
}
