//
//  SidebarView.swift
//  TexLab
//

import Foundation
import SwiftUI

/// The sidebar: the document outline, or the issues from the latest typesetting.
struct SidebarView: View {
    @Bindable var session: DocumentSession

    var body: some View {
        Group {
            switch session.sidebarTab {
            case .outline:
                OutlineSidebar(session: session)
            case .issues:
                IssuesSidebar(session: session)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Sidebar", selection: $session.sidebarTab) {
                Text("Outline").tag(SidebarTab.outline)
                Text(issuesTitle).tag(SidebarTab.issues)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var issuesTitle: String {
        let count = session.errorCount + session.warningCount
        return count > 0 ? String(localized: "Issues (\(count))") : String(localized: "Issues")
    }
}

/// The document's structure. Selecting an item jumps to it in the editor and preview; the
/// selection follows the insertion point, so the outline always shows where you are.
struct OutlineSidebar: View {
    var session: DocumentSession

    @State private var selection: OutlineItem.ID?

    var body: some View {
        if session.outline.isEmpty {
            ContentUnavailableView {
                Label("No Outline", systemImage: "list.bullet.indent")
            } description: {
                Text("Sections, frames, figures and tables appear here as you write them.")
            }
        } else {
            List(session.outline, children: \.children, selection: $selection) { item in
                OutlineRow(item: item)
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
}

private struct OutlineRow: View {
    var item: OutlineItem

    var body: some View {
        Label {
            Text(item.title)
                .lineLimit(1)
                .truncationMode(.tail)
        } icon: {
            Image(systemName: item.kind.systemImage)
                .foregroundStyle(.secondary)
        }
        .help(String(localized: "\(item.kind.accessibilityName) · Line \(item.line)"))
        .accessibilityLabel(String(localized: "\(item.kind.accessibilityName): \(item.title)"))
    }
}

/// Problems reported by TeX. Clicking one shows its source.
struct IssuesSidebar: View {
    var session: DocumentSession

    @AppStorage(SettingsKey.showsWarnings) private var showsWarnings = AppSettings.showsWarnings
    @AppStorage(SettingsKey.showsBadBoxes) private var showsBadBoxes = AppSettings.showsBadBoxes

    private var visibleIssues: [Issue] {
        session.issues.filter { issue in
            switch issue.severity {
            case .error: true
            case .warning: showsWarnings
            case .badBox: showsBadBoxes
            }
        }
    }

    var body: some View {
        Group {
            if visibleIssues.isEmpty {
                emptyState
            } else {
                List(visibleIssues) { issue in
                    Button {
                        session.reveal(issue)
                    } label: {
                        IssueRow(issue: issue, documentName: session.displayName)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.sidebar)
            }
        }
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
                .help("Show the full TeX log")
            }
            .toggleStyle(.button)
            .buttonStyle(.borderless)
            .labelStyle(.iconOnly)
            .controlSize(.small)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.bar)
            .overlay(alignment: .top) {
                Divider()
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if session.status == .idle || session.status == .running && session.lastTypesetDate == nil {
            ContentUnavailableView {
                Label("Not Typeset Yet", systemImage: "doc.badge.gearshape")
            } description: {
                Text("Problems TeX finds while typesetting appear here.")
            }
        } else {
            ContentUnavailableView {
                Label("No Issues", systemImage: "checkmark.circle")
            } description: {
                Text(session.issues.isEmpty ? "TeX found no problems." : "Hidden issues can be shown with the buttons below.")
            }
        }
    }
}

private struct IssueRow: View {
    var issue: Issue
    var documentName: String

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
        let file = issue.fileName ?? documentName
        if let line = issue.line {
            return String(localized: "\(file), line \(line)")
        }
        return issue.fileName ?? String(localized: "No location")
    }
}
