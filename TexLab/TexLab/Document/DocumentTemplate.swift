//
//  DocumentTemplate.swift
//  TexLab
//

import Foundation

/// Starting points offered by File ▸ New from Template.
///
/// Every template typesets with a standard TeX distribution, so a new document shows a
/// preview straight away and the user can learn by editing something that already works.
nonisolated enum DocumentTemplate: String, CaseIterable, Identifiable {
    case article
    case report
    case book
    case presentation
    case letter
    case minimal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .article: "Article"
        case .report: "Report"
        case .book: "Book"
        case .presentation: "Presentation"
        case .letter: "Letter"
        case .minimal: "Blank"
        }
    }

    var systemImage: String {
        switch self {
        case .article: "doc.text"
        case .report: "doc.richtext"
        case .book: "book.closed"
        case .presentation: "play.rectangle"
        case .letter: "envelope"
        case .minimal: "doc"
        }
    }

    var text: String {
        switch self {
        case .article:
            #"""
            \documentclass[11pt]{article}

            \usepackage[T1]{fontenc}
            \usepackage{amsmath, amssymb}
            \usepackage{graphicx}
            \usepackage{hyperref}

            \title{Untitled}
            \author{}
            \date{\today}

            \begin{document}

            \maketitle

            \section{Introduction}

            Start writing here. Typeset with \emph{Command-R} to update the preview.

            \end{document}

            """#
        case .report:
            #"""
            \documentclass[11pt]{report}

            \usepackage[T1]{fontenc}
            \usepackage{amsmath, amssymb}
            \usepackage{graphicx}
            \usepackage{hyperref}

            \title{Untitled Report}
            \author{}
            \date{\today}

            \begin{document}

            \maketitle
            \tableofcontents

            \chapter{Introduction}

            \section{Background}

            Start writing here.

            \chapter{Conclusion}

            \end{document}

            """#
        case .book:
            #"""
            \documentclass[11pt]{book}

            \usepackage[T1]{fontenc}
            \usepackage{amsmath, amssymb}
            \usepackage{graphicx}
            \usepackage{hyperref}

            \title{Untitled Book}
            \author{}
            \date{}

            \begin{document}

            \frontmatter
            \maketitle
            \tableofcontents

            \mainmatter

            \chapter{First Chapter}

            Start writing here.

            \backmatter

            \end{document}

            """#
        case .presentation:
            #"""
            \documentclass{beamer}

            \usetheme{default}

            \title{Untitled Presentation}
            \author{}
            \date{\today}

            \begin{document}

            \begin{frame}
              \titlepage
            \end{frame}

            \begin{frame}{Overview}
              \begin{itemize}
                \item First point
                \item Second point
              \end{itemize}
            \end{frame}

            \end{document}

            """#
        case .letter:
            #"""
            \documentclass[11pt]{letter}

            \signature{Your Name}
            \address{Street \\ City \\ Country}

            \begin{document}

            \begin{letter}{Recipient \\ Street \\ City}

            \opening{Dear Sir or Madam,}

            Start writing here.

            \closing{Yours faithfully,}

            \end{letter}

            \end{document}

            """#
        case .minimal:
            #"""
            \documentclass{article}

            \begin{document}



            \end{document}

            """#
        }
    }
}
