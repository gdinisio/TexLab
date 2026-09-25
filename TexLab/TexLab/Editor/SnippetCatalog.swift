//
//  SnippetCatalog.swift
//  TexLab
//

import Foundation

/// The snippets offered by the Insert menu and toolbar item.
///
/// In a snippet, a tab stands for one indent level and a line break keeps the current
/// indentation. The selection, if any, goes between `before` and `after`; otherwise the
/// insertion point does.
nonisolated enum SnippetCatalog {
    static let headings: [Snippet] = [
        Snippet("Part", systemImage: "books.vertical", before: "\\part{", after: "}\n"),
        Snippet("Chapter", systemImage: "book.closed", before: "\\chapter{", after: "}\n"),
        Snippet("Section", systemImage: "textformat.size.larger", before: "\\section{", after: "}\n"),
        Snippet("Subsection", systemImage: "textformat.size", before: "\\subsection{", after: "}\n"),
        Snippet("Subsubsection", systemImage: "textformat.size.smaller", before: "\\subsubsection{", after: "}\n"),
        Snippet("Paragraph Heading", systemImage: "paragraphsign", before: "\\paragraph{", after: "}\n"),
    ]

    static let lists: [Snippet] = [
        Snippet("Bulleted List", systemImage: "list.bullet", before: "\\begin{itemize}\n\t\\item ", after: "\n\\end{itemize}"),
        Snippet("Numbered List", systemImage: "list.number", before: "\\begin{enumerate}\n\t\\item ", after: "\n\\end{enumerate}"),
        Snippet("Description List", systemImage: "list.bullet.rectangle", before: "\\begin{description}\n\t\\item[", after: "] \n\\end{description}"),
    ]

    static let floats: [Snippet] = [
        Snippet(
            "Figure",
            systemImage: "photo",
            before: "\\begin{figure}[htbp]\n\t\\centering\n\t\\includegraphics[width=0.8\\linewidth]{",
            after: "}\n\t\\caption{}\n\t\\label{fig:}\n\\end{figure}"
        ),
        Snippet(
            "Table",
            systemImage: "tablecells",
            before: "\\begin{table}[htbp]\n\t\\centering\n\t\\caption{}\n\t\\label{tab:}\n\t\\begin{tabular}{ll}\n\t\t\\hline\n\t\t",
            after: " & \\\\\n\t\t\\hline\n\t\\end{tabular}\n\\end{table}"
        ),
    ]

    static let math: [Snippet] = [
        Snippet("Inline Math", systemImage: "x.squareroot", before: "$", after: "$"),
        Snippet("Display Math", systemImage: "function", before: "\\[\n\t", after: "\n\\]"),
        Snippet("Numbered Equation", systemImage: "number.square", before: "\\begin{equation}\n\t", after: "\n\t\\label{eq:}\n\\end{equation}"),
        Snippet("Aligned Equations", systemImage: "equal.square", before: "\\begin{align}\n\t", after: " &= \\\\\n\\end{align}"),
        Snippet("Fraction", before: "\\frac{", after: "}{}"),
        Snippet("Square Root", before: "\\sqrt{", after: "}"),
        Snippet("Superscript", before: "^{", after: "}"),
        Snippet("Subscript", before: "_{", after: "}"),
        Snippet("Sum", before: "\\sum_{i=1}^{n} ", after: ""),
        Snippet("Integral", before: "\\int_{a}^{b} ", after: " \\, dx"),
        Snippet("Limit", before: "\\lim_{x \\to \\infty} ", after: ""),
        Snippet("Matrix", before: "\\begin{pmatrix}\n\t", after: " & \\\\\n\\end{pmatrix}"),
        Snippet("Cases", before: "\\begin{cases}\n\t", after: " & \\text{if } \\\\\n\\end{cases}"),
        Snippet("Text in Math", before: "\\text{", after: "}"),
    ]

    static let references: [Snippet] = [
        Snippet("Label", systemImage: "tag", before: "\\label{", after: "}"),
        Snippet("Cross-Reference", systemImage: "arrow.turn.down.right", before: "\\ref{", after: "}"),
        Snippet("Equation Reference", before: "\\eqref{", after: "}"),
        Snippet("Citation", systemImage: "quote.opening", before: "\\cite{", after: "}"),
        Snippet("Footnote", systemImage: "note.text", before: "\\footnote{", after: "}"),
        Snippet("Link", systemImage: "link", before: "\\href{https://}{", after: "}"),
        Snippet("URL", systemImage: "globe", before: "\\url{", after: "}"),
    ]

    static let environments: [Snippet] = [
        Snippet("Centered", systemImage: "text.aligncenter", before: "\\begin{center}\n\t", after: "\n\\end{center}"),
        Snippet("Quotation", systemImage: "text.quote", before: "\\begin{quote}\n\t", after: "\n\\end{quote}"),
        Snippet("Verbatim", systemImage: "chevron.left.forwardslash.chevron.right", before: "\\begin{verbatim}\n", after: "\n\\end{verbatim}"),
        Snippet("Minipage", systemImage: "rectangle.split.2x1", before: "\\begin{minipage}{0.48\\linewidth}\n\t", after: "\n\\end{minipage}"),
        Snippet("Abstract", systemImage: "text.alignleft", before: "\\begin{abstract}\n\t", after: "\n\\end{abstract}"),
        Snippet("Theorem", before: "\\begin{theorem}\n\t", after: "\n\\end{theorem}"),
        Snippet("Proof", before: "\\begin{proof}\n\t", after: "\n\\end{proof}"),
        Snippet("Beamer Frame", systemImage: "rectangle.on.rectangle", before: "\\begin{frame}{", after: "}\n\t\n\\end{frame}"),
    ]

    static let breaks: [Snippet] = [
        Snippet("Line Break", before: "\\\\\n"),
        Snippet("Page Break", before: "\\newpage\n"),
        Snippet("Non-Breaking Space", before: "~"),
        Snippet("Horizontal Space", before: "\\hspace{", after: "}"),
        Snippet("Vertical Space", before: "\\vspace{", after: "}"),
    ]
}

/// Text formatting commands for the Format menu. Each wraps the selection in a command,
/// or unwraps it when it's already wrapped.
nonisolated struct FormatCommand: Identifiable, Sendable {
    var id: String { title }
    let title: String
    let command: String

    var prefix: String { "\\\(command){" }
    var suffix: String { "}" }

    static let bold = FormatCommand(title: "Bold", command: "textbf")
    static let italic = FormatCommand(title: "Italic", command: "textit")
    static let underline = FormatCommand(title: "Underline", command: "underline")
    static let emphasis = FormatCommand(title: "Emphasis", command: "emph")
    static let monospace = FormatCommand(title: "Monospace", command: "texttt")
    static let smallCaps = FormatCommand(title: "Small Caps", command: "textsc")
    static let sansSerif = FormatCommand(title: "Sans Serif", command: "textsf")

    static let all: [FormatCommand] = [.bold, .italic, .underline, .emphasis, .monospace, .smallCaps, .sansSerif]
}
