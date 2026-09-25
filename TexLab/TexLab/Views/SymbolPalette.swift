//
//  SymbolPalette.swift
//  TexLab
//

import Foundation
import SwiftUI

/// A searchable palette of math and text symbols, like the Character Viewer. Clicking a
/// symbol inserts its LaTeX command; the palette stays open for more.
struct SymbolPalette: View {
    var session: DocumentSession

    @State private var searchText = ""
    @State private var hoveredSymbol: LaTeXSymbol?

    private let columns = [GridItem(.adaptive(minimum: 36, maximum: 44), spacing: 4)]

    private var categories: [SymbolCategory] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return SymbolCatalog.categories }
        return SymbolCatalog.categories.compactMap { category in
            let symbols = category.symbols.filter {
                $0.name.lowercased().contains(query) || $0.command.lowercased().contains(query) || $0.glyph == query
            }
            return symbols.isEmpty ? nil : SymbolCategory(title: category.title, symbols: symbols)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Search Symbols", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .padding(10)

            Divider()

            if categories.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(categories) { category in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(category.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                LazyVGrid(columns: columns, spacing: 4) {
                                    ForEach(category.symbols) { symbol in
                                        SymbolCell(symbol: symbol, isHovered: hoveredSymbol == symbol) {
                                            session.editor.insertSymbol(symbol)
                                        }
                                        .onHover { inside in
                                            if inside {
                                                hoveredSymbol = symbol
                                            } else if hoveredSymbol == symbol {
                                                hoveredSymbol = nil
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(12)
                }
            }

            Divider()

            footer
                .padding(.horizontal, 12)
                .frame(height: 30)
        }
        .frame(width: 340, height: 420)
    }

    @ViewBuilder
    private var footer: some View {
        if let symbol = hoveredSymbol {
            HStack {
                Text(symbol.command)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                Spacer()
                if let package = symbol.package {
                    Text("Needs \(package)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(symbol.name.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Text("Click a symbol to insert its LaTeX command.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SymbolCell: View {
    var symbol: LaTeXSymbol
    var isHovered: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symbol.glyph)
                .font(.system(size: 18))
                .frame(width: 36, height: 32)
                .background(
                    isHovered ? Color.accentColor.opacity(0.18) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 6)
                )
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("\(symbol.name.capitalized) — \(symbol.command)")
        .accessibilityLabel(symbol.name)
        .accessibilityHint("Inserts \(symbol.command)")
    }
}
