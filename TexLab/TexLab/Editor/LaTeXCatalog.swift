//
//  LaTeXCatalog.swift
//  TexLab
//

import Foundation

/// Well-known LaTeX names offered as completions.
nonisolated enum LaTeXCatalog {
    /// Commands that take a mandatory braced argument. Completing one inserts `{}`.
    static let commandsTakingArgument: Set<String> = [
        // Structure
        "part", "chapter", "section", "subsection", "subsubsection", "paragraph", "subparagraph",
        "title", "author", "date", "thanks", "caption", "label", "footnote", "footnotetext",
        "marginpar", "include", "input", "includeonly",
        // Text formatting
        "textbf", "textit", "emph", "underline", "texttt", "textsc", "textsf", "textrm",
        "textsl", "textup", "textmd", "textnormal", "textsuperscript", "textsubscript",
        "textcolor", "colorbox", "fbox", "mbox", "makebox", "framebox", "parbox", "raisebox",
        "MakeUppercase", "MakeLowercase", "enquote", "hyphenation", "url", "href",
        // References and citations
        "ref", "eqref", "pageref", "autoref", "nameref", "cref", "Cref", "vref",
        "cite", "citep", "citet", "citealp", "citeauthor", "citeyear", "parencite",
        "textcite", "autocite", "footcite", "fullcite", "nocite",
        // Packages and files
        "documentclass", "usepackage", "RequirePackage", "bibliography", "bibliographystyle",
        "addbibresource", "includegraphics", "includepdf", "lstinputlisting", "graphicspath",
        // Definitions
        "newcommand", "renewcommand", "providecommand", "newenvironment", "renewenvironment",
        "DeclareMathOperator", "newtheorem", "newcounter", "setcounter", "addtocounter",
        "stepcounter", "setlength", "addtolength", "pagestyle", "thispagestyle", "pagenumbering",
        "vspace", "hspace", "color",
        // Math
        "frac", "dfrac", "tfrac", "sqrt", "binom", "overline", "underbrace", "overbrace",
        "hat", "widehat", "tilde", "widetilde", "bar", "vec", "dot", "ddot", "mathbf",
        "mathit", "mathrm", "mathsf", "mathtt", "mathcal", "mathbb", "mathfrak", "mathscr",
        "boldsymbol", "operatorname", "text", "intertext", "tag", "substack", "boxed",
        "SI", "si", "num", "qty", "unit",
        // Beamer
        "frametitle", "framesubtitle", "only", "uncover", "alert",
        "usetheme", "usecolortheme", "institute",
    ]

    /// Commands used without arguments.
    static let commandsWithoutArgument: [String] = [
        "maketitle", "tableofcontents", "listoffigures", "listoftables", "printbibliography",
        "newpage", "clearpage", "cleardoublepage", "pagebreak", "linebreak", "newline",
        "noindent", "indent", "centering", "raggedright", "raggedleft", "item", "hline",
        "toprule", "midrule", "bottomrule", "today", "LaTeX", "TeX", "ldots", "dots",
        "cdots", "vdots", "ddots", "quad", "qquad", "smallskip", "medskip", "bigskip",
        "hfill", "vfill", "par", "tiny", "scriptsize", "footnotesize", "small", "normalsize",
        "large", "Large", "LARGE", "huge", "Huge", "bfseries", "itshape", "ttfamily",
        "scshape", "sffamily", "rmfamily", "normalfont", "frontmatter", "mainmatter",
        "backmatter", "left", "right", "big", "Big", "bigg", "Bigg", "displaystyle",
        "textstyle", "limits", "nolimits", "infty", "partial", "nabla", "forall", "exists",
        "nexists", "emptyset", "varnothing", "neg", "land", "lor", "sum", "prod", "coprod",
        "int", "iint", "iiint", "oint", "lim", "limsup", "liminf", "sin", "cos", "tan",
        "arcsin", "arccos", "arctan", "sinh", "cosh", "tanh", "log", "ln", "exp", "max",
        "min", "sup", "inf", "det", "dim", "ker", "deg", "gcd", "Pr", "to", "mapsto",
        "rightarrow", "leftarrow", "leftrightarrow", "Rightarrow", "Leftarrow",
        "Leftrightarrow", "longrightarrow", "Longrightarrow", "iff", "implies", "impliedby",
        "uparrow", "downarrow", "leq", "geq", "neq", "approx", "equiv", "sim", "simeq",
        "cong", "propto", "ll", "gg", "cdot", "times", "div", "pm", "mp", "circ", "ast",
        "star", "oplus", "otimes", "in", "notin", "ni", "subset", "supset", "subseteq",
        "supseteq", "cup", "cap", "bigcup", "bigcap", "setminus", "wedge", "vee", "perp",
        "parallel", "mid", "angle", "prime", "ell", "hbar", "Re", "Im", "aleph", "dagger",
        "alpha", "beta", "gamma", "delta", "epsilon", "varepsilon", "zeta", "eta", "theta",
        "vartheta", "iota", "kappa", "lambda", "mu", "nu", "xi", "pi", "varpi", "rho",
        "varrho", "sigma", "varsigma", "tau", "upsilon", "phi", "varphi", "chi", "psi",
        "omega", "Gamma", "Delta", "Theta", "Lambda", "Xi", "Pi", "Sigma", "Upsilon", "Phi",
        "Psi", "Omega", "langle", "rangle", "lceil", "rceil", "lfloor", "rfloor", "lVert",
        "rVert", "lvert", "rvert", "nonumber", "notag", "displaybreak", "allowbreak",
        "protect", "makeatletter", "makeatother", "relax", "centerline", "footnotemark",
        "and", "S", "P", "copyright", "dag", "ddag", "euro", "pounds", "textbackslash",
        "appendix", "titlepage", "pause",
    ]

    /// Every command name, sorted, for command completion.
    static let allCommands: [String] = (Array(commandsTakingArgument) + commandsWithoutArgument).sorted()

    static let environments: [String] = [
        "document", "abstract", "itemize", "enumerate", "description", "figure", "figure*",
        "table", "table*", "tabular", "tabular*", "tabularx", "longtable", "array",
        "equation", "equation*", "align", "align*", "gather", "gather*", "multline",
        "multline*", "flalign", "alignat", "split", "cases", "matrix", "pmatrix", "bmatrix",
        "Bmatrix", "vmatrix", "Vmatrix", "smallmatrix", "center", "flushleft", "flushright",
        "quote", "quotation", "verse", "verbatim", "lstlisting", "minted", "minipage",
        "thebibliography", "theorem", "lemma", "proposition", "corollary", "definition",
        "example", "remark", "proof", "frame", "block", "alertblock", "exampleblock",
        "columns", "column", "subfigure", "tikzpicture", "axis", "wrapfigure", "landscape",
        "algorithm", "algorithmic", "comment", "titlepage", "appendices", "multicols",
    ].sorted()

    static let packages: [String] = [
        "algorithm", "algorithm2e", "algpseudocode", "amsmath", "amssymb", "amsthm",
        "appendix", "array", "babel", "biblatex", "bm", "booktabs", "caption", "cleveref",
        "csquotes", "enumitem", "etoolbox", "fancyhdr", "float", "fontenc", "fontspec",
        "geometry", "glossaries", "graphicx", "hyperref", "imakeidx", "inputenc", "lipsum",
        "listings", "lmodern", "longtable", "makeidx", "mathtools", "mhchem", "microtype",
        "minted", "multicol", "multirow", "natbib", "parskip", "pdfpages", "pgfplots",
        "physics", "placeins", "polyglossia", "setspace", "siunitx", "subcaption", "tabularx",
        "tcolorbox", "tikz", "titlesec", "todonotes", "unicode-math", "url", "wrapfig",
        "xcolor", "xparse",
    ]

    static let documentClasses: [String] = [
        "amsart", "amsbook", "article", "beamer", "book", "elsarticle", "exam", "IEEEtran",
        "letter", "llncs", "memoir", "moderncv", "report", "revtex4-2", "scrartcl",
        "scrbook", "scrreprt", "standalone",
    ]
}
