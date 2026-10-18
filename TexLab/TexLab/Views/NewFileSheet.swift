//
//  NewFileSheet.swift
//  TexLab
//

import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// File ▸ New File in Project, like Xcode's New File: choose what to make from the list —
/// a part of the document, an empty file, a figure, a table, a TikZ drawing, images from
/// the Mac, a document from a template, a bibliography or a package — then fill in what it
/// needs. Each is set up to use: a figure comes in a figure environment with its picture,
/// caption and label, and goes in where you're writing.
struct NewFileSheet: View {
    var session: DocumentSession
    @Environment(\.dismiss) private var dismiss
    /// The kind chosen last time, which the sheet starts with.
    @AppStorage("newFileKind") private var lastKind: NewFileKind = .chapter

    @State private var kind: NewFileKind = .chapter
    @State private var name = ""
    @State private var folder: URL?
    /// Whether the folder was chosen, rather than suggested for the kind of file.
    @State private var isFolderChosen = false
    @State private var usesFile = true
    @State private var caption = ""
    @State private var images: [URL] = []
    @State private var thumbnail: NSImage?
    @State private var isChoosingImages = false
    @State private var rows = 3
    @State private var columns = 3
    @State private var template: DocumentTemplate = .article
    @State private var errorMessage: String?
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                kindList
                    .frame(width: 210)
                Divider()
                details
            }
            Divider()
            footer
        }
        .frame(width: 680, height: 470)
        .fileImporter(isPresented: $isChoosingImages, allowedContentTypes: [.image, .pdf], allowsMultipleSelection: kind == .image) { result in
            if case .success(let urls) = result, !urls.isEmpty {
                choose(urls)
            }
        }
        .onAppear(perform: start)
        .onChange(of: kind) { oldKind, newKind in
            errorMessage = nil
            // Keep a name the user typed; replace the suggestion.
            if name.isEmpty || name == oldKind.defaultName || name == pictureName {
                name = newKind == .figure ? pictureName ?? newKind.defaultName : newKind.defaultName
            }
            if !isFolderChosen {
                folder = pickerFolder(for: suggestedFolder(for: newKind))
            }
            if newKind != .image && images.count > 1 {
                images = Array(images.prefix(1))
            }
        }
    }

    // MARK: - Kinds

    private var kindList: some View {
        List(selection: $kind) {
            ForEach(NewFileKind.Group.allCases) { group in
                Section(group.title) {
                    ForEach(NewFileKind.allCases.filter { $0.group == group }) { kind in
                        Label(kind.title, systemImage: kind.systemImage)
                            .tag(kind)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Details

    private var details: some View {
        Form {
            Section {
                if kind != .image {
                    TextField("Name", text: $name, prompt: Text(kind.defaultName))
                        .focused($isNameFocused)
                }
                switch kind {
                case .figure:
                    picture
                    captionField
                case .table:
                    captionField
                    stepper("Rows", value: $rows, in: 1...40)
                    stepper("Columns", value: $columns, in: 1...12)
                case .drawing:
                    captionField
                case .image:
                    imageList
                case .document:
                    Picker("Template", selection: $template) {
                        ForEach(DocumentTemplate.allCases) { template in
                            Label(template.title, systemImage: template.systemImage).tag(template)
                        }
                    }
                default:
                    EmptyView()
                }
            } header: {
                header
            } footer: {
                if kind == .document {
                    Text(template.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if kind == .figure && images.isEmpty {
                    Text("Without a picture, the figure has a frame to replace with one later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let project = session.project {
                Section {
                    Picker("Folder", selection: Binding(get: { folder }, set: { newFolder in
                        folder = newFolder
                        isFolderChosen = true
                    })) {
                        ForEach(project.tree.folders, id: \.url) { item in
                            Text(verbatim: folderTitle(item.url, in: project)).tag(Optional(item.url))
                        }
                    }
                    if let path = newFilePath(in: project) {
                        LabeledContent("File") {
                            Text(verbatim: path)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }
                    }
                    if let description = useDescription(in: project) {
                        Toggle(description, isOn: $usesFile)
                            .disabled(!canUseFile(in: project))
                    }
                } footer: {
                    if kind.reference == .insertionPoint && !session.acceptsFloats {
                        Text("Show a LaTeX file in the editor to insert it there.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: kind.systemImage)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.tint)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(kind.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(kind.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .textCase(nil)
        .padding(.bottom, 6)
    }

    private var captionField: some View {
        TextField("Caption", text: $caption, prompt: Text(verbatim: defaultCaption))
    }

    /// The caption a figure or table gets when none is typed: its name, as a sentence.
    private var defaultCaption: String {
        NewFileKind.title(for: trimmedName.isEmpty ? kind.defaultName : trimmedName) + "."
    }

    private var picture: some View {
        LabeledContent("Picture") {
            HStack(spacing: 10) {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 64, maxHeight: 44)
                        .accessibilityHidden(true)
                }
                Text(verbatim: images.first?.lastPathComponent ?? String(localized: "None"))
                    .foregroundStyle(images.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button("Choose…") {
                    isChoosingImages = true
                }
            }
        }
    }

    private var imageList: some View {
        LabeledContent("Images") {
            VStack(alignment: .trailing, spacing: 4) {
                if images.isEmpty {
                    Text("None")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(images.prefix(4), id: \.self) { url in
                        Text(verbatim: url.lastPathComponent)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    if images.count > 4 {
                        Text("and \(images.count - 4) more")
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Choose…") {
                    isChoosingImages = true
                }
            }
        }
    }

    private func stepper(_ title: LocalizedStringKey, value: Binding<Int>, in range: ClosedRange<Int>) -> some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                Text(verbatim: "\(value.wrappedValue)")
                    .monospacedDigit()
                Stepper(title, value: value, in: range)
                    .labelsHidden()
            }
        }
    }

    // MARK: - Using the file

    /// What the toggle does, or nil if this kind of file isn't used from anywhere.
    private func useDescription(in project: ProjectSnapshot) -> String? {
        let mainFileName = project.mainFile?.lastPathComponent ?? session.fileURL?.lastPathComponent ?? ""
        let shownFileName = session.fileURL?.lastPathComponent ?? String(localized: "the document")
        switch kind.reference {
        case .mainFile:
            guard project.mainFile != nil else { return nil }
            if kind == .empty && !isLaTeXName {
                return nil
            }
            return kind.referenceDescription(mainFileName: mainFileName, shownFileName: shownFileName)
        case .insertionPoint:
            return kind.referenceDescription(mainFileName: mainFileName, shownFileName: shownFileName)
        case .none:
            return nil
        }
    }

    private func canUseFile(in project: ProjectSnapshot) -> Bool {
        switch kind.reference {
        case .mainFile: project.mainFile != nil && (kind != .empty || isLaTeXName)
        case .insertionPoint: session.acceptsFloats
        case .none: false
        }
    }

    /// Whether an empty file is a LaTeX file, to input: one named without an extension, or
    /// with .tex.
    private var isLaTeXName: Bool {
        let pathExtension = (trimmedName as NSString).pathExtension.lowercased()
        return pathExtension.isEmpty || pathExtension == "tex"
    }

    // MARK: - Names and folders

    private var trimmedName: String {
        var trimmed = name.trimmingCharacters(in: .whitespaces)
        let suffix = "." + kind.fileExtension
        if kind != .empty && trimmed.lowercased().hasSuffix(suffix) {
            trimmed = String(trimmed.dropLast(suffix.count))
        }
        return trimmed
    }

    /// The new file's path in the project, as the sheet shows it.
    private func newFilePath(in project: ProjectSnapshot) -> String? {
        guard kind != .image, let folder, !trimmedName.isEmpty else { return nil }
        var url = folder.appending(path: trimmedName)
        if kind != .empty || url.pathExtension.isEmpty {
            url = url.appendingPathExtension(kind.fileExtension)
        }
        return PathUtilities.relativePath(of: url, from: project.folder)
    }

    /// Why the name won't do, or nil if it will.
    private var nameProblem: String? {
        guard kind != .image else { return nil }
        let name = trimmedName
        if name.hasPrefix(".") {
            return String(localized: "A name can’t begin with a period.")
        }
        if name.contains("/") || name.contains(":") {
            return String(localized: "A name can’t contain “/” or “:”.")
        }
        // TeX reads these as commands, comments or groups in \input and \usepackage.
        if kind != .empty || isLaTeXName, let character = name.first(where: { "\\{}%#$&^~".contains($0) }) {
            return String(localized: "A LaTeX file’s name can’t contain “\(String(character))”.")
        }
        return nil
    }

    private var isValid: Bool {
        guard folder != nil else { return false }
        if kind == .image {
            return !images.isEmpty
        }
        return !trimmedName.isEmpty && nameProblem == nil
    }

    /// The name a figure takes from its picture: “Results 2026.png” → “results-2026”.
    private var pictureName: String? {
        guard let picture = images.first else { return nil }
        let key = NewFileKind.labelKey(for: picture.deletingPathExtension().lastPathComponent)
        return key.isEmpty ? nil : key
    }

    /// Where a file of `kind` goes unless a folder is chosen: with others like it, in the
    /// folders the templates have — Sections or Chapters for parts, Figures for pictures and
    /// drawings, Tables for tables — and anything else in the project folder.
    private func suggestedFolder(for kind: NewFileKind) -> URL? {
        guard let project = session.project else { return nil }
        let names: [String]
        switch kind {
        case .chapter: names = ["sections", "chapters", "lectures", "slides"]
        case .figure, .drawing, .image: names = ["figures", "images", "graphics", "img", "pictures"]
        case .table: names = ["tables", "figures"]
        default: names = []
        }
        let folders = (project.tree.children ?? []).filter(\.isFolder)
        for name in names {
            if let match = folders.first(where: { $0.name.lowercased() == name }) {
                return match.url
            }
        }
        return project.folder
    }

    /// The picker's own entry for `url`, so the picker shows the choice.
    private func pickerFolder(for url: URL?) -> URL? {
        guard let project = session.project else { return url }
        return project.tree.folders.first { item in
            url.map { SourceMap.canonicalPath($0) == SourceMap.canonicalPath(item.url) } ?? false
        }?.url ?? project.folder
    }

    private func folderTitle(_ url: URL, in project: ProjectSnapshot) -> String {
        if SourceMap.canonicalPath(url) == SourceMap.canonicalPath(project.folder) {
            return String(localized: "\(project.folder.lastPathComponent) (project folder)")
        }
        return PathUtilities.relativePath(of: url, from: project.folder)
    }

    // MARK: - Creating

    private var footer: some View {
        HStack {
            if let message = errorMessage ?? nameProblem {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button("Cancel", role: .cancel) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            Button(kind == .image ? "Add" : "Create") {
                create()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!isValid)
        }
        .padding(16)
    }

    private func start() {
        kind = session.requestedNewFileKind ?? lastKind
        session.requestedNewFileKind = nil
        name = kind.defaultName
        let requested = session.newFileFolder.flatMap { url in
            // The project folder itself, from File ▸ New File in Project, is no choice.
            session.project.map { SourceMap.canonicalPath($0.folder) == SourceMap.canonicalPath(url) } == true ? nil : url
        }
        isFolderChosen = requested != nil
        folder = pickerFolder(for: requested ?? suggestedFolder(for: kind))
        isNameFocused = true
        if kind == .image {
            // Add Images… goes straight to choosing them.
            Task {
                isChoosingImages = true
            }
        }
    }

    private func choose(_ urls: [URL]) {
        let oldPictureName = pictureName
        images = kind == .image ? urls : Array(urls.prefix(1))
        thumbnail = images.first.flatMap { url in
            let isAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if isAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            return NSImage(contentsOf: url)
        }
        // Name the figure after its picture, unless it was named already.
        if kind == .figure, let pictureName, name.isEmpty || name == kind.defaultName || name == oldPictureName {
            name = pictureName
        }
    }

    private func create() {
        guard isValid, let folder else {
            NSSound.beep()
            return
        }
        var request = NewFileRequest(kind: kind, name: trimmedName, folder: folder, usesFile: false)
        if let project = session.project {
            request.usesFile = usesFile && canUseFile(in: project)
        }
        request.caption = caption
        request.images = images
        request.rows = rows
        request.columns = columns
        request.template = template
        do {
            try session.createProjectFile(request)
            if kind != .image {
                lastKind = kind
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension DocumentSession {
    /// Shows New File in Project, for a kind of file and in a folder if given.
    func showNewFileSheet(_ kind: NewFileKind? = nil, in folder: URL? = nil) {
        requestedNewFileKind = kind
        newFileFolder = folder ?? projectFolder
        isShowingNewFileSheet = true
    }
}
