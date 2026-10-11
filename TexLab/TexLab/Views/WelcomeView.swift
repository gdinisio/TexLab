//
//  WelcomeView.swift
//  TexLab
//

import AppKit
import Foundation
import SwiftUI

/// The Welcome window, like Xcode's: create, open or clone a project — a whole folder —
/// or start a single document, and pick up a recent project. A folder or document dropped
/// on the window opens too.
struct WelcomeView: View {
    @Environment(\.newDocument) private var newDocument
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.showsWelcomeAtLaunch) private var showsAtLaunch = AppSettings.showsWelcomeAtLaunch
    @State private var isShowingClone = false
    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: 0) {
            actions
                .frame(width: 440)
            Divider()
            RecentProjectsPane()
                .frame(width: 340)
        }
        .frame(height: 480)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: \.isFileURL) else { return false }
            ProjectOpener.open(url)
            return true
        } isTargeted: { isTargeted in
            isDropTargeted = isTargeted
        }
        .sheet(isPresented: $isShowingClone) {
            CloneRepositoryView()
        }
        .onAppear {
            WelcomeWindow.opener = openWindow
        }
    }

    private var actions: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)
                .accessibilityHidden(true)
            Text(verbatim: "TexLab")
                .font(.system(size: 36, weight: .semibold))
                .padding(.top, 6)
            Text(versionText)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer(minLength: 20)
            VStack(alignment: .leading, spacing: 2) {
                WelcomeAction(
                    title: "Create New Project…",
                    subtitle: "Choose a template, then where to save the folder",
                    systemImage: "folder.badge.plus",
                    shortcut: "⇧⌘N"
                ) {
                    openWindow(id: NewProjectWindow.id)
                }
                WelcomeAction(
                    title: "Open Existing Project…",
                    subtitle: "A project folder, or a single LaTeX document",
                    systemImage: "folder",
                    shortcut: "⇧⌘O"
                ) {
                    ProjectOpener.chooseAndOpen()
                }
                WelcomeAction(
                    title: "Clone Git Repository…",
                    subtitle: "From GitHub, GitLab or an Overleaf project",
                    systemImage: "arrow.down.circle"
                ) {
                    isShowingClone = true
                }
                WelcomeAction(
                    title: "New Document",
                    subtitle: "A single untitled document",
                    systemImage: "doc.badge.plus",
                    shortcut: "⌘N"
                ) {
                    newDocument(TexLabDocument())
                }
            }
            .padding(.horizontal, 32)
            Spacer(minLength: 16)
            Toggle("Show this window when TexLab opens", isOn: $showsAtLaunch)
                .toggleStyle(.checkbox)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.bottom, 14)
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
    var shortcut: String?
    var action: () -> Void

    @State private var isHovered = false

    init(title: LocalizedStringKey, subtitle: LocalizedStringKey, systemImage: String, shortcut: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.shortcut = shortcut
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let shortcut {
                    Text(verbatim: shortcut)
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
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

/// Recent projects, newest first, with pinned projects above them and a search field.
/// Double-click or Return opens one; the context menu pins, reveals, locates or removes.
private struct RecentProjectsPane: View {
    @State private var recents = RecentProjects.shared
    @State private var selection: RecentProject.ID?
    @State private var query = ""

    private var pinned: [RecentProject] {
        recents.pinned.filter { $0.matches(query) }
    }

    private var others: [RecentProject] {
        recents.unpinned.filter { $0.matches(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !recents.items.isEmpty {
                searchField
            }
            content
        }
        .background(.background.secondary)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search Recent Projects", text: $query)
                .textFieldStyle(.plain)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear the search")
                .accessibilityLabel("Clear the search")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.background, in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(.separator)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var content: some View {
        if recents.items.isEmpty {
            ContentUnavailableView {
                Label("No Recent Projects", systemImage: "clock")
            } description: {
                Text("Projects you open appear here. You can also drop a project folder or a document on this window.")
            }
        } else if pinned.isEmpty && others.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List(selection: $selection) {
                if !pinned.isEmpty {
                    Section("Pinned") {
                        ForEach(pinned) { project in
                            RecentProjectRow(project: project)
                                .tag(project.id)
                        }
                    }
                }
                if !others.isEmpty {
                    Section {
                        ForEach(others) { project in
                            RecentProjectRow(project: project)
                                .tag(project.id)
                        }
                    } header: {
                        if !pinned.isEmpty {
                            Text("Recent")
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .contextMenu(forSelectionType: RecentProject.ID.self) { ids in
                menu(for: ids)
            } primaryAction: { ids in
                open(ids)
            }
        }
    }

    @ViewBuilder
    private func menu(for ids: Set<RecentProject.ID>) -> some View {
        if let project = recents.items.first(where: { ids.contains($0.id) }) {
            if project.exists {
                Button("Open") {
                    ProjectOpener.open(project)
                }
                Button("Show in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([project.url])
                }
                Button("Copy Path") {
                    Pasteboard.copy(project.url.path(percentEncoded: false))
                }
            } else {
                Button("Locate…") {
                    RecentProjectsPane.locate(project)
                }
            }
            Divider()
            Button(project.isPinned ? LocalizedStringKey("Unpin") : LocalizedStringKey("Pin to Top")) {
                recents.setPinned(!project.isPinned, for: project)
            }
            Button("Remove from Recent Projects") {
                recents.remove(project)
            }
            Divider()
        }
        if recents.items.contains(where: { !$0.exists }) {
            Button("Remove Projects That Can’t Be Found") {
                recents.removeMissing()
            }
        }
        Button("Clear Recent Projects") {
            recents.clear()
        }
        .help("Pinned projects stay")
    }

    private func open(_ ids: Set<RecentProject.ID>) {
        guard let project = recents.items.first(where: { ids.contains($0.id) }) else { return }
        if project.exists {
            ProjectOpener.open(project)
        } else {
            Self.offerToLocate(project)
        }
    }

    /// A project that has moved: find it, or forget it.
    private static func offerToLocate(_ project: RecentProject) {
        let alert = NSAlert()
        alert.messageText = String(localized: "“\(project.name)” can’t be found")
        alert.informativeText = String(localized: "It may have been moved, renamed or deleted.")
        alert.addButton(withTitle: String(localized: "Locate…"))
        alert.addButton(withTitle: String(localized: "Remove from List"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            locate(project)
        case .alertSecondButtonReturn:
            RecentProjects.shared.remove(project)
        default:
            break
        }
    }

    /// Asks where a moved project is now, starting in the nearest folder that still exists.
    private static func locate(_ project: RecentProject) {
        let panel = NSOpenPanel()
        panel.message = String(localized: "Where is “\(project.name)” now?")
        panel.prompt = String(localized: "Choose")
        panel.canChooseDirectories = project.isFolderProject
        panel.canChooseFiles = !project.isFolderProject
        var folder = project.url.deletingLastPathComponent()
        while !FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)) && folder.pathComponents.count > 1 {
            folder = folder.deletingLastPathComponent()
        }
        panel.directoryURL = folder
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated {
                RecentProjects.shared.relocate(project, to: url)
            }
        }
    }
}

/// A recent project: a thumbnail of its typeset first page when there is one, its name,
/// title and location, and when it was last opened.
private struct RecentProjectRow: View {
    var project: RecentProject

    @State private var thumbnail: NSImage?

    var body: some View {
        let exists = project.exists
        HStack(spacing: 10) {
            icon
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(verbatim: project.name)
                        .font(.headline)
                        .lineLimit(1)
                    if project.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Pinned")
                    }
                }
                if let title = project.title, title != project.name {
                    Text(verbatim: title)
                        .font(.caption)
                        .lineLimit(1)
                }
                Text(verbatim: exists ? project.location : String(localized: "Can’t be found"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer(minLength: 4)
            Text(project.lastOpened, format: .relative(presentation: .named))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
        .opacity(exists ? 1 : 0.5)
        .help(exists ? project.location : String(localized: "This project can’t be found. It may have been moved or deleted."))
        .task(id: project.id) {
            thumbnail = await ProjectThumbnails.shared.thumbnail(for: project)
        }
    }

    @ViewBuilder
    private var icon: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 40)
                .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
                .frame(width: 34, height: 40)
                .accessibilityHidden(true)
        } else {
            Image(systemName: project.isFolderProject ? "folder.fill" : "doc.text.fill")
                .font(.title2)
                .foregroundStyle(project.isFolderProject ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .frame(width: 34, height: 40)
                .accessibilityHidden(true)
        }
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
