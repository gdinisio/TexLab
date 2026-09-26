//
//  WelcomeView.swift
//  TexLab
//

import AppKit
import Foundation
import SwiftUI

/// The Welcome window, like Xcode's: create or open a project — a whole folder — or
/// a single document, or pick up a recent project.
struct WelcomeView: View {
    @Environment(\.newDocument) private var newDocument
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.showsWelcomeAtLaunch) private var showsAtLaunch = AppSettings.showsWelcomeAtLaunch

    var body: some View {
        HStack(spacing: 0) {
            actions
                .frame(width: 440)
            Divider()
            RecentProjectsList()
                .frame(width: 320)
        }
        .frame(height: 460)
        .onAppear {
            WelcomeWindow.opener = openWindow
        }
    }

    private var actions: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 28)
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)
                .accessibilityHidden(true)
            Text(verbatim: "TexLab")
                .font(.system(size: 36, weight: .semibold))
                .padding(.top, 8)
            Text(versionText)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 24)
            VStack(alignment: .leading, spacing: 4) {
                WelcomeAction(
                    title: "Create New Project…",
                    subtitle: "A folder with main.tex, ready for chapters and a bibliography",
                    systemImage: "folder.badge.plus"
                ) {
                    ProjectCreator.createProject()
                }
                WelcomeAction(
                    title: "Open Existing Project…",
                    subtitle: "A project folder, or a single LaTeX document",
                    systemImage: "folder"
                ) {
                    ProjectOpener.chooseAndOpen()
                }
                WelcomeAction(
                    title: "New Document",
                    subtitle: "A single untitled document",
                    systemImage: "doc.badge.plus"
                ) {
                    newDocument(TexLabDocument())
                }
            }
            .padding(.horizontal, 36)
            Spacer(minLength: 20)
            Toggle("Show this window when TexLab opens", isOn: $showsAtLaunch)
                .toggleStyle(.checkbox)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
        }
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return String(localized: "Version \(version)")
    }
}

/// A large action row, highlighted under the pointer like Xcode's.
private struct WelcomeAction: View {
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey
    var systemImage: String
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .background(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

/// Recent projects, newest first. Double-click or Return opens one.
private struct RecentProjectsList: View {
    @State private var recents = RecentProjects.shared
    @State private var selection: RecentProject.ID?

    var body: some View {
        Group {
            if recents.items.isEmpty {
                ContentUnavailableView {
                    Label("No Recent Projects", systemImage: "clock")
                } description: {
                    Text("Projects and documents you open appear here.")
                }
            } else {
                List(recents.items, selection: $selection) { project in
                    RecentProjectRow(project: project)
                        .tag(project.id)
                }
                .listStyle(.sidebar)
                .contextMenu(forSelectionType: RecentProject.ID.self) { ids in
                    if let project = recents.items.first(where: { ids.contains($0.id) }) {
                        Button("Open") {
                            ProjectOpener.open(project)
                        }
                        .disabled(!project.exists)
                        Button("Show in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([project.isFolderProject ? project.folder : (project.mainFile ?? project.folder)])
                        }
                        .disabled(!project.exists)
                        Divider()
                        Button("Remove from Recent Projects") {
                            recents.remove(project)
                        }
                    }
                    Divider()
                    Button("Clear Recent Projects") {
                        recents.clear()
                    }
                } primaryAction: { ids in
                    if let project = recents.items.first(where: { ids.contains($0.id) }), project.exists {
                        ProjectOpener.open(project)
                    }
                }
            }
        }
        .background(.background.secondary)
    }
}

private struct RecentProjectRow: View {
    var project: RecentProject

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: project.isFolderProject ? "folder.fill" : "doc.text.fill")
                .font(.title2)
                .foregroundStyle(project.isFolderProject ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: project.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(verbatim: project.location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
        }
        .padding(.vertical, 4)
        .opacity(project.exists ? 1 : 0.45)
        .help(project.exists ? project.location : String(localized: "This project can’t be found. It may have been moved or deleted."))
    }
}

/// Opening the Welcome window from outside SwiftUI, such as when the Dock icon is clicked
/// with no windows open.
enum WelcomeWindow {
    static let id = "welcome"
    static var opener: OpenWindowAction?

    static func show() {
        if let opener {
            opener(id: id)
        } else {
            ProjectOpener.chooseAndOpen()
        }
    }
}

/// Keeps TexLab from opening an empty document at launch, since the Welcome window does
/// that job, and brings the Welcome window back when the Dock icon is clicked.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            WelcomeWindow.show()
        }
        return false
    }
}
