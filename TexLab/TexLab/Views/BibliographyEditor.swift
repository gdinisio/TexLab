//
//  BibliographyEditor.swift
//  TexLab
//

import AppKit
import Foundation
import SwiftUI

/// A row of the bibliography table: an entry, or one of its fields.
private struct BibliographyRow: Identifiable, Hashable {
    enum Kind: Hashable {
        case entry
        /// A field the entry has; `occurrence` tells apart a name used twice.
        case field(name: String, occurrence: Int)
        /// A field the entry's type needs that it doesn't have yet.
        case missing(String)
        case addField
        /// An entry that doesn't end properly, left to the Code editor.
        case incomplete
    }

    var entry: Int
    var kind: Kind

    var id: Self { self }
}

/// A bibliography in the Visual editor, like Xcode's Info editor: each entry a row with its
/// citation key, its kind — Journal Article, Book, Website… — and a summary; open it to
/// see and edit its fields by name — Authors, Title, Journal, Year — with the fields its
/// kind needs ready to fill in. BibTeX stays behind it: every change is an undoable edit
/// to the text, which the Code editor shows as it is.
struct BibliographyEditor: View {
    var session: DocumentSession

    @State private var file = BibliographyFile()
    @State private var expandedKeys: Set<String> = []
    @State private var selection: Set<BibliographyRow> = []
    @State private var filter = ""
    @State private var loadedURL: URL?
    /// The entry an Other Field… is being added to, and its name.
    @State private var otherFieldEntry: Int?
    @State private var otherFieldName = ""
    @AppStorage("bibliographyShowsBibTeXNames") private var showsBibTeXNames = false

    var body: some View {
        VStack(spacing: 0) {
            bar
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: session.textRevision, initial: true) {
            reload()
        }
        // Undo and Redo go to the bibliography's history while the table has the focus, as
        // they do in the Code editor.
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
            .frame(maxWidth: 360)
            Spacer()
            Text(countDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            ControlGroup {
                Button {
                    expandedKeys = Set(file.entries.map(expansionKey))
                } label: {
                    Label("Expand All", systemImage: "rectangle.expand.vertical")
                }
                .help("Show every entry’s fields")
                Button {
                    expandedKeys = []
                } label: {
                    Label("Collapse All", systemImage: "rectangle.compress.vertical")
                }
                .help("Show only the entries")
            }
            .labelStyle(.iconOnly)
            .fixedSize()
            Toggle(isOn: $showsBibTeXNames) {
                Label("BibTeX Names", systemImage: "curlybraces")
            }
            .toggleStyle(.button)
            .labelStyle(.iconOnly)
            .help("Show fields and kinds of entry by their BibTeX names, such as “booktitle” and “inproceedings”")
        }
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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

    // MARK: - Table

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
            table
        }
    }

    private var table: some View {
        Table(of: BibliographyRow.self, selection: $selection) {
            TableColumn("Key") { row in
                keyCell(row)
            }
            .width(min: 120, ideal: 210)
            TableColumn("Type") { row in
                typeCell(row)
            }
            .width(min: 90, ideal: 170, max: 260)
            TableColumn("Value") { row in
                valueCell(row)
            }
        } rows: {
            ForEach(visibleEntries) { entry in
                DisclosureTableRow(BibliographyRow(entry: entry.id, kind: .entry), isExpanded: expansion(of: entry)) {
                    ForEach(rows(of: entry)) { row in
                        TableRow(row)
                    }
                }
            }
        }
        .contextMenu(forSelectionType: BibliographyRow.self) { rows in
            menu(for: rows)
        } primaryAction: { rows in
            // Double-click an entry to open or close it.
            for row in rows where row.kind == .entry {
                if let entry = self.entry(row.entry) {
                    toggle(entry)
                }
            }
        }
        .onDeleteCommand {
            delete(selection)
        }
    }

    /// An entry's rows: the fields its kind needs, in the usual order — filled in or ready
    /// to be — then its other fields as the file has them, and Add Field.
    private func rows(of entry: BibliographyEntry) -> [BibliographyRow] {
        guard entry.isComplete else {
            return [BibliographyRow(entry: entry.id, kind: .incomplete)]
        }
        var rows: [BibliographyRow] = []
        var shown: Set<Int> = []
        let required = BibliographyCatalog.type(entry.type)?.required ?? []
        for group in required {
            if let index = entry.fields.firstIndex(where: { group.contains($0.name) }) {
                rows.append(fieldRow(entry, index))
                shown.insert(index)
            } else if let name = group.first {
                rows.append(BibliographyRow(entry: entry.id, kind: .missing(name)))
            }
        }
        for index in entry.fields.indices where !shown.contains(index) {
            rows.append(fieldRow(entry, index))
        }
        rows.append(BibliographyRow(entry: entry.id, kind: .addField))
        return rows
    }

    private func fieldRow(_ entry: BibliographyEntry, _ index: Int) -> BibliographyRow {
        let name = entry.fields[index].name
        let occurrence = entry.fields[..<index].filter { $0.name == name }.count
        return BibliographyRow(entry: entry.id, kind: .field(name: name, occurrence: occurrence))
    }

    // MARK: - Cells

    @ViewBuilder
    private func keyCell(_ row: BibliographyRow) -> some View {
        if let entry = self.entry(row.entry) {
            switch row.kind {
            case .entry:
                HStack(spacing: 6) {
                    Image(systemName: BibliographyCatalog.systemImage(ofType: entry.type))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                        .accessibilityHidden(true)
                    CommitField(value: entry.key, prompt: String(localized: "Key"), isMonospaced: true) { key in
                        file.problem(withKey: key, for: entry)
                    } commit: { key in
                        setKey(key, of: entry)
                    }
                }
            case .field(let name, _):
                fieldName(name)
            case .missing(let name):
                fieldName(name)
                    .foregroundStyle(.secondary)
            case .addField:
                Menu {
                    addFieldItems(for: entry)
                } label: {
                    Label("Add Field", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .foregroundStyle(.secondary)
            case .incomplete:
                Label("Incomplete Entry", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
        }
    }

    private func fieldName(_ name: String) -> some View {
        Text(verbatim: showsBibTeXNames ? name : BibliographyCatalog.fieldTitle(name))
            .help(showsBibTeXNames ? BibliographyCatalog.fieldTitle(name) : name)
    }

    @ViewBuilder
    private func typeCell(_ row: BibliographyRow) -> some View {
        if let entry = self.entry(row.entry) {
            switch row.kind {
            case .entry:
                Picker("Type", selection: typeBinding(of: entry)) {
                    ForEach(BibliographyCatalog.types) { type in
                        Label(showsBibTeXNames ? type.name : type.title, systemImage: type.systemImage)
                            .tag(type.name)
                    }
                    if BibliographyCatalog.type(entry.type) == nil {
                        Text(verbatim: entry.type)
                            .tag(entry.normalizedType)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            case .field(let name, _):
                Text(BibliographyCatalog.fieldKind(name))
                    .foregroundStyle(.secondary)
            case .missing(let name):
                Text(BibliographyCatalog.fieldKind(name))
                    .foregroundStyle(.tertiary)
            case .addField, .incomplete:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func valueCell(_ row: BibliographyRow) -> some View {
        if let entry = self.entry(row.entry) {
            switch row.kind {
            case .entry:
                HStack(spacing: 6) {
                    Text(verbatim: entry.summary)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    let missing = BibliographyCatalog.missingFields(of: entry)
                    if entry.isComplete && !missing.isEmpty {
                        Spacer(minLength: 4)
                        Image(systemName: "exclamationmark.circle")
                            .foregroundStyle(.orange)
                            .help(String(localized: "Still to fill in: \(missing.map(BibliographyCatalog.fieldTitle).formatted(.list(type: .and)))"))
                            .accessibilityLabel(String(localized: "Missing fields"))
                    }
                }
            case .field(let name, let occurrence):
                if let field = entry.fields.filter({ $0.name == name }).dropFirst(occurrence).first {
                    HStack(spacing: 4) {
                        CommitField(value: field.value, prompt: nil, isMonospaced: false) { value in
                            BibliographyFile.problem(withValue: value)
                        } commit: { value in
                            setValue(value, of: field, in: entry)
                        }
                        .help(BibliographyCatalog.fieldHelp(name) ?? "")
                        if let link = BibliographyCatalog.link(forField: name, value: field.value) {
                            Link(destination: link) {
                                Image(systemName: "arrow.up.forward.square")
                            }
                            .buttonStyle(.borderless)
                            .help("Open in your browser")
                        }
                    }
                }
            case .missing(let name):
                CommitField(value: "", prompt: String(localized: "Required"), isMonospaced: false) { value in
                    BibliographyFile.problem(withValue: value)
                } commit: { value in
                    addField(name, value: value, to: entry)
                }
                .help(BibliographyCatalog.fieldHelp(name) ?? "")
            case .addField:
                EmptyView()
            case .incomplete:
                HStack(spacing: 8) {
                    Text("This entry doesn’t end with a closing brace.")
                        .foregroundStyle(.secondary)
                    Button("Show in Code") {
                        session.showBibliographySource(at: entry.range)
                    }
                    .buttonStyle(.link)
                }
            }
        }
    }

    @ViewBuilder
    private func addFieldItems(for entry: BibliographyEntry) -> some View {
        let suggested = BibliographyCatalog.suggestedFields(for: entry)
        let own = Set(BibliographyCatalog.type(entry.type).map { $0.required.flatMap { $0 } + $0.optional } ?? [])
        ForEach(suggested.filter(own.contains), id: \.self) { name in
            Button(showsBibTeXNames ? name : BibliographyCatalog.fieldTitle(name)) {
                addField(name, value: "", to: entry)
            }
        }
        Divider()
        Menu("More") {
            ForEach(suggested.filter { !own.contains($0) }, id: \.self) { name in
                Button(showsBibTeXNames ? name : BibliographyCatalog.fieldTitle(name)) {
                    addField(name, value: "", to: entry)
                }
            }
        }
        Button("Other Field…") {
            otherFieldName = ""
            otherFieldEntry = entry.id
        }
    }

    @ViewBuilder
    private func menu(for rows: Set<BibliographyRow>) -> some View {
        let entries = selectedEntries(rows)
        if entries.count == 1, let entry = entries.first {
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
        }
        let fields = rows.filter { if case .field = $0.kind { true } else { false } }
        if !fields.isEmpty {
            Divider()
            Button(fields.count == 1 ? String(localized: "Remove Field") : String(localized: "Remove \(fields.count) Fields")) {
                delete(fields)
            }
        }
        let entryRows = rows.filter { $0.kind == .entry }
        if !entryRows.isEmpty {
            Divider()
            Button(entryRows.count == 1 ? String(localized: "Delete Entry") : String(localized: "Delete \(entryRows.count) Entries"), role: .destructive) {
                delete(entryRows)
            }
        }
    }

    // MARK: - Entries

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

    private func selectedEntries(_ rows: Set<BibliographyRow>) -> [BibliographyEntry] {
        Set(rows.map(\.entry)).compactMap { self.entry($0) }.sorted { $0.id < $1.id }
    }

    /// What keeps an entry open across edits: its key, which moves with it.
    private func expansionKey(_ entry: BibliographyEntry) -> String {
        entry.key.isEmpty ? "#\(entry.id)" : entry.key.lowercased()
    }

    private func expansion(of entry: BibliographyEntry) -> Binding<Bool> {
        let key = expansionKey(entry)
        return Binding {
            expandedKeys.contains(key)
        } set: { isExpanded in
            if isExpanded {
                expandedKeys.insert(key)
            } else {
                expandedKeys.remove(key)
            }
        }
    }

    private func toggle(_ entry: BibliographyEntry) {
        let key = expansionKey(entry)
        if expandedKeys.contains(key) {
            expandedKeys.remove(key)
        } else {
            expandedKeys.insert(key)
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
            selection = []
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
        apply([file.appending(type: type, key: key, to: session.text as NSString)], actionName: String(localized: "Add Entry"))
        selection = [BibliographyRow(entry: file.entries.count, kind: .entry)]
    }

    private func duplicate(_ entry: BibliographyEntry) {
        apply([file.duplicating(entry, in: session.text as NSString)], actionName: String(localized: "Duplicate Entry"))
    }

    /// Removes the selected fields, or deletes the selected entries with their fields.
    private func delete(_ rows: Set<BibliographyRow>) {
        let text = session.text as NSString
        let entryIDs = Set(rows.filter { $0.kind == .entry }.map(\.entry))
        var edits = entryIDs.compactMap { self.entry($0) }.map { file.removing($0, in: text) }
        for row in rows where !entryIDs.contains(row.entry) {
            guard case .field(let name, let occurrence) = row.kind, let entry = self.entry(row.entry),
                  let field = entry.fields.filter({ $0.name == name }).dropFirst(occurrence).first else { continue }
            edits.append(file.removing(field, from: entry))
        }
        guard !edits.isEmpty else {
            NSSound.beep()
            return
        }
        selection = []
        apply(edits, actionName: entryIDs.isEmpty ? String(localized: "Remove Field") : String(localized: "Delete Entry"))
    }
}

/// A value edited in place, written when Return is pressed or the field is left, like a
/// cell of Xcode's Info editor. Esc puts back what was there. A value that can't be
/// written, such as one with unmatched braces, stays in the field, in red, until it can.
private struct CommitField: View {
    var value: String
    var prompt: String?
    var isMonospaced: Bool
    var validate: (String) -> String?
    var commit: (String) -> Void

    @State private var draft = ""
    @State private var problem: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $draft, prompt: prompt.map { Text($0) })
            .textFieldStyle(.plain)
            .font(isMonospaced ? .body.monospaced() : .body)
            .foregroundStyle(problem == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.red))
            .focused($isFocused)
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
