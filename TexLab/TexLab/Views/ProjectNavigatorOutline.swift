//
//  ProjectNavigatorOutline.swift
//  TexLab
//

import AppKit
import Foundation
import SwiftUI

/// What the project navigator's list asks of the sidebar around it.
struct ProjectNavigatorActions {
    /// File ▸ New File in Project, in a folder, for a kind of file if given.
    var newFile: (URL, NewFileKind?) -> Void
    /// A new folder, which the list then names.
    var newFolder: (URL) -> Void
    /// Asks before moving items to the Trash.
    var moveToTrash: ([URL]) -> Void
    var showError: (Error) -> Void
    /// The folder asked to be renamed is being renamed.
    var didBeginRenaming: () -> Void
}

/// The project navigator's list: an AppKit outline view in the sidebar style, as Xcode's
/// navigators and the Finder's sidebar are.
///
/// It works as Xcode's does. Clicking a text file shows it in the editor, and the arrow
/// keys and type-select step through the files while the list keeps the keyboard; the
/// selection follows the file the editor shows. Double-click or ⌘↓ goes to the file —
/// images and PDFs open in their app — Return renames inline, ⌘⌫ moves to the Trash, and
/// the context menu acts on the clicked row or the selection. Files drag into the editor
/// to reference them, onto a folder to move them, and from the Finder to copy them in.
struct ProjectNavigatorOutline: NSViewRepresentable {
    var session: DocumentSession
    var project: ProjectSnapshot
    var filter: String
    /// The file the editor shows.
    var shownURL: URL?
    /// A newly made folder to name.
    var renameRequest: URL?
    var actions: ProjectNavigatorActions

    func makeCoordinator() -> ProjectNavigatorCoordinator {
        ProjectNavigatorCoordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let outlineView = NavigatorOutlineView()
        let scrollView = NSScrollView()
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        // SwiftUI places the list below the navigator bar already.
        scrollView.automaticallyAdjustsContentInsets = false
        context.coordinator.configuration = self
        context.coordinator.attach(outlineView)
        context.coordinator.update()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.configuration = self
        context.coordinator.update()
    }
}

/// A row of the navigator: a file or folder of the project. Rows keep their identity across
/// updates, so the list keeps its open folders and selection while the project changes.
final class NavigatorNode: NSObject {
    let key: String
    var title = ""
    var url: URL?
    var systemImage = "doc"
    /// What the file is, for its icon's colour and its description.
    var kind = ProjectFileKind.other
    /// The extension the name leaves out, as the icon stands for it; kept on renaming.
    var hiddenExtension: String?
    /// The file's folder, while filtering.
    var detail: String?
    var isFolder = false
    var isMain = false
    var children: [NavigatorNode] = []

    init(key: String) {
        self.key = key
        super.init()
    }

    nonisolated override func isEqual(_ object: Any?) -> Bool {
        (object as? NavigatorNode)?.key == key
    }

    nonisolated override var hash: Int {
        key.hashValue
    }

    var isExpandable: Bool {
        !children.isEmpty
    }
}

final class ProjectNavigatorCoordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate, NSMenuDelegate, NSTextFieldDelegate {
    var configuration: ProjectNavigatorOutline?
    private weak var outlineView: NavigatorOutlineView?

    private var roots: [NavigatorNode] = []
    private var nodes: [String: NavigatorNode] = [:]
    private var parents: [String: NavigatorNode] = [:]
    /// What the rows were built from, to rebuild them only when it changes.
    private var builtProject: ProjectSnapshot?
    private var builtFilter = ""
    private var followedURL: URL?
    private var autosaveFolder: String?
    private var isSelectingProgrammatically = false
    private var renaming: (node: NavigatorNode, isCancelled: Bool)?
    private var handledRenameRequest: URL?

    private var session: DocumentSession? {
        configuration?.session
    }

    // MARK: - Setting up

    func attach(_ outlineView: NavigatorOutlineView) {
        self.outlineView = outlineView
        outlineView.navigator = self
        outlineView.style = .sourceList
        outlineView.backgroundColor = .clear
        outlineView.headerView = nil
        outlineView.allowsMultipleSelection = true
        outlineView.allowsEmptySelection = true
        outlineView.floatsGroupRows = false
        outlineView.rowSizeStyle = .default
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.resizingMask = .autoresizingMask
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.target = self
        outlineView.doubleAction = #selector(openClickedRow(_:))
        let menu = NSMenu()
        menu.delegate = self
        outlineView.menu = menu
        outlineView.registerForDraggedTypes([.fileURL])
        outlineView.setDraggingSourceOperationMask([.copy, .move], forLocal: true)
        outlineView.setDraggingSourceOperationMask(.copy, forLocal: false)
        outlineView.setAccessibilityLabel(String(localized: "Project navigator"))
    }

    // MARK: - Updating

    func update() {
        guard let configuration, let outlineView else { return }
        // Reloading would end a rename in progress; the rows catch up when it's done.
        if renaming == nil, configuration.project != builtProject || configuration.filter != builtFilter {
            let selectedKeys = Set(selectedNodes().map(\.key))
            rebuild(configuration.project, filter: configuration.filter)
            outlineView.reloadData()
            restoreExpandedFolders(of: configuration.project)
            select(selectedKeys.compactMap { nodes[$0] })
            followShownFile(force: true)
        } else {
            followShownFile(force: false)
        }
        if let request = configuration.renameRequest, request != handledRenameRequest,
           let node = nodes["item:" + Self.plainPath(request)] {
            handledRenameRequest = request
            DispatchQueue.main.async { [weak self] in
                self?.beginRenaming(node)
                self?.configuration?.actions.didBeginRenaming()
            }
        }
    }

    /// Folders open last time stay open, per project.
    private func restoreExpandedFolders(of project: ProjectSnapshot) {
        guard let outlineView else { return }
        let folder = Self.plainPath(project.folder)
        guard folder != autosaveFolder else { return }
        autosaveFolder = folder
        outlineView.autosaveExpandedItems = true
        outlineView.autosaveName = "TexLab Navigator \(folder)"
    }

    private func rebuild(_ project: ProjectSnapshot, filter: String) {
        builtProject = project
        builtFilter = filter
        var used: [String: NavigatorNode] = [:]
        var newParents: [String: NavigatorNode] = [:]
        let mainPath = project.mainFile.map(Self.plainPath)

        func node(_ key: String) -> NavigatorNode {
            let node = nodes[key] ?? NavigatorNode(key: key)
            node.children = []
            node.detail = nil
            node.isMain = false
            used[key] = node
            return node
        }

        func item(_ file: ProjectFile) -> NavigatorNode {
            let path = Self.plainPath(file.url)
            let item = node("item:" + path)
            item.title = file.isFolder ? file.name : ProjectFileKind.displayName(of: file.url)
            item.url = file.url
            item.isFolder = file.isFolder
            item.kind = file.kind
            item.hiddenExtension = !file.isFolder && file.kind.hidesExtension ? file.url.pathExtension : nil
            item.systemImage = file.isFolder ? file.kind.systemImage : ProjectFileKind.systemImage(for: file.url)
            item.isMain = path == mainPath
            return item
        }

        func tree(_ file: ProjectFile) -> NavigatorNode {
            let parent = item(file)
            for child in file.children ?? [] {
                let childNode = tree(child)
                parent.children.append(childNode)
                newParents[childNode.key] = parent
            }
            return parent
        }

        if !filter.isEmpty {
            roots = matchingFiles(in: project, filter: filter).map { file in
                let match = item(file)
                let folder = PathUtilities.relativePath(of: file.url.deletingLastPathComponent(), from: project.folder)
                match.detail = folder.isEmpty || folder == "." ? nil : folder
                return match
            }
        } else {
            // The folder as it is; the Outline navigator has the document's structure.
            roots = (project.tree.children ?? []).map(tree)
        }
        nodes = used
        parents = newParents
    }

    /// Files whose name or path contains the filter, in path order.
    private func matchingFiles(in project: ProjectSnapshot, filter: String) -> [ProjectFile] {
        project.tree.files
            .map { file in (file, PathUtilities.relativePath(of: file.url, from: project.folder)) }
            .filter { file, path in
                file.name.localizedStandardContains(filter) || path.localizedStandardContains(filter)
            }
            .sorted { $0.1.localizedStandardCompare($1.1) == .orderedAscending }
            .map(\.0)
    }

    /// A path to tell rows apart by, without a folder's trailing slash.
    static func plainPath(_ url: URL) -> String {
        var path = url.standardizedFileURL.path(percentEncoded: false)
        if path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }

    // MARK: - Selection

    private func selectedNodes() -> [NavigatorNode] {
        guard let outlineView else { return [] }
        return outlineView.selectedRowIndexes.compactMap { outlineView.item(atRow: $0) as? NavigatorNode }
    }

    private func select(_ selection: [NavigatorNode]) {
        guard let outlineView else { return }
        let rows = IndexSet(selection.map { outlineView.row(forItem: $0) }.filter { $0 >= 0 })
        isSelectingProgrammatically = true
        outlineView.selectRowIndexes(rows, byExtendingSelection: false)
        isSelectingProgrammatically = false
    }

    /// Selects the file the editor shows, unless it's among the selection already, opening
    /// folders to reveal it.
    private func followShownFile(force: Bool) {
        guard let outlineView, let url = configuration?.shownURL else { return }
        guard force || url != followedURL else { return }
        followedURL = url
        let path = SourceMap.canonicalPath(url)
        guard !selectedNodes().contains(where: { $0.url.map(SourceMap.canonicalPath) == path }) else { return }
        guard let node = node(showing: url) else { return }
        reveal(node)
        let row = outlineView.row(forItem: node)
        guard row >= 0 else { return }
        select([node])
        outlineView.scrollRowToVisible(row)
    }

    private func node(showing url: URL) -> NavigatorNode? {
        if let item = nodes["item:" + Self.plainPath(url)] {
            return item
        }
        // The same file by another path, through a symbolic link.
        let canonical = SourceMap.canonicalPath(url)
        return nodes.values.first { $0.url.map(SourceMap.canonicalPath) == canonical }
    }

    /// Opens the folders that contain `node`.
    private func reveal(_ node: NavigatorNode) {
        guard let outlineView else { return }
        var ancestors: [NavigatorNode] = []
        var current = parents[node.key]
        while let parent = current {
            ancestors.append(parent)
            current = parents[parent.key]
        }
        for ancestor in ancestors.reversed() {
            outlineView.expandItem(ancestor)
        }
    }

    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !isSelectingProgrammatically, let session else { return }
        let selection = selectedNodes()
        // One text file chosen: show it, as Xcode does. The list keeps the keyboard, so the
        // arrow keys go on through the files.
        guard selection.count == 1, let node = selection.first, let url = node.url, !node.isFolder,
              ProjectFileKind(url: url, isDirectory: false).opensInTexLab, !session.isShowing(url) else { return }
        followedURL = url
        session.openProjectFile(url)
    }

    // MARK: - Opening

    @objc private func openClickedRow(_ sender: Any?) {
        guard let outlineView, outlineView.clickedRow >= 0,
              let node = outlineView.item(atRow: outlineView.clickedRow) as? NavigatorNode else { return }
        if node.isFolder && node.isExpandable {
            if outlineView.isItemExpanded(node) {
                outlineView.collapseItem(node)
            } else {
                outlineView.expandItem(node)
            }
            return
        }
        if let url = node.url, !node.isFolder {
            open(url, focusingEditor: true)
        }
    }

    /// Goes to a file: text in the editor, other files in the app that opens them.
    private func open(_ url: URL, focusingEditor: Bool) {
        guard let session else { return }
        guard ProjectFileKind(url: url, isDirectory: false).opensInTexLab else {
            NSWorkspace.shared.open(url)
            return
        }
        session.openProjectFile(url)
        if focusingEditor {
            session.editor.focus()
        }
    }

    /// ⌘↓: goes to the selected file.
    func openSelection() {
        let files = selectedNodes().filter { !$0.isFolder }.compactMap(\.url)
        guard !files.isEmpty else {
            NSSound.beep()
            return
        }
        for file in files {
            open(file, focusingEditor: files.count == 1)
        }
    }

    // MARK: - Renaming

    /// Return: renames the selected row in place.
    func renameSelection() {
        let selection = selectedNodes().filter { $0.url != nil }
        guard selection.count == 1, let node = selection.first else {
            NSSound.beep()
            return
        }
        beginRenaming(node)
    }

    private func beginRenaming(_ node: NavigatorNode) {
        guard let outlineView, node.url != nil else { return }
        reveal(node)
        let row = outlineView.row(forItem: node)
        guard row >= 0 else { return }
        select([node])
        outlineView.scrollRowToVisible(row)
        guard let cell = outlineView.view(atColumn: 0, row: row, makeIfNecessary: true) as? NavigatorCellView else { return }
        renaming = (node, false)
        cell.beginEditing(delegate: self)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard commandSelector == #selector(NSResponder.cancelOperation(_:)), renaming != nil else { return false }
        // Esc leaves the name as it was.
        renaming?.isCancelled = true
        outlineView?.window?.makeFirstResponder(outlineView)
        return true
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField, let state = renaming else { return }
        renaming = nil
        var view: NSView? = field
        while let current = view, !(current is NavigatorCellView) {
            view = current.superview
        }
        (view as? NavigatorCellView)?.endEditing()
        defer {
            // Rows that changed while the name was edited.
            update()
        }
        let movement = notification.userInfo?["NSTextMovement"] as? Int
        if movement == NSTextMovement.return.rawValue {
            // Return keeps the keyboard in the list, as in the Finder.
            outlineView?.window?.makeFirstResponder(outlineView)
        }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !state.isCancelled, !name.isEmpty, name != state.node.title, let url = state.node.url, let session else {
            field.stringValue = state.node.title
            return
        }
        guard !name.contains("/"), !name.hasPrefix(".") else {
            field.stringValue = state.node.title
            NSSound.beep()
            return
        }
        var newName = name
        if let hidden = state.node.hiddenExtension, !hidden.isEmpty,
           ProjectFileKind(url: URL(filePath: name), isDirectory: false) == .other {
            // The extension isn't shown, so it stays unless another one is typed.
            newName += "." + hidden
        }
        guard newName != url.lastPathComponent else {
            field.stringValue = state.node.title
            return
        }
        let actions = configuration?.actions
        Task {
            do {
                try await session.renameProjectFile(url, to: newName)
            } catch {
                field.stringValue = state.node.title
                actions?.showError(error)
            }
        }
    }

    // MARK: - Moving to the Trash

    /// ⌘⌫: asks to move the selected items to the Trash.
    func trashSelection() {
        let urls = selectedNodes().compactMap(\.url)
        guard !urls.isEmpty else {
            NSSound.beep()
            return
        }
        configuration?.actions.moveToTrash(Self.unique(urls))
    }

    private static func unique(_ urls: [URL]) -> [URL] {
        var seen: Set<String> = []
        return urls.filter { seen.insert(plainPath($0)).inserted }
    }

    // MARK: - Data source

    private func children(of item: Any?) -> [NavigatorNode] {
        (item as? NavigatorNode)?.children ?? roots
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        children(of: item).count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        children(of: item)[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as? NavigatorNode)?.isExpandable ?? false
    }

    func outlineView(_ outlineView: NSOutlineView, persistentObjectForItem item: Any?) -> Any? {
        (item as? NavigatorNode)?.key
    }

    func outlineView(_ outlineView: NSOutlineView, itemForPersistentObject object: Any) -> Any? {
        (object as? String).flatMap { nodes[$0] }
    }

    // MARK: - Rows

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? NavigatorNode else { return nil }
        let cell = (outlineView.makeView(withIdentifier: NavigatorCellView.identifier, owner: self) as? NavigatorCellView) ?? NavigatorCellView()
        cell.configure(with: node)
        return cell
    }

    func outlineView(_ outlineView: NSOutlineView, typeSelectStringFor tableColumn: NSTableColumn?, item: Any) -> String? {
        (item as? NavigatorNode)?.title
    }

    // MARK: - Context menu

    /// The rows a context menu acts on: the selection if the clicked row is in it, or the
    /// clicked row; none for a click below the rows.
    private func menuTargets() -> [NavigatorNode] {
        guard let outlineView, outlineView.clickedRow >= 0,
              let clicked = outlineView.item(atRow: outlineView.clickedRow) as? NavigatorNode else { return [] }
        if outlineView.selectedRowIndexes.contains(outlineView.clickedRow) {
            return selectedNodes()
        }
        return [clicked]
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        guard let configuration else { return }
        let session = configuration.session
        let project = configuration.project
        let actions = configuration.actions
        let targets = menuTargets()
        let urls = Self.unique(targets.compactMap(\.url))
        let files = Self.unique(targets.filter { !$0.isFolder }.compactMap(\.url))
        let folder = targetFolder(for: targets, in: project)

        if !files.isEmpty {
            let title = files.count == 1 ? String(localized: "Open") : String(localized: "Open \(files.count) Files")
            menu.addItem(ActionMenuItem(title) { [weak self] in
                for file in files {
                    self?.open(file, focusingEditor: files.count == 1)
                }
            })
            if files.count == 1, let file = files.first, ProjectFileKind(url: file, isDirectory: false).opensInTexLab {
                menu.addItem(ActionMenuItem(String(localized: "Open in New Window")) {
                    session.openProjectFile(file, inNewWindow: true)
                })
            }
            if files.count == 1, let file = files.first, !session.isShowing(file),
               ProjectReferences.reference(to: file, from: project.folder) != nil {
                menu.addItem(ActionMenuItem(String(localized: "Insert Reference at Insertion Point")) {
                    session.insertReference(to: file)
                })
            }
            if files.count == 1, let file = files.first, ProjectFileKind(url: file, isDirectory: false) == .latex,
               !session.isShowing(file), project.mainFile.map({ SourceMap.canonicalPath($0) != SourceMap.canonicalPath(file) }) ?? true {
                menu.addItem(ActionMenuItem(String(localized: "Use as Main File for This Document")) {
                    session.useAsMainFile(file)
                })
            }
            menu.addItem(.separator())
        }

        menu.addItem(ActionMenuItem(String(localized: "New File…")) {
            actions.newFile(folder, nil)
        })
        menu.addItem(ActionMenuItem(String(localized: "Add Images…")) {
            actions.newFile(folder, .image)
        })
        menu.addItem(ActionMenuItem(String(localized: "New Folder")) {
            actions.newFolder(folder)
        })

        guard !urls.isEmpty else { return }
        menu.addItem(.separator())
        menu.addItem(ActionMenuItem(urls.count == 1 ? String(localized: "Show in Finder") : String(localized: "Show \(urls.count) Items in Finder")) {
            session.showInFinder(urls)
        })
        menu.addItem(.separator())
        let copyPath = ActionMenuItem(urls.count == 1 ? String(localized: "Copy Path") : String(localized: "Copy Paths")) {
            Pasteboard.copy(urls.map { PathUtilities.relativePath(of: $0, from: project.folder) }.joined(separator: "\n"))
        }
        copyPath.toolTip = String(localized: "The path from the main file’s folder, as \\includegraphics and \\input expect it")
        menu.addItem(copyPath)
        menu.addItem(ActionMenuItem(urls.count == 1 ? String(localized: "Copy Full Path") : String(localized: "Copy Full Paths")) {
            Pasteboard.copy(urls.map(\.filePath).joined(separator: "\n"))
        })
        let references = urls.compactMap { ProjectReferences.reference(to: $0, from: project.folder) }
        if !references.isEmpty {
            let copyReference = ActionMenuItem(references.count == 1 ? String(localized: "Copy LaTeX Reference") : String(localized: "Copy LaTeX References")) {
                Pasteboard.copy(references.joined(separator: "\n"))
            }
            copyReference.toolTip = String(localized: "The command that uses the file, such as \\includegraphics{…} or \\input{…}")
            menu.addItem(copyReference)
        }
        menu.addItem(.separator())
        if targets.count == 1, let node = targets.first {
            menu.addItem(ActionMenuItem(String(localized: "Rename")) { [weak self] in
                self?.beginRenaming(node)
            })
        }
        menu.addItem(ActionMenuItem(String(localized: "Move to Trash")) {
            actions.moveToTrash(urls)
        })
    }

    /// The folder a new item goes in: the folder clicked, or the clicked file's folder, or
    /// the project folder.
    private func targetFolder(for targets: [NavigatorNode], in project: ProjectSnapshot) -> URL {
        guard let first = targets.first, let url = first.url else { return project.folder }
        return first.isFolder ? url : url.deletingLastPathComponent()
    }

    // MARK: - Dragging

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        guard let url = (item as? NavigatorNode)?.url else { return nil }
        return url as NSURL
    }

    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        guard configuration?.filter.isEmpty == true, let target = dropTarget(for: item) else { return [] }
        let urls = draggedURLs(info)
        guard !urls.isEmpty else { return [] }
        let isFromHere = (info.draggingSource as? NSOutlineView) === outlineView
        if isFromHere {
            let destination = Self.plainPath(target.folder)
            let movable = urls.filter { url in
                let path = Self.plainPath(url)
                // Not into itself or a folder inside it, nor where it is already.
                return destination != path && !destination.hasPrefix(path + "/")
                    && Self.plainPath(url.deletingLastPathComponent()) != destination
            }
            guard movable.count == urls.count else { return [] }
        }
        outlineView.setDropItem(target.row, dropChildIndex: NSOutlineViewDropOnItemIndex)
        return isFromHere ? .move : .copy
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        guard let configuration, let target = dropTarget(for: item) else { return false }
        let urls = draggedURLs(info)
        guard !urls.isEmpty else { return false }
        let session = configuration.session
        let actions = configuration.actions
        if (info.draggingSource as? NSOutlineView) === outlineView {
            Task {
                do {
                    try await session.moveProjectItems(urls, into: target.folder)
                } catch {
                    actions.showError(error)
                }
            }
        } else {
            do {
                try session.copyIntoProject(urls, folder: target.folder)
            } catch {
                actions.showError(error)
                return false
            }
        }
        return true
    }

    /// The folder a drop on `item` puts files in, and the row to highlight: a folder, the
    /// folder of a file, or the project folder.
    private func dropTarget(for item: Any?) -> (folder: URL, row: NavigatorNode?)? {
        guard let project = configuration?.project else { return nil }
        guard let node = item as? NavigatorNode else {
            return (project.folder, nil)
        }
        if node.isFolder, let url = node.url {
            return (url, node)
        }
        if let parent = parents[node.key], parent.isFolder, let url = parent.url {
            return (url, parent)
        }
        return (project.folder, nil)
    }

    private func draggedURLs(_ info: NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
    }
}

/// The outline view, with the Finder's keys: Return renames, ⌘⌫ moves to the Trash and
/// ⌘↓ opens.
final class NavigatorOutlineView: NSOutlineView {
    weak var navigator: ProjectNavigatorCoordinator?

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let returnKey: UInt16 = 36
        let enterKey: UInt16 = 76
        let deleteKey: UInt16 = 51
        let downArrowKey: UInt16 = 125
        if (event.keyCode == returnKey || event.keyCode == enterKey) && modifiers.isEmpty {
            navigator?.renameSelection()
        } else if event.keyCode == deleteKey && modifiers == .command {
            navigator?.trashSelection()
        } else if event.keyCode == downArrowKey && modifiers == .command {
            navigator?.openSelection()
        } else {
            super.keyDown(with: event)
        }
    }
}

/// A file or folder: its icon and name, its folder in grey while filtering, and a Main
/// badge.
final class NavigatorCellView: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("NavigatorItem")

    private let icon = NSImageView()
    private let name = NSTextField(labelWithString: "")
    private let detail = NSTextField(labelWithString: "")
    private let badge = BadgeView(text: String(localized: "Main"))
    private var isFolder = false
    private var hidesExtension = false
    private var tint = NSColor.secondaryLabelColor

    init() {
        super.init(frame: .zero)
        identifier = Self.identifier
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        icon.imageScaling = .scaleProportionallyDown
        name.lineBreakMode = .byTruncatingMiddle
        name.cell?.isScrollable = false
        detail.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingTail
        textField = name
        imageView = icon

        let stack = NSStackView(views: [icon, name, badge, detail])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        // The name stays whole as long as it can; the detail gives way first.
        name.setContentCompressionResistancePriority(.defaultLow + 1, for: .horizontal)
        name.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        detail.setContentCompressionResistancePriority(.defaultLow - 1, for: .horizontal)
        detail.setContentHuggingPriority(.defaultLow, for: .horizontal)
        badge.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 18),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -4),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("Navigator rows are made in code")
    }

    func configure(with node: NavigatorNode) {
        isFolder = node.isFolder
        hidesExtension = node.hiddenExtension != nil
        tint = node.kind.tint
        icon.image = NSImage(systemSymbolName: node.systemImage, accessibilityDescription: nil)
        name.stringValue = node.title
        detail.stringValue = node.detail ?? ""
        detail.isHidden = node.detail == nil
        badge.isHidden = !node.isMain
        // The whole name, extension and all, and where the file is.
        toolTip = node.url?.filePath
        // The icon says what the file is; VoiceOver says it in words.
        var description = node.title
        if let url = node.url, !node.isFolder {
            description += ", " + ProjectFileKind.typeName(of: url)
        }
        if node.isMain {
            description += ", " + String(localized: "main file")
        }
        setAccessibilityLabel(description)
        updateColors()
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            updateColors()
        }
    }

    /// Each kind's colour gives way to the selection's when it's emphasized.
    private func updateColors() {
        let isEmphasized = backgroundStyle == .emphasized
        icon.contentTintColor = isEmphasized ? .alternateSelectedControlTextColor : tint
        detail.textColor = isEmphasized ? .alternateSelectedControlTextColor : .secondaryLabelColor
        badge.isEmphasized = isEmphasized
    }

    /// Makes the name editable in place, with the part before the extension selected, as
    /// the Finder does — all of it when the extension isn't shown.
    func beginEditing(delegate: NSTextFieldDelegate) {
        name.isEditable = true
        name.isSelectable = true
        name.delegate = delegate
        name.drawsBackground = true
        name.backgroundColor = .textBackgroundColor
        window?.makeFirstResponder(name)
        let title = name.stringValue as NSString
        let length = isFolder || hidesExtension ? title.length : (title.deletingPathExtension as NSString).length
        name.currentEditor()?.selectedRange = NSRange(location: 0, length: length)
    }

    func endEditing() {
        name.isEditable = false
        name.isSelectable = false
        name.drawsBackground = false
        name.delegate = nil
    }
}

/// A small rounded label, such as Main beside the main file.
final class BadgeView: NSView {
    private let label: NSTextField
    var isEmphasized = false {
        didSet {
            label.textColor = isEmphasized ? .alternateSelectedControlTextColor : .secondaryLabelColor
            needsDisplay = true
        }
    }

    init(text: String) {
        label = NSTextField(labelWithString: text)
        super.init(frame: .zero)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize - 1, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("Badges are made in code")
    }

    override func draw(_ dirtyRect: NSRect) {
        let color = isEmphasized ? NSColor.alternateSelectedControlTextColor.withAlphaComponent(0.25) : NSColor.quaternaryLabelColor
        color.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2).fill()
    }
}

/// A menu item that runs a closure.
final class ActionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("Menu items are made in code")
    }

    @objc private func run() {
        handler()
    }
}
