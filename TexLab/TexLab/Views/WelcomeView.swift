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
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @AppStorage(SettingsKey.showsWelcomeAtLaunch) private var showsAtLaunch = AppSettings.showsWelcomeAtLaunch
    @State private var isShowingClone = false
    @State private var isDropTargeted = false

    var body: some View {
        HStack(spacing: 0) {
            actions
                .frame(width: 420)
            Divider()
            RecentProjectsPane()
                .frame(width: 340)
        }
        .frame(height: 460)
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
            WelcomeWindow.dismisser = dismissWindow
        }
    }

    /// The icon, name and version, then the four ways in, each one line; what each does,
    /// and its shortcut, is in its help tag.
    private var actions: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
                .accessibilityHidden(true)
            Text(verbatim: "TexLab")
                .font(.system(size: 32, weight: .semibold))
                .padding(.top, 4)
            Text(versionText)
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            VStack(spacing: 2) {
                WelcomeAction("Create New Project…", systemImage: "folder.badge.plus", help: "Choose a template, then where to save the project’s folder (⇧⌘N)") {
                    openWindow(id: NewProjectWindow.id)
                }
                WelcomeAction("Open Existing Project…", systemImage: "folder", help: "Open a project folder or a single LaTeX document (⇧⌘O)") {
                    ProjectOpener.chooseAndOpen()
                }
                WelcomeAction("Clone Git Repository…", systemImage: "arrow.down.circle", help: "Clone a project from GitHub, GitLab or Overleaf") {
                    isShowingClone = true
                }
                WelcomeAction("New Document", systemImage: "doc.badge.plus", help: "Start a single untitled document (⌘N)") {
                    NSDocumentController.shared.newDocument(nil)
                }
            }
            .frame(width: 280)
            Spacer()
            Toggle("Show this window when TexLab opens", isOn: $showsAtLaunch)
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
        }
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return String(localized: "Version \(version)")
    }
}

/// An action of the Welcome window: its symbol and title on one line, highlighted under the
/// pointer, as in Xcode.
private struct WelcomeAction: View {
    var title: LocalizedStringKey
    var systemImage: String
    var help: LocalizedStringKey
    var action: () -> Void

    @State private var isHovered = false

    init(_ title: LocalizedStringKey, systemImage: String, help: LocalizedStringKey, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.help = help
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 26)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.body.weight(.medium))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help)
    }
}

/// Recent projects, newest first, with pinned projects above them. Double-click or Return
/// opens one; the context menu pins, reveals, locates or removes it. Below the list, on
/// Liquid Glass like the navigators' bars, a filter field and Clear, which forgets every
/// project that isn't pinned — the projects themselves stay where they are.
private struct RecentProjectsPane: View {
    @State private var recents = RecentProjects.shared
    @State private var selection: RecentProject.ID?
    @State private var query = ""
    @State private var isConfirmingClear = false

    private var pinned: [RecentProject] {
        recents.pinned.filter { $0.matches(query) }
    }

    private var others: [RecentProject] {
        recents.unpinned.filter { $0.matches(query) }
    }

    /// Whether Clear has anything to forget: pinned projects stay.
    private var canClear: Bool {
        !recents.unpinned.isEmpty
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !recents.items.isEmpty {
                    bottomBar
                }
            }
            .background(.background.secondary)
            .confirmationDialog("Clear the recent projects?", isPresented: $isConfirmingClear) {
                Button("Clear", role: .destructive) {
                    recents.clear()
                    selection = nil
                }
            } message: {
                if recents.pinned.isEmpty {
                    Text("The list is emptied; the projects themselves stay where they are.")
                } else {
                    Text("Pinned projects stay; the others leave the list, and the projects themselves stay where they are.")
                }
            }
    }

    private var bottomBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.3.horizontal.decrease")
                .foregroundStyle(query.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.accentColor))
                .accessibilityHidden(true)
            TextField("Filter", text: $query)
                .textFieldStyle(.plain)
                .help("Show only projects whose name, title or location contains this text")
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear the filter")
                .accessibilityLabel("Clear the filter")
            }
            Divider()
                .frame(height: 14)
            Button("Clear…") {
                isConfirmingClear = true
            }
            .buttonStyle(.borderless)
            .disabled(!canClear)
            .help("Forget the recent projects that aren’t pinned")
        }
        .font(.callout)
        .navigatorGlass()
        .padding(8)
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
            .scrollContentBackground(.hidden)
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
        Button("Clear Recent Projects…") {
            isConfirmingClear = true
        }
        .disabled(!canClear)
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

/// A recent project in two lines: a thumbnail of its typeset first page when there is one,
/// its name and where it is. Its title and when it was last opened are in its help tag.
private struct RecentProjectRow: View {
    var project: RecentProject

    @State private var thumbnail: NSImage?

    var body: some View {
        let exists = project.exists
        HStack(spacing: 10) {
            icon
            VStack(alignment: .leading, spacing: 2) {
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
                Text(verbatim: exists ? project.location : String(localized: "Can’t be found"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .opacity(exists ? 1 : 0.5)
        .help(helpText)
        .task(id: project.id) {
            thumbnail = await ProjectThumbnails.shared.thumbnail(for: project)
        }
    }

    private var helpText: String {
        guard project.exists else {
            return String(localized: "This project can’t be found. It may have been moved or deleted.")
        }
        var lines: [String] = []
        if let title = project.title, title != project.name {
            lines.append(title)
        }
        lines.append(project.location)
        lines.append(String(localized: "Opened \(project.lastOpened.formatted(.relative(presentation: .named)))"))
        return lines.joined(separator: "\n")
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
    static var dismisser: DismissWindowAction?

    static func show() {
        if let opener {
            opener(id: id)
        } else {
            ProjectOpener.chooseAndOpen()
        }
    }

    /// A project window took over from the Welcome window, as in Xcode.
    static func dismiss() {
        dismisser?(id: id)
    }
}

/// Makes TexLab a document app, keeps it from opening an empty document at launch, since
/// the Welcome window does that job, and brings the Welcome window back when the Dock icon
/// is clicked.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        // The first document controller made is the app's.
        _ = TeXDocumentController()
        ActiveSession.shared.startObserving()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        RecentDocuments.shared.refresh()
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    /// TexLab stays open with no windows, as document apps do; the Dock icon brings the
    /// Welcome window back.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            WelcomeWindow.show()
        }
        return false
    }
}
