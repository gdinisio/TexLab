//
//  TableSheet.swift
//  TexLab
//

import SwiftUI

/// Column alignment for a generated table.
nonisolated enum TableColumnAlignment: String, CaseIterable, Identifiable {
    case left = "l"
    case center = "c"
    case right = "r"

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .left: "Left"
        case .center: "Center"
        case .right: "Right"
        }
    }
}

/// Insert ▸ Table…: builds a `tabular` of the chosen size, so nobody has to count
/// ampersands.
struct TableSheet: View {
    var session: DocumentSession

    @Environment(\.dismiss) private var dismiss
    @State private var rows = 3
    @State private var columns = 3
    @State private var alignment: TableColumnAlignment = .left
    @State private var hasHeaderRow = true
    @State private var hasRules = true
    @State private var isFloating = true

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Stepper(value: $rows, in: 1...60) {
                        LabeledContent("Rows", value: rows.formatted())
                    }
                    Stepper(value: $columns, in: 1...20) {
                        LabeledContent("Columns", value: columns.formatted())
                    }
                    Picker("Alignment", selection: $alignment) {
                        ForEach(TableColumnAlignment.allCases) { alignment in
                            Text(alignment.title).tag(alignment)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Toggle("Header row", isOn: $hasHeaderRow)
                    Toggle("Horizontal rules", isOn: $hasRules)
                    Toggle("Numbered table with caption", isOn: $isFloating)
                } footer: {
                    Text("A numbered table can be referenced with \\ref and floats to a good position on the page.")
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("Insert") {
                    session.editor.insert(snippet)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding([.horizontal, .bottom], 20)
        }
        .frame(width: 420)
        .navigationTitle("Insert Table")
    }

    /// The table, with the insertion point in the first cell.
    private var snippet: Snippet {
        let specification = String(repeating: alignment.rawValue, count: columns)
        let emptyRow = Array(repeating: "", count: columns).joined(separator: " & ") + " \\\\"
        let outer = isFloating ? "\t" : ""
        let inner = outer + "\t"
        let rule = hasRules ? inner + "\\hline\n" : ""

        var before = isFloating ? "\\begin{table}[htbp]\n\t\\centering\n\t\\caption{}\n\t\\label{tab:}\n" : ""
        before += outer + "\\begin{tabular}{\(specification)}\n" + rule + inner

        var after = emptyRow + "\n"
        if hasHeaderRow && rows > 1 {
            after += rule
        }
        for _ in 1..<rows {
            after += inner + emptyRow + "\n"
        }
        after += rule + outer + "\\end{tabular}"
        if isFloating {
            after += "\n\\end{table}"
        }
        return Snippet("Table", before: before, after: after)
    }
}
