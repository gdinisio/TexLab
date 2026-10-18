//
//  ProjectTemplates.swift
//  TexLab
//

import Foundation

/// A file a new project starts with, written with placeholders that New Project fills in.
///
/// `⟨title⟩`, `⟨author⟩`, `⟨affiliation⟩`, `⟨date⟩`, `⟨year⟩`, `⟨size⟩`, `⟨paper⟩`,
/// `⟨language⟩` and `⟨slides⟩` are replaced with the choices made. A line ending in `⟨bib⟩`
/// is kept only with a bibliography and one ending in `⟨nobib⟩` only without; a line ending
/// in `⟨pdf⟩` only for pdfLaTeX, and one ending in `⟨unicode⟩` only for XeLaTeX and
/// LuaLaTeX, which use the Mac's fonts through fontspec.
nonisolated struct ProjectFileTemplate: Sendable {
    /// Where the file goes, from the project folder.
    var path: String
    var text: String
    /// Made only with a bibliography, like references.bib.
    var onlyWithBibliography = false
}

nonisolated extension DocumentTemplate {
    /// The folders a new project has, including ones it starts without files in.
    var projectFolders: [String] {
        switch self {
        case .article: ["Figures", "Sections"]
        case .report: ["Chapters", "Figures", "FrontMatter"]
        case .thesis: ["Appendices", "Chapters", "Figures", "FrontMatter"]
        case .notes: ["Figures", "Lectures"]
        case .assignment: ["Figures"]
        case .presentation: ["Figures", "Slides"]
        case .letter, .minimal: []
        }
    }

    /// The files a new project has, its main file first.
    var projectFiles: [ProjectFileTemplate] {
        switch self {
        case .article:
            return [
                ProjectFileTemplate(path: "main.tex", text: #"""
                \documentclass[⟨size⟩]{article}

                % Fonts and language
                \usepackage[T1]{fontenc}⟨pdf⟩
                \usepackage{lmodern}⟨pdf⟩
                \usepackage{fontspec}⟨unicode⟩
                \usepackage[⟨language⟩]{babel}
                \usepackage{csquotes}
                \usepackage{microtype}

                % Page layout
                \usepackage[⟨paper⟩, top=2.5cm, bottom=2.5cm, left=3cm, right=3cm]{geometry}

                % Maths and graphics
                \usepackage{amsmath,amssymb,amsthm}
                \usepackage{graphicx}
                \graphicspath{{Figures/}}
                \usepackage{tikz}
                \usepackage{float}
                \usetikzlibrary{arrows.meta, babel}

                % Bibliography⟨bib⟩
                \usepackage[⟨bib⟩
                  backend=biber,⟨bib⟩
                  style=numeric,⟨bib⟩
                  sorting=none,⟨bib⟩
                  date=long,⟨bib⟩
                  urldate=long,⟨bib⟩
                  dateabbrev=false⟨bib⟩
                ]{biblatex}⟨bib⟩
                \addbibresource{references.bib}⟨bib⟩
                ⟨bib⟩
                % Hyperlinks (load last)
                \usepackage[colorlinks=true, allcolors=blue]{hyperref}
                \usepackage[all]{hypcap}

                % Theorem environments
                \theoremstyle{plain}
                \newtheorem{proposition}{Proposition}
                \theoremstyle{definition}
                \newtheorem{definition}{Definition}

                % Paper details, defined once and used everywhere
                \newcommand{\papertitle}{⟨title⟩}
                \newcommand{\paperauthor}{⟨author⟩}
                \newcommand{\paperaffil}{⟨affiliation⟩}
                \newcommand{\paperdate}{⟨date⟩}   % update when you publish

                \hypersetup{
                  pdftitle   = {\papertitle},
                  pdfauthor  = {\paperauthor}
                }

                \begin{document}

                \begin{titlepage}
                  {\centering
                    \vspace*{3cm}
                    {\LARGE\bfseries \papertitle \par}
                    \vspace{1cm}
                    {\large \paperauthor \par}
                    \vspace{0.3cm}
                    {\normalsize \paperaffil \par}
                    \vspace{0.3cm}
                    {\normalsize \paperdate \par}
                    \vspace{1.5cm}
                  }

                  \input{Sections/abstract}   % contains its own abstract environment

                  \vfill
                  \begin{center}
                    {\large \textcopyright\ ⟨year⟩ \paperauthor}
                  \end{center}
                  \vspace*{1cm}
                \end{titlepage}

                % ---- Content ----
                \input{Sections/introduction}

                \clearpage⟨bib⟩
                \printbibliography[heading=bibintoc, title={References}]⟨bib⟩

                \end{document}

                """#),
                ProjectFileTemplate(path: "Sections/abstract.tex", text: #"""
                % !TEX root = ../main.tex

                \begin{abstract}
                  In a few sentences: the question this paper answers, how it goes about it,
                  and what it finds.
                \end{abstract}

                """#),
                ProjectFileTemplate(path: "Sections/introduction.tex", text: #"""
                % !TEX root = ../main.tex

                \section{Introduction}
                \label{sec:introduction}

                Start writing here, and typeset with Command-R to see the paper beside the text.
                Cite a source with \verb|\cite|, like this~\cite{lamport1994latex}; the references⟨bib⟩
                follow on a page of their own.⟨bib⟩

                Each further section goes in a file of its own in the Sections folder: choose
                File, New File in Project, and TexLab adds it to \texttt{main.tex}. Pictures go in
                the Figures folder, where \verb|\includegraphics| finds them by name.

                """#),
                ProjectFileTemplate(path: "references.bib", text: Self.sampleBibliography, onlyWithBibliography: true),
            ]

        case .report:
            return [
                ProjectFileTemplate(path: "main.tex", text: #"""
                \documentclass[⟨size⟩]{report}

                % Fonts and language
                \usepackage[T1]{fontenc}⟨pdf⟩
                \usepackage{lmodern}⟨pdf⟩
                \usepackage{fontspec}⟨unicode⟩
                \usepackage[⟨language⟩]{babel}
                \usepackage{csquotes}
                \usepackage{microtype}

                % Page layout
                \usepackage[⟨paper⟩, top=2.5cm, bottom=2.5cm, left=3cm, right=3cm]{geometry}
                \usepackage{setspace}
                \onehalfspacing

                % Maths, tables and graphics
                \usepackage{amsmath,amssymb}
                \usepackage{graphicx}
                \graphicspath{{Figures/}}
                \usepackage{booktabs}
                \usepackage{caption}
                \usepackage{float}

                % Bibliography⟨bib⟩
                \usepackage[backend=biber, style=numeric, sorting=none]{biblatex}⟨bib⟩
                \addbibresource{references.bib}⟨bib⟩
                ⟨bib⟩
                % Hyperlinks (load last)
                \usepackage[colorlinks=true, allcolors=blue]{hyperref}
                \usepackage[all]{hypcap}

                % Report details, defined once and used everywhere
                \newcommand{\reporttitle}{⟨title⟩}
                \newcommand{\reportauthor}{⟨author⟩}
                \newcommand{\reportaffil}{⟨affiliation⟩}
                \newcommand{\reportdate}{⟨date⟩}

                \hypersetup{
                  pdftitle  = {\reporttitle},
                  pdfauthor = {\reportauthor}
                }

                \begin{document}

                \begin{titlepage}
                  \centering
                  \vspace*{4cm}
                  {\Huge\bfseries \reporttitle \par}
                  \vspace{1.5cm}
                  {\Large \reportauthor \par}
                  \vspace{0.5cm}
                  {\large \reportaffil \par}
                  \vfill
                  {\large \reportdate \par}
                \end{titlepage}

                \pagenumbering{roman}
                \input{FrontMatter/abstract}   % contains its own abstract environment
                \tableofcontents
                \clearpage
                \pagenumbering{arabic}

                % ---- Chapters ----
                \input{Chapters/introduction}
                \input{Chapters/conclusion}

                \printbibliography[heading=bibintoc, title={References}]⟨bib⟩

                \end{document}

                """#),
                ProjectFileTemplate(path: "FrontMatter/abstract.tex", text: #"""
                % !TEX root = ../main.tex

                \begin{abstract}
                  What the report is about, what was done and what it found, in a paragraph or
                  two.
                \end{abstract}

                """#),
                ProjectFileTemplate(path: "Chapters/introduction.tex", text: #"""
                % !TEX root = ../main.tex

                \chapter{Introduction}
                \label{ch:introduction}

                Start writing here, and typeset with Command-R to see the report beside the text.
                Cite a source with \verb|\cite|, like this~\cite{lamport1994latex}.⟨bib⟩

                \section{Aims}

                Each chapter goes in a file of its own in the Chapters folder: choose File, New
                File in Project, and TexLab adds it to \texttt{main.tex}. Tables are set with the
                rules of \texttt{booktabs}, as in Table~\ref{tab:example}.

                \begin{table}[htbp]
                  \centering
                  \begin{tabular}{lrr}
                    \toprule
                    Sample & Mass (g) & Volume (ml) \\
                    \midrule
                    A & 12.4 & 10.0 \\
                    B & 15.1 & 12.5 \\
                    \bottomrule
                  \end{tabular}
                  \caption{An example table.}
                  \label{tab:example}
                \end{table}

                """#),
                ProjectFileTemplate(path: "Chapters/conclusion.tex", text: #"""
                % !TEX root = ../main.tex

                \chapter{Conclusion}
                \label{ch:conclusion}

                What the report found, and what should happen next.

                """#),
                ProjectFileTemplate(path: "references.bib", text: Self.sampleBibliography, onlyWithBibliography: true),
            ]

        case .thesis:
            return [
                ProjectFileTemplate(path: "main.tex", text: #"""
                \documentclass[⟨size⟩, oneside]{book}

                % Fonts and language
                \usepackage[T1]{fontenc}⟨pdf⟩
                \usepackage{lmodern}⟨pdf⟩
                \usepackage{fontspec}⟨unicode⟩
                \usepackage[⟨language⟩]{babel}
                \usepackage{csquotes}
                \usepackage{microtype}

                % Page layout, with a wider margin for binding
                \usepackage[⟨paper⟩, top=2.5cm, bottom=2.5cm, inner=3.5cm, outer=2.5cm]{geometry}
                \usepackage{setspace}
                \onehalfspacing

                % Maths, tables and graphics
                \usepackage{amsmath,amssymb,amsthm}
                \usepackage{graphicx}
                \graphicspath{{Figures/}}
                \usepackage{booktabs}
                \usepackage{caption}

                % Bibliography⟨bib⟩
                \usepackage[backend=biber, style=numeric, sorting=none]{biblatex}⟨bib⟩
                \addbibresource{references.bib}⟨bib⟩
                ⟨bib⟩
                % Hyperlinks (load last)
                \usepackage[colorlinks=true, allcolors=blue]{hyperref}
                \usepackage[all]{hypcap}

                % Theorem environments, numbered within chapters
                \theoremstyle{plain}
                \newtheorem{theorem}{Theorem}[chapter]
                \newtheorem{proposition}[theorem]{Proposition}
                \newtheorem{lemma}[theorem]{Lemma}
                \theoremstyle{definition}
                \newtheorem{definition}[theorem]{Definition}

                % Thesis details, defined once and used everywhere
                \newcommand{\thesistitle}{⟨title⟩}
                \newcommand{\thesisauthor}{⟨author⟩}
                \newcommand{\thesisuniversity}{⟨affiliation⟩}
                \newcommand{\thesisdegree}{Doctor of Philosophy}   % or Master of Science, …
                \newcommand{\thesisdate}{⟨date⟩}

                \hypersetup{
                  pdftitle  = {\thesistitle},
                  pdfauthor = {\thesisauthor}
                }

                \begin{document}

                \frontmatter

                \begin{titlepage}
                  \centering
                  \vspace*{3cm}
                  {\Huge\bfseries \thesistitle \par}
                  \vspace{2cm}
                  {\Large \thesisauthor \par}
                  \vfill
                  {\large A thesis submitted for the degree of \par}
                  \vspace{0.3cm}
                  {\large\itshape \thesisdegree \par}
                  \vspace{1cm}
                  {\large \thesisuniversity \par}
                  \vspace{0.3cm}
                  {\large \thesisdate \par}
                \end{titlepage}

                \input{FrontMatter/abstract}
                \input{FrontMatter/acknowledgements}
                \tableofcontents
                \listoffigures
                \listoftables

                \mainmatter

                % ---- Chapters ----
                \input{Chapters/introduction}
                \input{Chapters/conclusion}

                \appendix
                \input{Appendices/additional-material}

                \backmatter
                \printbibliography[heading=bibintoc, title={References}]⟨bib⟩

                \end{document}

                """#),
                ProjectFileTemplate(path: "FrontMatter/abstract.tex", text: #"""
                % !TEX root = ../main.tex

                \chapter*{Abstract}
                \addcontentsline{toc}{chapter}{Abstract}

                The thesis in a page: the question it asks, how it answers it, what it finds and
                why that matters.

                """#),
                ProjectFileTemplate(path: "FrontMatter/acknowledgements.tex", text: #"""
                % !TEX root = ../main.tex

                \chapter*{Acknowledgements}
                \addcontentsline{toc}{chapter}{Acknowledgements}

                The people and institutions who made this work possible.

                """#),
                ProjectFileTemplate(path: "Chapters/introduction.tex", text: #"""
                % !TEX root = ../main.tex

                \chapter{Introduction}
                \label{ch:introduction}

                Start writing here, and typeset with Command-R to see the thesis beside the text.
                Cite a source with \verb|\cite|, like this~\cite{lamport1994latex}.⟨bib⟩

                Each chapter goes in a file of its own in the Chapters folder: choose File, New
                File in Project, and TexLab adds it to \texttt{main.tex}. Figure~\ref{fig:placeholder}
                and Table~\ref{tab:example} show how figures and tables are numbered by chapter and
                listed at the front.

                \begin{figure}[htbp]
                  \centering
                  \fbox{\parbox[c][3.5cm][c]{0.6\linewidth}{\centering
                    Put pictures in the Figures folder and include them with
                    \texttt{\textbackslash includegraphics\{name\}}.}}
                  \caption{A place for a figure.}
                  \label{fig:placeholder}
                \end{figure}

                \begin{table}[htbp]
                  \centering
                  \begin{tabular}{lr}
                    \toprule
                    Condition & Result \\
                    \midrule
                    Control & 1.00 \\
                    Treatment & 1.42 \\
                    \bottomrule
                  \end{tabular}
                  \caption{An example table.}
                  \label{tab:example}
                \end{table}

                """#),
                ProjectFileTemplate(path: "Chapters/conclusion.tex", text: #"""
                % !TEX root = ../main.tex

                \chapter{Conclusion}
                \label{ch:conclusion}

                What the thesis has shown, its limits, and where the work could go next.

                """#),
                ProjectFileTemplate(path: "Appendices/additional-material.tex", text: #"""
                % !TEX root = ../main.tex

                \chapter{Additional Material}
                \label{app:additional-material}

                Material that supports the thesis but would interrupt it: long proofs, data and
                code.

                """#),
                ProjectFileTemplate(path: "references.bib", text: Self.sampleBibliography, onlyWithBibliography: true),
            ]

        case .notes:
            return [
                ProjectFileTemplate(path: "main.tex", text: #"""
                \documentclass[⟨size⟩]{article}

                % Fonts and language
                \usepackage[T1]{fontenc}⟨pdf⟩
                \usepackage{lmodern}⟨pdf⟩
                \usepackage{fontspec}⟨unicode⟩
                \usepackage[⟨language⟩]{babel}
                \usepackage{csquotes}
                \usepackage{microtype}

                % Page layout, with running heads
                \usepackage[⟨paper⟩, margin=2.5cm, headheight=15pt]{geometry}
                \usepackage{fancyhdr}

                % Maths and graphics
                \usepackage{amsmath,amssymb,amsthm,mathtools}
                \usepackage{graphicx}
                \graphicspath{{Figures/}}
                \usepackage{enumitem}

                % Bibliography⟨bib⟩
                \usepackage[backend=biber, style=numeric, sorting=none]{biblatex}⟨bib⟩
                \addbibresource{references.bib}⟨bib⟩
                ⟨bib⟩
                % Hyperlinks, and references that name what they refer to (load last). Labels
                % without colons, such as thm-identity, work with \cref in every language.
                \usepackage[colorlinks=true, allcolors=blue]{hyperref}
                \usepackage{cleveref}

                % Theorem environments, numbered within sections
                \theoremstyle{plain}
                \newtheorem{theorem}{Theorem}[section]
                \newtheorem{proposition}[theorem]{Proposition}
                \newtheorem{lemma}[theorem]{Lemma}
                \newtheorem{corollary}[theorem]{Corollary}
                \theoremstyle{definition}
                \newtheorem{definition}[theorem]{Definition}
                \newtheorem{example}[theorem]{Example}
                \newtheorem{exercise}[theorem]{Exercise}
                \theoremstyle{remark}
                \newtheorem*{remark}{Remark}
                \numberwithin{equation}{section}

                % Course details, defined once and used everywhere
                \newcommand{\coursetitle}{⟨title⟩}
                \newcommand{\courselecturer}{⟨author⟩}
                \newcommand{\courseinstitution}{⟨affiliation⟩}
                \newcommand{\courseterm}{⟨date⟩}

                \hypersetup{
                  pdftitle  = {\coursetitle},
                  pdfauthor = {\courselecturer}
                }

                % The course on the left of each page, the section on the right
                \pagestyle{fancy}
                \fancyhf{}
                \fancyhead[L]{\coursetitle}
                \fancyhead[R]{\nouppercase{\leftmark}}
                \fancyfoot[C]{\thepage}

                \begin{document}

                \begin{titlepage}
                  \centering
                  \vspace*{4cm}
                  {\Huge\bfseries \coursetitle \par}
                  \vspace{1.5cm}
                  {\Large \courselecturer \par}
                  \vspace{0.5cm}
                  {\large \courseinstitution \par}
                  \vspace{0.3cm}
                  {\large \courseterm \par}
                \end{titlepage}

                \tableofcontents
                \clearpage

                % ---- Lectures ----
                \input{Lectures/lecture01}

                \clearpage⟨bib⟩
                \printbibliography[heading=bibintoc, title={References}]⟨bib⟩

                \end{document}

                """#),
                ProjectFileTemplate(path: "Lectures/lecture01.tex", text: #"""
                % !TEX root = ../main.tex

                \section{First Lecture}
                \label{sec-lecture01}

                Each lecture goes in a file of its own in the Lectures folder: choose File, New
                File in Project, and TexLab adds it to \texttt{main.tex}.

                \begin{definition}
                  A \emph{group} is a set $G$ with an associative operation, an identity element
                  and an inverse for every element.
                \end{definition}

                \begin{theorem}\label{thm-identity}
                  The identity element of a group is unique.
                \end{theorem}

                \begin{proof}
                  If $e$ and $e'$ are both identities, then $e = e e' = e'$.
                \end{proof}

                \begin{remark}
                  The proof of \cref{thm-identity} uses only that $G$ has an identity, not that
                  the operation is associative.
                \end{remark}

                \begin{exercise}
                  Show that the inverse of each element is unique too.
                \end{exercise}

                Further reading is listed at the end~\cite{lamport1994latex}.⟨bib⟩

                """#),
                ProjectFileTemplate(path: "references.bib", text: Self.sampleBibliography, onlyWithBibliography: true),
            ]

        case .assignment:
            return [
                ProjectFileTemplate(path: "main.tex", text: #"""
                \documentclass[⟨size⟩]{article}

                % Fonts and language
                \usepackage[T1]{fontenc}⟨pdf⟩
                \usepackage{lmodern}⟨pdf⟩
                \usepackage{fontspec}⟨unicode⟩
                \usepackage[⟨language⟩]{babel}
                \usepackage{microtype}

                % Page layout, with the course and your name on every page
                \usepackage[⟨paper⟩, margin=2.5cm, headheight=15pt]{geometry}
                \usepackage{fancyhdr}

                % Maths and graphics
                \usepackage{amsmath,amssymb,amsthm,mathtools}
                \usepackage{graphicx}
                \graphicspath{{Figures/}}
                \usepackage{enumitem}
                \usepackage[colorlinks=true, allcolors=blue]{hyperref}

                % Assignment details, defined once and used everywhere
                \newcommand{\assignmenttitle}{⟨title⟩}
                \newcommand{\assignmentauthor}{⟨author⟩}
                \newcommand{\assignmentcourse}{⟨affiliation⟩}
                \newcommand{\assignmentdate}{⟨date⟩}

                \pagestyle{fancy}
                \fancyhf{}
                \fancyhead[L]{\assignmentcourse}
                \fancyhead[R]{\assignmentauthor}
                \fancyfoot[C]{\thepage}

                % Numbered problems, with an optional title, and their solutions
                \newcounter{problem}
                \newenvironment{problem}[1][]
                  {\par\bigskip\refstepcounter{problem}\noindent
                   \textbf{Problem~\theproblem}\if\relax\detokenize{#1}\relax\else\ (#1)\fi.\quad}
                  {\par}
                \newenvironment{solution}
                  {\begin{proof}[Solution]}
                  {\end{proof}}

                \begin{document}

                \begin{center}
                  {\Large\bfseries \assignmenttitle \par}
                  \medskip
                  {\large \assignmentauthor \par}
                  \smallskip
                  {\assignmentcourse \par}
                  {\assignmentdate \par}
                \end{center}

                \begin{problem}[Warm-up]
                  Show that $\sum_{k=1}^{n} k = \frac{n(n+1)}{2}$ for every positive integer $n$.
                \end{problem}

                \begin{solution}
                  By induction on $n$. Both sides equal $1$ when $n = 1$. If the formula holds
                  for $n$, then
                  \[
                    \sum_{k=1}^{n+1} k = \frac{n(n+1)}{2} + (n+1) = \frac{(n+1)(n+2)}{2},
                  \]
                  so it holds for $n + 1$ as well.
                \end{solution}

                \begin{problem}
                  The next problem, in parts:
                  \begin{enumerate}[label=(\alph*)]
                    \item the first part;
                    \item the second part.
                  \end{enumerate}
                \end{problem}

                \begin{solution}
                  Write the solution here.
                \end{solution}

                \end{document}

                """#),
            ]

        case .presentation:
            return [
                ProjectFileTemplate(path: "main.tex", text: #"""
                \documentclass⟨slides⟩{beamer}

                % Fonts and language
                \usepackage[T1]{fontenc}⟨pdf⟩
                \usepackage{lmodern}⟨pdf⟩
                \usepackage{fontspec}⟨unicode⟩
                \usepackage[⟨language⟩]{babel}
                \usepackage{csquotes}

                % Maths, tables and graphics
                \usepackage{amsmath,amssymb}
                \graphicspath{{Figures/}}
                \usepackage{booktabs}

                % Bibliography⟨bib⟩
                \usepackage[backend=biber, style=authoryear]{biblatex}⟨bib⟩
                \addbibresource{references.bib}⟨bib⟩
                ⟨bib⟩
                % A plain look: no navigation symbols, and the slide number at the bottom right
                \setbeamertemplate{navigation symbols}{}
                \setbeamertemplate{footline}[frame number]
                \setbeamercolor{frametitle}{fg=blue!50!black}
                \setbeamercolor{title}{fg=blue!50!black}

                \title{⟨title⟩}
                \author{⟨author⟩}
                \institute{⟨affiliation⟩}
                \date{⟨date⟩}

                \begin{document}

                \begin{frame}[plain]
                  \titlepage
                \end{frame}

                \begin{frame}{Outline}
                  \tableofcontents
                \end{frame}

                % ---- Slides ----
                \input{Slides/introduction}
                \input{Slides/conclusion}

                \begin{frame}[allowframebreaks]{References}⟨bib⟩
                  \printbibliography⟨bib⟩
                \end{frame}⟨bib⟩

                \end{document}

                """#),
                ProjectFileTemplate(path: "Slides/introduction.tex", text: #"""
                % !TEX root = ../main.tex

                \section{Introduction}

                \begin{frame}{Introduction}
                  \begin{itemize}
                    \item Each part of the talk goes in a file of its own in the Slides folder.
                    \item Pictures go in the Figures folder, where \texttt{\textbackslash includegraphics} finds them.
                    \item<2-> Points can appear one at a time.
                  \end{itemize}
                \end{frame}

                \begin{frame}{Two Columns}
                  \begin{columns}[T]
                    \begin{column}{0.48\textwidth}
                      Text on the left, and a result on the right.
                    \end{column}
                    \begin{column}{0.48\textwidth}
                      \begin{block}{A Result}
                        Something worth remembering~\parencite{lamport1994latex}.⟨bib⟩
                        Something worth remembering.⟨nobib⟩
                      \end{block}
                    \end{column}
                  \end{columns}
                \end{frame}

                """#),
                ProjectFileTemplate(path: "Slides/conclusion.tex", text: #"""
                % !TEX root = ../main.tex

                \section{Conclusion}

                \begin{frame}{Conclusion}
                  \begin{itemize}
                    \item The one thing to remember.
                    \item What comes next.
                  \end{itemize}
                \end{frame}

                """#),
                ProjectFileTemplate(path: "references.bib", text: Self.sampleBibliography, onlyWithBibliography: true),
            ]

        case .letter:
            return [
                ProjectFileTemplate(path: "main.tex", text: #"""
                \documentclass[⟨size⟩, ⟨paper⟩]{letter}

                \usepackage[T1]{fontenc}⟨pdf⟩
                \usepackage{lmodern}⟨pdf⟩
                \usepackage{fontspec}⟨unicode⟩
                \usepackage[⟨language⟩]{babel}
                \usepackage{microtype}

                \signature{⟨author⟩}
                \address{Street \\ City \\ Country}

                \begin{document}

                \begin{letter}{Recipient \\ Street \\ City}

                \opening{Dear Sir or Madam,}

                Start writing here.

                \closing{Yours faithfully,}

                \end{letter}

                \end{document}

                """#),
            ]

        case .minimal:
            return [
                ProjectFileTemplate(path: "main.tex", text: #"""
                \documentclass[⟨size⟩, ⟨paper⟩]{article}

                \usepackage[T1]{fontenc}⟨pdf⟩
                \usepackage{fontspec}⟨unicode⟩

                \begin{document}



                \end{document}

                """#),
            ]
        }
    }

    /// A first entry for references.bib, so the bibliography typesets straight away.
    static let sampleBibliography = #"""
    % The bibliography. Cite an entry with \cite{key}; the document lists what it cites.

    @book{lamport1994latex,
      author    = {Leslie Lamport},
      title     = {{\LaTeX}: A Document Preparation System},
      edition   = {2},
      publisher = {Addison-Wesley},
      year      = {1994},
    }

    """#
}
