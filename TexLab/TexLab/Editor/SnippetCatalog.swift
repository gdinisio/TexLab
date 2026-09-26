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
    // MARK: Headings

    static let part = Snippet("Part", systemImage: "books.vertical", before: "\\part{", after: "}\n")
    static let chapter = Snippet("Chapter", systemImage: "book.closed", before: "\\chapter{", after: "}\n")
    static let section = Snippet("Section", systemImage: "textformat.size.larger", before: "\\section{", after: "}\n")
    static let subsection = Snippet("Subsection", systemImage: "textformat.size", before: "\\subsection{", after: "}\n")
    static let subsubsection = Snippet("Subsubsection", systemImage: "textformat.size.smaller", before: "\\subsubsection{", after: "}\n")
    static let paragraphHeading = Snippet("Paragraph Heading", systemImage: "paragraphsign", before: "\\paragraph{", after: "}\n")

    static let headings: [Snippet] = [part, chapter, section, subsection, subsubsection, paragraphHeading]

    // MARK: Lists

    static let bulletedList = Snippet("Bulleted List", systemImage: "list.bullet", before: "\\begin{itemize}\n\t\\item ", after: "\n\\end{itemize}")
    static let numberedList = Snippet("Numbered List", systemImage: "list.number", before: "\\begin{enumerate}\n\t\\item ", after: "\n\\end{enumerate}")
    static let descriptionList = Snippet("Description List", systemImage: "list.bullet.rectangle", before: "\\begin{description}\n\t\\item[", after: "] \n\\end{description}")

    static let lists: [Snippet] = [bulletedList, numberedList, descriptionList]

    // MARK: Floats

    static let figure = Snippet(
        "Figure",
        systemImage: "photo",
        before: "\\begin{figure}[htbp]\n\t\\centering\n\t\\includegraphics[width=0.8\\linewidth]{",
        after: "}\n\t\\caption{}\n\t\\label{fig:}\n\\end{figure}"
    )
    static let table = Snippet(
        "Table",
        systemImage: "tablecells",
        before: "\\begin{table}[htbp]\n\t\\centering\n\t\\caption{}\n\t\\label{tab:}\n\t\\begin{tabular}{ll}\n\t\t\\hline\n\t\t",
        after: " & \\\\\n\t\t\\hline\n\t\\end{tabular}\n\\end{table}"
    )

    static let floats: [Snippet] = [figure, table]

    // MARK: Math

    static let inlineMath = Snippet("Inline Math", systemImage: "x.squareroot", before: "$", after: "$")
    static let displayMath = Snippet("Display Math", systemImage: "function", before: "\\[\n\t", after: "\n\\]")
    static let equation = Snippet("Numbered Equation", systemImage: "number.square", before: "\\begin{equation}\n\t", after: "\n\t\\label{eq:}\n\\end{equation}")
    static let align = Snippet("Aligned Equations", systemImage: "equal.square", before: "\\begin{align}\n\t", after: " &= \\\\\n\\end{align}")
    static let fraction = Snippet("Fraction", systemImage: "divide", before: "\\frac{", after: "}{}")
    static let matrix = Snippet("Matrix", systemImage: "square.grid.3x3", before: "\\begin{pmatrix}\n\t", after: " & \\\\\n\\end{pmatrix}")
    static let cases = Snippet("Cases", systemImage: "curlybraces.square", before: "\\begin{cases}\n\t", after: " & \\text{if } \\\\\n\\end{cases}")

    static let math: [Snippet] = [
        inlineMath, displayMath, equation, align, fraction,
        Snippet("Square Root", before: "\\sqrt{", after: "}"),
        Snippet("Superscript", before: "^{", after: "}"),
        Snippet("Subscript", before: "_{", after: "}"),
        Snippet("Sum", before: "\\sum_{i=1}^{n} ", after: ""),
        Snippet("Integral", before: "\\int_{a}^{b} ", after: " \\, dx"),
        Snippet("Limit", before: "\\lim_{x \\to \\infty} ", after: ""),
        matrix, cases,
        Snippet("Text in Math", before: "\\text{", after: "}"),
    ]

    /// Packages each math snippet needs beyond LaTeX itself.
    static func packages(for snippet: Snippet) -> [String] {
        [align.title, matrix.title, cases.title, "Text in Math"].contains(snippet.title) ? ["amsmath"] : []
    }

    // MARK: References and notes

    static let label = Snippet("Label", systemImage: "tag", before: "\\label{", after: "}")
    static let footnote = Snippet("Footnote", systemImage: "note.text", before: "\\footnote{", after: "}")
    static let link = Snippet("Link", systemImage: "link", before: "\\href{https://}{", after: "}")
    static let url = Snippet("URL", systemImage: "globe", before: "\\url{", after: "}")

    static let references: [Snippet] = [
        label,
        Snippet("Cross-Reference", systemImage: "arrow.turn.down.right", before: "\\ref{", after: "}"),
        Snippet("Equation Reference", before: "\\eqref{", after: "}"),
        Snippet("Citation", systemImage: "quote.opening", before: "\\cite{", after: "}"),
        footnote, link, url,
    ]

    // MARK: Environments

    static let quotation = Snippet("Quotation", systemImage: "text.quote", before: "\\begin{quote}\n\t", after: "\n\\end{quote}")
    static let codeListing = Snippet("Code Listing", systemImage: "curlybraces", before: "\\begin{lstlisting}\n", after: "\n\\end{lstlisting}")
    static let centered = Snippet("Centered", systemImage: "text.aligncenter", before: "\\begin{center}\n\t", after: "\n\\end{center}")
    static let abstract = Snippet("Abstract", systemImage: "text.alignleft", before: "\\begin{abstract}\n\t", after: "\n\\end{abstract}")

    static let environments: [Snippet] = [
        centered, quotation,
        Snippet("Verbatim", systemImage: "chevron.left.forwardslash.chevron.right", before: "\\begin{verbatim}\n", after: "\n\\end{verbatim}"),
        codeListing,
        Snippet("Minipage", systemImage: "rectangle.split.2x1", before: "\\begin{minipage}{0.48\\linewidth}\n\t", after: "\n\\end{minipage}"),
        abstract,
    ]

    // MARK: Presentations

    static let frame = Snippet("Frame", systemImage: "rectangle.on.rectangle", before: "\\begin{frame}{", after: "}\n\t\n\\end{frame}")
    static let columns = Snippet(
        "Columns",
        systemImage: "rectangle.split.2x1",
        before: "\\begin{columns}\n\t\\begin{column}{0.5\\textwidth}\n\t\t",
        after: "\n\t\\end{column}\n\t\\begin{column}{0.5\\textwidth}\n\t\t\n\t\\end{column}\n\\end{columns}"
    )
    static let block = Snippet("Block", systemImage: "rectangle.grid.1x2", before: "\\begin{block}{", after: "}\n\t\n\\end{block}")
    static let pause = Snippet("Pause", systemImage: "pause", before: "\\pause\n")

    static let presentation: [Snippet] = [frame, columns, block, pause]

    // MARK: Spacing

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
