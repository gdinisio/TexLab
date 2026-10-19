//
//  PackagePicker.swift
//  TexLab
//

import AppKit
import Foundation
import SwiftUI

/// Add Package: the packages people use most, each with what it's for, and any other by
/// its name, with options if it takes them. Those the document loads already — itself, or
/// through its class or another package — are marked, so nothing is loaded twice. The
/// package goes in the preamble after the others, or in the main file's for a part of a
/// project, as an undoable edit.
struct PackagePicker: View {
    var session: DocumentSession
    var dismiss: () -> Void

    @State private var search = ""
    @State private var options = ""
    @State private var selection: String?
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Package", text: $search, prompt: Text("Find or type a package’s name"))
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit(add)
            }
            .navigatorGlass()
            .padding(10)

            List(selection: $selection) {
                if let typed = typedName, !Self.catalog.contains(typed) {
                    Section("Other Package") {
                        row(typed, description: String(localized: "Load the package “\(typed)”"))
                    }
                }
                Section(search.isEmpty ? "Common Packages" : "Matching Packages") {
                    ForEach(matches, id: \.self) { name in
                        row(name, description: LaTeXCatalog.packageDescriptions[name])
                    }
                }
            }
            .listStyle(.inset)
            .contextMenu(forSelectionType: String.self) { _ in
                EmptyView()
            } primaryAction: { names in
                if let name = names.first {
                    selection = name
                    add()
                }
            }

            Divider()
            HStack(spacing: 8) {
                TextField("Options", text: $options, prompt: Text("Options, such as margin=2cm"))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Add") {
                    add()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(chosen == nil || chosen.map(loaded.contains) == true)
            }
            .padding(10)
        }
        .frame(width: 400, height: 440)
        .onAppear {
            isSearchFocused = true
        }
        .onChange(of: search) {
            // What's typed is the choice until one is picked from the list.
            selection = typedName.map { matches.first ?? $0 }
        }
    }

    private func row(_ name: String, description: String?) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: name)
                    .font(.body.monospaced())
                if let description {
                    Text(verbatim: description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if loaded.contains(name) {
                Label("Loaded", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .help("The document loads this package already")
            }
        }
        .tag(name)
    }

    // MARK: - Packages

    /// Every package the picker knows: the common ones, and those commands need.
    private static let catalog: [String] = {
        var names = Set(LaTeXCatalog.packages)
        names.formUnion(LaTeXCatalog.packageDescriptions.keys)
        names.formUnion(PackageRequirements.commands.values.compactMap(\.first))
        names.formUnion(PackageRequirements.environments.values.compactMap(\.first))
        return names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }()

    private var matches: [String] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return Self.catalog }
        return Self.catalog.filter { name in
            name.localizedCaseInsensitiveContains(query)
                || (LaTeXCatalog.packageDescriptions[name]?.localizedCaseInsensitiveContains(query) ?? false)
        }
        .sorted { lhs, rhs in
            // Names that start with what's typed first.
            let left = lhs.lowercased().hasPrefix(query.lowercased())
            let right = rhs.lowercased().hasPrefix(query.lowercased())
            return left != right ? left : lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

    /// A package name as typed, if it could be one.
    private var typedName: String? {
        let name = search.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, name.allSatisfy({ $0.isLetter || $0.isNumber || "-_.".contains($0) }) else { return nil }
        return name
    }

    private var chosen: String? {
        selection ?? typedName
    }

    /// What the document loads: itself, through its class, or through other packages.
    private var loaded: Set<String> {
        guard let context = session.packageContext else { return [] }
        var packages = PackageRequirements.packagesLoaded(by: context.preamble)
        let documentClass = NewFileKind.documentClass(of: context.preamble)
        packages.formUnion(PackageRequirements.classes[documentClass] ?? [])
        return PackageRequirements.closure(of: packages)
    }

    private func add() {
        guard let name = chosen, !loaded.contains(name) else {
            NSSound.beep()
            return
        }
        session.addPackage(name, options: options)
        dismiss()
    }
}
