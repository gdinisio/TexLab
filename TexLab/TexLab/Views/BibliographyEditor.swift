//
//  BibliographyEditor.swift
//  TexLab
//

import AppKit
import Foundation
import SwiftUI

/// A bibliography in the Visual editor, in the spirit of Xcode's Info editor but laid out
/// to read: each entry a card in a page-wide column, with its kind, citation key and a
/// summary; open it to see its fields by name — Authors, Title, Journal, Year — in a
/// column of labels and values, the ones its kind needs ready to fill in. Values look
/// like text until they're edited, and long ones wrap. BibTeX stays behind it: every
/// change is an undoable edit to the text, which the Code editor shows as it is.
struct BibliographyEditor: View {
    var session: DocumentSession

    @State private var file = BibliographyFile()
    @State private var expandedKeys: Set<String> = []
    @State private var filter = ""
    @State private var loadedURL: URL?
    /// An entry just added, to bring into view once it's in the file.
    @State private var revealedEntry: Int?
    /// The entry an Other Field… is being added to, and its name.
    @State private var otherFieldEntry: Int?
    @State private var otherFieldName = ""
    @AppStorage("bibliographyShowsBibTeXNames") private var showsBibTeXNames = false

    /// A readable line length, like the Visual editor's page.
    private static let columnWidth: CGFloat = 760

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .textBackgroundColor))
            .safeAreaInset(edge: .top, spacing: 0) {
                bar
            }
            .onChange(of: session.textRevision, initial: true) {
                reload()
            }
            // Undo and Redo go to the bibliography's history, as they do in the Code
            // editor, when no field is being edited.
            .onCommand(Selector(("undo:"))) {
                session.undoBibliographyEdit()
            }
            .onCommand(Selector(("redo:"))) {
                session.redoBibliographyEdit()
            }
            .alert("Add Another Field", isPresented: Binding(get: { otherFieldEntry != nil }, set: { if !$0 { otherFieldEntry = nil } })) {
                TextField("Name", text: $otherFieldName)
                Button("Add") {
                    let name = otherFieldName.trimmingCharacters(in: .whitespaces).lowercased()
                    if let id = otherFieldEntry, let entry = self.entry(id), !name.isEmpty, name.allSatisfy({ $0.isLetter || $0.isNumber || "-_.:".contains($0) }) {
                        addField(name, value: "", to: entry)
                    } else {
                        NSSound.beep()
                    }
                    otherFieldName = ""
                }
                Button("Cancel", role: .cancel) {
                    otherFieldName = ""
                }
            } message: {
                Text("The field’s name as BibTeX writes it, such as “isbn” or “eprint”.")
            }
    }

    // MARK: - Bar

    /// Add Entry, the filter and the count, floating on glass over the cards.
    private var bar: some View {
        HStack(spacing: 10) {
            addEntryMenu
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                    .foregroundStyle(filter.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.accentColor))
                    .accessibilityHidden(true)
                TextField("Filter by key, author, title or year", text: $filter)
                    .textFieldStyle(.plain)
                if !filter.isEmpty {
                    Button {
                        filter = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear the filter")
                    .accessibilityLabel("Clear the filter")
                }
            }
            .navigatorGlass()
            .frame(maxWidth: 340)
            Spacer(minLength: 8)
            Text(countDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Button {
                if expandedKeys.isEmpty {
                    expandedKeys = Set(file.entries.map(expansionKey))
                } else {
                    expandedKeys = []
                }
            } label: {
                Label(expandedKeys.isEmpty ? "Open All" : "Close All", systemImage: expandedKeys.isEmpty ? "rectangle.expand.vertical" : "rectangle.compress.vertical")
            }
            .buttonStyle(.glass)
            .labelStyle(.iconOnly)
            .help(expandedKeys.isEmpty ? "Show every entry’s fields" : "Show only the entries")
            Toggle(isOn: $showsBibTeXNames) {
                Label("BibTeX Names", systemImage: "curlybraces")
            }
            .toggleStyle(.button)
            .buttonStyle(.glass)
            .labelStyle(.iconOnly)
            .help("Show fields and kinds by their BibTeX names, such as “booktitle” and “inproceedings”")
        }
        .controlSize(.regular)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var addEntryMenu: some View {
        Menu {
            ForEach(BibliographyCatalog.types) { type in
                Button {
                    addEntry(type.name)
                } label: {
                    Label(showsBibTeXNames ? type.name : type.title, systemImage: type.systemImage)
                }
            }
        } label: {
            Label("Add Entry", systemImage: "plus")
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        .fixedSize()
        .help("Add a book, article, website or other entry to the bibliography")
    }

    private var countDescription: String {
        let count = file.entries.count
        let shown = visibleEntries.count
        if shown != count {
            return String(localized: "\(shown) of \(count) entries")
        }
        return count == 1 ? String(localized: "1 entry") : String(localized: "\(count) entries")
    }

    // MARK: - Cards

    @ViewBuilder
    private var content: some View {
        if file.entries.isEmpty {
            ContentUnavailableView {
                Label("No Entries", systemImage: "books.vertical")
            } description: {
                Text("Add the books, articles and websites you cite. Each becomes BibTeX in this file, which the Code editor shows as it is.")
            } actions: {
                addEntryMenu
            }
        } else if visibleEntries.isEmpty {
            ContentUnavailableView.search(text: filter)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(visibleEntries) { entry in
                            card(for: entry)
                                .id(entry.id)
                        }
                    }
                    .frame(maxWidth: Self.columnWidth)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: file.entries.count) {
                    guard let id = revealedEntry, file.entries.indices.contains(id) else { return }
                    revealedEntry = nil
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    /// An entry: its header, and when open, its fields and Add Field.
    private func card(for entry: BibliographyEntry) -> some View {
        let isExpanded = expandedKeys.contains(expansionKey(entry))
        return VStack(alignment: .leading, spacing: 0) {
            header(for: entry, isExpanded: isExpanded)
            if isExpanded {
                Divider()
                    .padding(.leading, 58)
                if entry.isComplete {
                    fields(of: entry)
                } else {
                    incomplete(entry)
                }
            }
        }
        .background(.quinary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator.opacity(0.5))
        }
        .contextMenu {
            actions(for: entry)
        }
    }

    private func header(for entry: BibliographyEntry, isExpanded: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: BibliographyCatalog.systemImage(ofType: entry.type))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Self.tint(forType: entry.type))
                .frame(width: 32, height: 32)
                .background(Self.tint(forType: entry.type).opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onTapGesture {
                    toggle(entry)
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                ValueField(value: entry.key, prompt: String(localized: "Key"), font: .body.monospaced().weight(.semibold)) { key in
                    file.problem(withKey: key, for: entry)
                } commit: { key in
                    setKey(key, of: entry)
                }
                .help("The citation key, as \\cite{…} names this entry")
                Text(verbatim: entry.summary.isEmpty ? String(localized: "No author, year or title yet") : entry.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggle(entry)
                    }
            }
            let missing = BibliographyCatalog.missingFields(of: entry)
            if entry.isComplete && !missing.isEmpty {
                Text("\(missing.count) to fill in")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.12), in: Capsule())
                    .help(String(localized: "Still to fill in: \(missing.map(BibliographyCatalog.fieldTitle).formatted(.list(type: .and)))"))
            }
            typeMenu(for: entry)
            Menu {
                actions(for: entry)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .accessibilityLabel("Actions")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Copy, duplicate, show in Code or delete this entry")
            Button {
                toggle(entry)
            } label: {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help(isExpanded ? "Hide the fields" : "Show the fields")
            .accessibilityLabel(isExpanded ? "Hide the fields" : "Show the fields")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    /// The kind of entry, as a quiet menu: "Journal Article ⌄".
    private func typeMenu(for entry: BibliographyEntry) -> some View {
        Menu {
            Picker("Kind", selection: typeBinding(of: entry)) {
                ForEach(BibliographyCatalog.types) { type in
                    Label(showsBibTeXNames ? type.name : type.title, systemImage: type.systemImage)
                        .tag(type.name)
                }
                if BibliographyCatalog.type(entry.type) == nil {
                    Text(verbatim: entry.type)
                        .tag(entry.normalizedType)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Text(verbatim: showsBibTeXNames ? entry.normalizedType : BibliographyCatalog.title(ofType: entry.type))
                .font(.callout)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("The kind of entry, which decides the fields it needs")
    }

    /// The fields, labels in a column and values beside them: those the entry's kind needs
    /// first, filled in or waiting, then its others as the file has them.
    private func fields(of entry: BibliographyEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(rows(of: entry), id: \.self) { row in
                switch row {
                case .field(let index):
                    let field = entry.fields[index]
                    FieldRow(
                        label: label(for: field.name),
                        help: BibliographyCatalog.fieldHelp(field.name) ?? field.name,
                        value: field.value,
                        prompt: nil,
                        wraps: Self.wrappingFields.contains(field.name),
                        isRequired: BibliographyCatalog.isRequired(field.name, inType: entry.type),
                        link: BibliographyCatalog.link(forField: field.name, value: field.value)
                    ) { value in
                        setValue(value, of: field, in: entry)
                    } remove: {
                        apply([file.removing(field, from: entry)], actionName: String(localized: "Remove \(BibliographyCatalog.fieldTitle(field.name))"))
                    }
                case .missing(let name):
                    FieldRow(
                        label: label(for: name),
                        help: BibliographyCatalog.fieldHelp(name) ?? name,
                        value: "",
                        prompt: String(localized: "Required"),
                        wraps: Self.wrappingFields.contains(name),
                        isRequired: true,
                        link: nil
                    ) { value in
                        addField(name, value: value, to: entry)
                    }
                }
            }
            Menu {
                addFieldItems(for: entry)
            } label: {
                Label("Add Field", systemImage: "plus.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .foregroundStyle(.secondary)
            .padding(.leading, FieldRow.labelWidth + 16)
            .padding(.top, 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func incomplete(_ entry: BibliographyEntry) -> some View {
        HStack(spacing: 8) {
            Label("This entry doesn’t end with a closing brace.", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Button("Show in Code") {
                session.showBibliographySource(at: entry.range)
            }
            .buttonStyle(.link)
        }
        .padding(14)
    }

    private func label(for name: String) -> String {
        showsBibTeXNames ? name : BibliographyCatalog.fieldTitle(name)
    }

    /// Fields whose values run long, which wrap onto more lines.
    private static let wrappingFields: Set<String> = [
        "title", "booktitle", "author", "editor", "abstract", "note", "annote", "keywords", "howpublished", "organization", "journal", "journaltitle", "publisher",
    ]

    /// A colour for each kind of entry, so a long bibliography is easy to scan.
    private static func tint(forType type: String) -> Color {
        switch BibliographyCatalog.type(type)?.name ?? type.lowercased() {
        case "article": .blue
        case "book", "inbook", "incollection", "booklet": .orange
        case "inproceedings", "proceedings": .purple
        case "online", "software", "dataset": .teal
        case "phdthesis", "mastersthesis": .indigo
        case "techreport", "manual": .brown
        default: .gray
        }
    }

    // MARK: - Menus

    @ViewBuilder
    private func actions(for entry: BibliographyEntry) -> some View {
        if entry.isComplete {
            Menu("Add Field") {
                addFieldItems(for: entry)
            }
            Divider()
        }
        Button("Copy Citation") {
            Pasteboard.copy("\\cite{\(entry.key)}")
        }
        Button("Copy Key") {
            Pasteboard.copy(entry.key)
        }
        Button("Duplicate Entry") {
            duplicate(entry)
        }
        Button("Show in Code") {
            session.showBibliographySource(at: entry.range)
        }
        Divider()
        Button("Delete Entry", role: .destructive) {
            apply([file.removing(entry, in: session.text as NSString)], actionName: String(localized: "Delete Entry"))
        }
    }

    @ViewBuilder
    private func addFieldItems(for entry: BibliographyEntry) -> some View {
        let suggested = BibliographyCatalog.suggestedFields(for: entry)
        let own = Set(BibliographyCatalog.type(entry.type).map { $0.required.flatMap { $0 } + $0.optional } ?? [])
        ForEach(suggested.filter(own.contains), id: \.self) { name in
            Button(label(for: name)) {
                addField(name, value: "", to: entry)
            }
        }
        Divider()
        Menu("More") {
            ForEach(suggested.filter { !own.contains($0) }, id: \.self) { name in
                Button(label(for: name)) {
                    addField(name, value: "", to: entry)
                }
            }
        }
        Button("Other Field…") {
            otherFieldName = ""
            otherFieldEntry = entry.id
        }
    }

    // MARK: - Entries

    private enum Row: Hashable {
        /// A field the entry has, by its place among the entry's fields.
        case field(Int)
        /// A field the entry's kind needs that it doesn't have yet.
        case missing(String)
    }

    private func rows(of entry: BibliographyEntry) -> [Row] {
        var rows: [Row] = []
        var shown: Set<Int> = []
        for group in BibliographyCatalog.type(entry.type)?.required ?? [] {
            if let index = entry.fields.firstIndex(where: { group.contains($0.name) }) {
                rows.append(.field(index))
                shown.insert(index)
            } else if let name = group.first {
                rows.append(.missing(name))
            }
        }
        for index in entry.fields.indices where !shown.contains(index) {
            rows.append(.field(index))
        }
        return rows
    }

    private var visibleEntries: [BibliographyEntry] {
        let query = filter.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return file.entries }
        return file.entries.filter { entry in
            entry.key.localizedCaseInsensitiveContains(query)
                || entry.summary.localizedCaseInsensitiveContains(query)
                || entry.fields.contains { BibliographyCatalog.readable($0.value).localizedCaseInsensitiveContains(query) }
        }
    }

    private func entry(_ id: Int) -> BibliographyEntry? {
        file.entries.indices.contains(id) ? file.entries[id] : nil
    }

    /// What keeps an entry open across edits: its key, which moves with it.
    private func expansionKey(_ entry: BibliographyEntry) -> String {
        entry.key.isEmpty ? "#\(entry.id)" : entry.key.lowercased()
    }

    private func toggle(_ entry: BibliographyEntry) {
        let key = expansionKey(entry)
        withAnimation(.snappy(duration: 0.2)) {
            if expandedKeys.contains(key) {
                expandedKeys.remove(key)
            } else {
                expandedKeys.insert(key)
            }
        }
    }

    private func typeBinding(of entry: BibliographyEntry) -> Binding<String> {
        Binding {
            BibliographyCatalog.type(entry.type)?.name ?? entry.normalizedType
        } set: { type in
            guard type != (BibliographyCatalog.type(entry.type)?.name ?? entry.normalizedType) else { return }
            apply([file.settingType(type, of: entry)], actionName: String(localized: "Change Kind of Entry"))
        }
    }

    private func reload() {
        let parsed = BibliographyFile.parse(session.text)
        if loadedURL != session.fileURL {
            loadedURL = session.fileURL
            // A short bibliography opens with every entry's fields in view.
            expandedKeys = parsed.entries.count <= 6 ? Set(parsed.entries.map(expansionKey)) : []
        }
        file = parsed
    }

    // MARK: - Changes

    private func apply(_ edits: [BibliographyEdit], actionName: String) {
        // From the end, so each edit's range is still where it was.
        for edit in edits.sorted(by: { $0.range.location > $1.range.location }) {
            session.applyBibliographyEdit(edit, actionName: actionName)
        }
    }

    private func setValue(_ value: String, of field: BibliographyField, in entry: BibliographyEntry) {
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            apply([file.removing(field, from: entry)], actionName: String(localized: "Remove \(BibliographyCatalog.fieldTitle(field.name))"))
        } else {
            apply([file.setting(value, of: field)], actionName: String(localized: "Change \(BibliographyCatalog.fieldTitle(field.name))"))
        }
    }

    private func addField(_ name: String, value: String, to entry: BibliographyEntry) {
        guard entry.isComplete else { return }
        expandedKeys.insert(expansionKey(entry))
        apply([file.adding(name, value: value, to: entry, in: session.text as NSString)], actionName: String(localized: "Add \(BibliographyCatalog.fieldTitle(name))"))
    }

    private func setKey(_ key: String, of entry: BibliographyEntry) {
        if expandedKeys.remove(expansionKey(entry)) != nil {
            expandedKeys.insert(key.lowercased())
        }
        apply([file.settingKey(key, of: entry)], actionName: String(localized: "Change Key"))
    }

    private func addEntry(_ type: String) {
        let key = file.uniqueKey(type)
        filter = ""
        expandedKeys.insert(key.lowercased())
        revealedEntry = file.entries.count
        apply([file.appending(type: type, key: key, to: session.text as NSString)], actionName: String(localized: "Add Entry"))
    }

    private func duplicate(_ entry: BibliographyEntry) {
        apply([file.duplicating(entry, in: session.text as NSString)], actionName: String(localized: "Duplicate Entry"))
    }
}

/// A field: its name in the label column, its value beside it, and — on hover — a button
/// to remove it, as Xcode's Info editor has. A field the entry's kind needs is marked.
private struct FieldRow: View {
    static let labelWidth: CGFloat = 120

    var label: String
    var help: String
    var value: String
    var prompt: String?
    var wraps: Bool
    var isRequired: Bool
    var link: URL?
    var commit: (String) -> Void
    var remove: (() -> Void)? = nil

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            HStack(spacing: 4) {
                if isRequired && value.isEmpty {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                        .accessibilityLabel("Required")
                }
                Text(verbatim: label)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: Self.labelWidth, alignment: .trailing)
            .help(help)
            ValueField(value: value, prompt: prompt, font: .body, wraps: wraps) { value in
                BibliographyFile.problem(withValue: value)
            } commit: { value in
                commit(value)
            }
            .help(help)
            HStack(spacing: 2) {
                if let link {
                    Link(destination: link) {
                        Image(systemName: "arrow.up.forward.square")
                    }
                    .buttonStyle(.borderless)
                    .help("Open in your browser")
                }
                if let remove {
                    Button(action: remove) {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .opacity(isHovered ? 1 : 0)
                    .help("Remove this field")
                    .accessibilityLabel("Remove \(label)")
                }
            }
            .frame(width: 40, alignment: .leading)
        }
        .onHover { isHovered = $0 }
    }
}

/// A value edited in place: it reads as text, shows a soft field on hover and a ring when
/// edited, and is written when Return is pressed or the field is left. Esc puts back what
/// was there. A value that can't be written, such as one with unmatched braces, stays in
/// the field, in red, until it can.
private struct ValueField: View {
    var value: String
    var prompt: String?
    var font: Font
    var wraps = false
    var validate: (String) -> String?
    var commit: (String) -> Void

    @State private var draft = ""
    @State private var problem: String?
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        field
            .textFieldStyle(.plain)
            .font(font)
            .foregroundStyle(problem == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.red))
            .focused($isFocused)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isFocused ? AnyShapeStyle(.background) : isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(problem != nil ? Color.red.opacity(0.7) : isFocused ? Color.accentColor.opacity(0.7) : .clear, lineWidth: 1)
            }
            .onHover { isHovered = $0 }
            .help(problem ?? "")
            .onAppear {
                draft = value
            }
            .onChange(of: value) { _, newValue in
                if !isFocused {
                    draft = newValue
                    problem = nil
                }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused {
                    save()
                }
            }
            .onSubmit(save)
            .onExitCommand {
                draft = value
                problem = nil
                isFocused = false
            }
    }

    @ViewBuilder
    private var field: some View {
        if wraps {
            TextField("", text: $draft, prompt: prompt.map { Text($0) }, axis: .vertical)
                .lineLimit(1...6)
        } else {
            TextField("", text: $draft, prompt: prompt.map { Text($0) })
        }
    }

    private func save() {
        guard draft != value else {
            problem = nil
            return
        }
        if let problem = validate(draft) {
            self.problem = problem
            NSSound.beep()
            return
        }
        problem = nil
        commit(draft)
    }
}
