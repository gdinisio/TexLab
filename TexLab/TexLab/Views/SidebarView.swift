//
//  SidebarView.swift
//  TexLab
//

import Foundation
import SwiftUI

/// The sidebar: five navigators, like Xcode's — the project's files, the outline, Find,
/// references and issues — chosen with the icons along the top or ⌘1 to ⌘5.
struct SidebarView: View {
    @Bindable var session: DocumentSession

    var body: some View {
        Group {
            switch session.sidebarTab {
            case .project:
                ProjectSidebar(session: session)
            case .outline:
                OutlineSidebar(session: session)
            case .find:
                FindSidebar(session: session)
            case .references:
                ReferencesSidebar(session: session)
            case .issues:
                IssuesSidebar(session: session)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            NavigatorBar(session: session)
        }
    }
}

/// The row of navigator icons above the sidebar, like Xcode's, floating on Liquid Glass:
/// the chosen one is highlighted, and the Issues icon shows how many there are.
private struct NavigatorBar: View {
    var session: DocumentSession
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 2) {
            ForEach(SidebarTab.allCases) { tab in
                NavigatorButton(
                    tab: tab,
                    isSelected: session.sidebarTab == tab,
                    badge: tab == .issues ? issuesCount : 0,
                    hasErrors: session.errorCount > 0,
                    highlight: highlight
                ) {
                    withAnimation(.snappy(duration: 0.25)) {
                        session.sidebarTab = tab
                    }
                }
            }
        }
        .padding(3)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    private var issuesCount: Int {
        session.errorCount + session.warningCount
    }
}

private struct NavigatorButton: View {
    var tab: SidebarTab
    var isSelected: Bool
    var badge: Int
    var hasErrors: Bool
    /// Where the highlight of the chosen navigator slides between buttons.
    var highlight: Namespace.ID
    var action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: isSelected ? tab.selectedSystemImage : tab.systemImage)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                .frame(maxWidth: .infinity, minHeight: 26)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.accentColor.opacity(0.16))
                            .matchedGeometryEffect(id: "selection", in: highlight)
                    } else if isHovered {
                        Capsule()
                            .fill(.quaternary)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if badge > 0 {
                        Text(verbatim: badge > 99 ? "99+" : "\(badge)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 14, minHeight: 14)
                            .background(hasErrors ? Color.red : Color.orange, in: Capsule())
                            .offset(x: -1, y: -2)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(tab.helpText)
        .accessibilityLabel(badge > 0 ? "\(tab.title), \(badge)" : tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

extension View {
    /// A navigator's search or filter field, or its row of buttons: a capsule of Liquid
    /// Glass that floats over the list, like the navigator bar.
    func navigatorGlass() -> some View {
        padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffect(.regular, in: .capsule)
    }

    /// Fills the navigator, so a message such as “No Issues” sits in the middle of it and
    /// the bars above and below stay at the edges.
    func fillsNavigator() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension SidebarTab {
    var title: String {
        switch self {
        case .project: String(localized: "Project")
        case .outline: String(localized: "Outline")
        case .find: String(localized: "Find")
        case .references: String(localized: "References")
        case .issues: String(localized: "Issues")
        }
    }

    var systemImage: String {
        switch self {
        case .project: "folder"
        case .outline: "list.bullet.indent"
        case .find: "magnifyingglass"
        case .references: "books.vertical"
        case .issues: "exclamationmark.triangle"
        }
    }

    var selectedSystemImage: String {
        switch self {
        case .project: "folder.fill"
        case .outline: "list.bullet.indent"
        case .find: "magnifyingglass"
        case .references: "books.vertical.fill"
        case .issues: "exclamationmark.triangle.fill"
        }
    }

    /// The tooltip, with the shortcut.
    var helpText: String {
        let index = (SidebarTab.allCases.firstIndex(of: self) ?? 0) + 1
        switch self {
        case .project: return String(localized: "Project: the files of the project (⌘\(index))")
        case .outline: return String(localized: "Outline: headings, frames and floats (⌘\(index))")
        case .find: return String(localized: "Find in Project (⌘\(index))")
        case .references: return String(localized: "References: labels and bibliography (⌘\(index))")
        case .issues: return String(localized: "Issues: found while typing and by TeX (⌘\(index))")
        }
    }
}

/// The document's structure: the file on screen, or the whole document across the files
/// its main file includes. Selecting an item jumps to it in the editor and preview — in
/// another file if that's where it is — and the selection follows the insertion point.
struct OutlineSidebar: View {
    var session: DocumentSession

    @AppStorage("outlineShowsWholeDocument") private var showsWholeDocument = true
    @State private var selection: OutlineItem.ID?
    @State private var documentSelection: DocumentOutlineNode.ID?

    /// Whether the project has more than one file to show an outline across.
    private var hasDocument: Bool {
        (session.project?.parts.filter { $0.kind != .bibliography }.count ?? 0) > 1
    }

    var body: some View {
        Group {
            if hasDocument && showsWholeDocument {
                documentOutline
            } else {
                fileOutline
            }
        }
        .fillsNavigator()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if hasDocument {
                Picker("Outline", selection: $showsWholeDocument) {
                    Text("This File").tag(false)
                    Text("Whole Document").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .padding(3)
                .glassEffect(.regular, in: .capsule)
                .padding(8)
            }
        }
    }

    // MARK: - This file

    @ViewBuilder
    private var fileOutline: some View {
        if session.outline.isEmpty {
            ContentUnavailableView {
                Label("No Outline", systemImage: "list.bullet.indent")
            } description: {
                Text("Sections, frames, figures and tables appear here as you write them.")
            }
        } else {
            List(session.outline, children: \.children, selection: $selection) { item in
                OutlineRow(kind: item.kind, title: item.title, line: item.line, fileName: nil)
            }
            .listStyle(.sidebar)
            .onAppear {
                follow(session.currentOutlineItemID)
            }
            .onChange(of: session.currentOutlineItemID) { _, newValue in
                follow(newValue)
            }
            .onChange(of: selection) { _, newValue in
                // Following the insertion point selects its item; only picking a different
                // item moves the editor.
                guard let newValue, newValue != session.currentOutlineItemID,
                      let item = session.outlineItem(withID: newValue) else { return }
                session.revealOutlineItem(item)
            }
        }
    }

    /// Selects the item containing the insertion point without jumping to it.
    private func follow(_ id: OutlineItem.ID?) {
        guard selection != id else { return }
        selection = id
    }

    // MARK: - Whole document

    @ViewBuilder
    private var documentOutline: some View {
        let entries = session.project?.outline ?? []
        if entries.isEmpty {
            ContentUnavailableView {
                Label("No Outline", systemImage: "list.bullet.indent")
            } description: {
                Text("The chapters and sections of every file of the document appear here.")
            }
        } else {
            List(DocumentStructure.tree(from: entries), children: \.children, selection: $documentSelection) { node in
                OutlineRow(kind: node.entry.kind, title: node.entry.title, line: node.entry.line, fileName: isShown(node.entry.file) ? nil : node.entry.file.lastPathComponent)
            }
            .listStyle(.sidebar)
            .onAppear {
                followInDocument(entries)
            }
            .onChange(of: session.caretLine) {
                followInDocument(entries)
            }
            .onChange(of: session.currentDocument?.id) {
                followInDocument(entries)
            }
            .onChange(of: documentSelection) { _, newValue in
                guard let newValue, newValue != currentDocumentEntryID(entries),
                      let entry = entries.first(where: { nodeID(of: $0) == newValue }) else { return }
                session.revealOutlineEntry(entry)
            }
        }
    }

    private func isShown(_ file: URL) -> Bool {
        session.fileURL.map { Self.isSameFile($0, file) } ?? false
    }

    /// A quick comparison for the many entries of an outline; symbolic links are rare
    /// inside a project.
    private static func isSameFile(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.standardizedFileURL.path(percentEncoded: false) == rhs.standardizedFileURL.path(percentEncoded: false)
    }

    private func nodeID(of entry: DocumentOutlineEntry) -> DocumentOutlineNode.ID {
        DocumentOutlineNode(entry: entry, children: nil).id
    }

    /// The entry containing the insertion point: the last one before it in the shown file.
    private func currentDocumentEntryID(_ entries: [DocumentOutlineEntry]) -> DocumentOutlineNode.ID? {
        guard let fileURL = session.fileURL else { return nil }
        let line = session.caretLine
        return entries.last { $0.line <= line && Self.isSameFile($0.file, fileURL) }.map(nodeID(of:))
    }

    private func followInDocument(_ entries: [DocumentOutlineEntry]) {
        let id = currentDocumentEntryID(entries)
        guard documentSelection != id else { return }
        documentSelection = id
    }
}

private struct OutlineRow: View {
    var kind: OutlineItem.Kind
    var title: String
    var line: Int
    /// The file the item is in, when it isn't the one on screen, named in the tooltip.
    var fileName: String?

    var body: some View {
        Label {
            Text(title)
                .lineLimit(1)
                .truncationMode(.tail)
        } icon: {
            Image(systemName: kind.systemImage)
                .foregroundStyle(.secondary)
        }
        .help(fileName.map { String(localized: "\(kind.accessibilityName) · \($0), line \(line)") } ?? String(localized: "\(kind.accessibilityName) · Line \(line)"))
        .accessibilityLabel(String(localized: "\(kind.accessibilityName): \(title)"))
    }
}

/// Problems found while typing and reported by TeX. Clicking one shows its source.
struct IssuesSidebar: View {
    var session: DocumentSession

    @AppStorage(SettingsKey.showsWarnings) private var showsWarnings = AppSettings.showsWarnings
    @AppStorage(SettingsKey.showsBadBoxes) private var showsBadBoxes = AppSettings.showsBadBoxes

    private func visible(_ issues: [Issue]) -> [Issue] {
        issues.filter { issue in
            switch issue.severity {
            case .error: true
            case .warning: showsWarnings
            case .badBox: showsBadBoxes
            }
        }
    }

    var body: some View {
        let live = visible(session.liveIssues)
        let typeset = visible(session.issues)
        Group {
            if live.isEmpty && typeset.isEmpty {
                emptyState
            } else {
                List {
                    if !live.isEmpty {
                        Section {
                            ForEach(live) { issue in
                                issueButton(issue, showsFile: false)
                            }
                        } header: {
                            Text("Found While Typing · \(session.currentName)")
                        }
                    }
                    // TeX's issues, by file, in the order TeX reported them.
                    ForEach(groups(of: typeset)) { group in
                        Section {
                            ForEach(group.issues) { issue in
                                issueButton(issue, showsFile: false)
                            }
                        } header: {
                            Text(verbatim: group.name)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .fillsNavigator()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 6) {
                Toggle(isOn: $showsWarnings) {
                    Label("Warnings", systemImage: "exclamationmark.triangle")
                }
                .help("Show warnings")
                Toggle(isOn: $showsBadBoxes) {
                    Label("Bad Boxes", systemImage: "rectangle.badge.xmark")
                }
                .help("Show overfull and underfull boxes")
                Spacer()
                Button {
                    session.isShowingLog = true
                } label: {
                    Label("Show Log", systemImage: "doc.text.magnifyingglass")
                }
                .disabled(session.log.isEmpty && session.console.isEmpty)
                .help("Show the full TeX log")
            }
            .toggleStyle(.button)
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
            .controlSize(.small)
            .navigatorGlass()
            .padding(8)
        }
    }

    private func issueButton(_ issue: Issue, showsFile: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Button {
                session.reveal(issue)
            } label: {
                IssueRow(issue: issue, documentName: session.displayName, showsFile: showsFile)
            }
            .buttonStyle(.plain)
            if let fix = issue.fix {
                // Like an Xcode Fix-It.
                Button(fix.title) {
                    session.apply(fix)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help(fix.help)
            }
        }
    }

    /// Issues grouped by the file they're in, named by its path in the project.
    private func groups(of issues: [Issue]) -> [IssueGroup] {
        var order: [String] = []
        var grouped: [String: [Issue]] = [:]
        for issue in issues {
            let name = fileTitle(of: issue)
            if grouped[name] == nil {
                order.append(name)
            }
            grouped[name, default: []].append(issue)
        }
        return order.map { IssueGroup(name: $0, issues: grouped[$0] ?? []) }
    }

    private func fileTitle(of issue: Issue) -> String {
        switch issue.source {
        case .file(let url)?:
            if let folder = session.project?.folder {
                return PathUtilities.relativePath(of: url, from: folder)
            }
            return url.lastPathComponent
        case .currentDocument?:
            return session.displayName
        case nil:
            return String(localized: "TeX")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if session.allIssues.isEmpty && session.lastTypesetDate == nil {
            ContentUnavailableView {
                Label("Not Typeset Yet", systemImage: "doc.badge.gearshape")
            } description: {
                Text("Problems found as you type and while typesetting appear here.")
            }
        } else {
            ContentUnavailableView {
                Label("No Issues", systemImage: "checkmark.circle")
            } description: {
                Text(session.allIssues.isEmpty ? "TexLab and TeX found no problems." : "Hidden issues can be shown with the buttons below.")
            }
        }
    }
}

/// The issues of one file.
private struct IssueGroup: Identifiable {
    var name: String
    var issues: [Issue]

    var id: String { name }
}

private struct IssueRow: View {
    var issue: Issue
    var documentName: String
    /// Whether the row names the file, rather than its section in the list.
    var showsFile = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: issue.systemImage)
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(issue.severity == .badBox ? Color.secondary : Color.primary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(issue.displayMessage)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(locationDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(severityName): \(issue.displayMessage), \(locationDescription)")
        .accessibilityHint("Shows the source of this issue")
    }

    private var severityName: String {
        switch issue.severity {
        case .error: String(localized: "Error")
        case .warning: String(localized: "Warning")
        case .badBox: String(localized: "Bad box")
        }
    }

    private var locationDescription: String {
        if !showsFile {
            if let line = issue.line {
                return String(localized: "Line \(line)")
            }
            return issue.source == nil ? String(localized: "See the log") : String(localized: "No line")
        }
        let file = issue.fileName ?? documentName
        if let line = issue.line {
            return String(localized: "\(file), line \(line)")
        }
        return issue.fileName ?? String(localized: "No location")
    }
}
