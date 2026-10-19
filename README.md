# TexLab

TexLab is a native LaTeX editor for macOS. It is a Mac document app built like Xcode: each
file is a document with the standard File menu (New, Open Recent, Save, Duplicate,
Rename, Move To, Revert To and versions, autosave), and a project's files share one
window, which shows them one at a time. Projects are plain folders, opened from a Welcome
window like Xcode's. You write on the left — as code, or in a Visual editor close to the
typeset document — the PDF updates on the right, and the two are linked both ways with
SyncTeX.

See [CHANGELOG.md](CHANGELOG.md) for what changed in each version.

## Features

**Getting started**

- **Welcome window** — like Xcode's: Create New Project, Open Existing Project (a folder
  or a single document), Clone Git Repository, New Document, and your recent projects.
  It appears when TexLab opens (Settings can turn that off), from Window ▸ Welcome to
  TexLab (⇧⌘1), and when you click the Dock icon with no windows open. Drop a project
  folder or a document on it to open it.
- **Recent projects** — each shows a thumbnail of its typeset first page, its title,
  where it is and when you last opened it. Search them, pin the ones you use most to
  the top, and find a project that was moved with Locate…; the context menu also shows
  it in the Finder, copies its path and removes it. File ▸ Open Recent Project lists
  them too.
- **Opening a folder** — File ▸ Open Project (⇧⌘O) opens a folder at its main file:
  `main.tex`, or its only complete document. When several documents could be the main
  file, TexLab asks which one (showing their titles) and remembers the answer; a folder
  without a document gets a `main.tex` if you like.
- **Clone Git Repository** — clones a project from GitHub, GitLab or Overleaf (its Git
  address) with the git from the Xcode command line tools, then opens it. Passwords come
  from your keychain, and failures are explained in plain words.

**Writing**

- **Code and Visual editors** — each window switches between them with the Code | Visual
  control in the toolbar (⌃⌘1, ⌃⌘2), and Settings chooses which one documents open in.
  - **Code** shows the LaTeX source in the code font, with colouring and folding.
  - **Visual** is close to the typeset document, like Overleaf's Visual Editor: text in a
    serif (or sans) typeface in a page-like column, large headings, rendered formulas,
    TikZ drawings, tables and images, lists, references and included files as they will
    look, and the preamble collapsed.
    Markup appears, in the code font, wherever the insertion point is.
- **Bibliographies, read and edited like Xcode's Info editor** — a `.bib` file in the
  Visual editor is a column of cards, a page wide like the Visual editor's text: each
  entry's card shows its kind with an icon in that kind's colour, its citation key, a
  summary ("Knuth · 1984 · The TeXbook") and the kind — Journal Article, Book,
  Conference Paper, Website, PhD Thesis… — as a menu to change it. Open a card to see
  its fields by name — Authors, Title, Journal, Year, Publisher, Organization, URL — in a
  column of labels and values, as Xcode shows "Bundle display name" for
  `CFBundleDisplayName`.
  - Values read as text and are edited in place: hovering shows a soft field, clicking
    edits it with a ring around it, Return or clicking away writes it, Esc puts it back.
    Long values — titles, authors, abstracts, notes — wrap onto more lines.
  - The fields an entry's kind needs come first and are always listed, ready to fill in
    with an orange dot until they are; the card says how many are left. Add Field offers
    the ones its kind usually has, and more, and hovering a field shows a − to remove it.
  - Add Entry (which brings the new card into view), Duplicate Entry, Delete, Copy
    Citation and Show in Code from the card's ⋯ menu or its context menu, and a filter
    by key, author, title or year; a link opens a URL or DOI in the browser. Accents and
    dashes read as they print (M{\"u}ller as Müller), and each field says how to write
    it where it isn't obvious, such as names separated with "and".
  - BibTeX stays behind it: each change is written into the text as an undoable edit
    that touches only what changed — the file's comments, layout, `@string`
    abbreviations and lined-up `=` signs stay as they were — and the Code editor shows
    the BibTeX as it is. The BibTeX names button shows `booktitle` and `inproceedings`
    instead of the readable names. Edits were checked with BibTeX and biber.
- **Customisation** — the code font (any installed monospaced font) and size, line
  spacing, five colour themes (Xcode, Classic, Soft, High Contrast, Monochrome), and the
  Visual editor's typeface, size and line length, in Settings.
- **Source editor** on the Mac text system: Find and Replace, spelling, dictation,
  services, Look Up and undo behave as in every Mac app.
- **LaTeX syntax colouring** in light and dark variants of the chosen theme: commands,
  environments, math, comments, keys and verbatim text; section titles in bold. Spelling ignores markup
  and checks prose and comments only.
- **Line numbers** with the current line emphasised and issue markers; click a number to
  select the line. A subtle current line highlight.
- **Smart editing** — automatic indentation; Return after `\begin{itemize}` closes the
  environment and starts an `\item`; Return continues a list and an empty item leaves it
  (Option-Return inserts a plain line break); brackets and `$` pair automatically, and
  typing an opening bracket with a selection wraps it; Tab and Shift-Tab indent lines;
  ⌘/ comments lines.
- **Preview while editing** — while the insertion point is in a formula, a TikZ drawing,
  a table, a figure or table float, an `\includegraphics` or an `\input` of a figure,
  its typeset version floats just below the source in a small panel of Liquid Glass, in
  both the Code and the Visual editor, so you see the source and what it makes together.
  It follows your changes: the last version that typeset stays, dimmed, with a spinner
  while TeX catches up, or a warning when the source can't be typeset as it is (an
  unfinished `\frac{`, say). It moves above the source when there's no room below or the
  completion list is there, scrolls with the text, lets clicks through, and can be turned
  off in Settings ▸ Editor.
- **Rendered math in the source** — formulas (`$…$`, `\(…\)`, `\[…\]`, `$$…$$` and
  math environments such as `equation` and `align`) are shown typeset right in the
  editor, with the document's own macros, until the insertion point enters them; then
  their source appears for editing. Click a formula to edit it. Display math is centred
  on its line like in the PDF. Formulas are drawn in the text colour, so they follow Dark
  Mode (colour set with `\color` inside a formula isn't shown).
- **What the Visual editor shows** — the markup comes back wherever the insertion point
  is:
  - `\section{…}` and the other headings show as large bold titles, `\title` and
    `\author` as a title block, and `\maketitle` as the title and author centred.
  - `\begin{abstract}` shows a centred Abstract heading; theorem-like environments
    (theorem, lemma, definition, …) show "Theorem (title)."; proofs show "Proof." and ∎.
  - Lists show bullets (•, –, ∗, ·) and numbers (1., (a), i., A.) in place of `\item`,
    with the `\begin{itemize}` lines hidden; quote and center markers are hidden too.
  - `\emph`, `\textbf`, `\textit`, `\texttt`, `\textsc`, `\textsf`, `\textrm`,
    `\underline` and `\sout` style their argument, nesting like in TeX.
  - `\ref`, `\eqref`, `\cref`, `\cite` (and variants) and `\label` show as chips;
    `\url` and `\href` as links; footnotes in small grey text.
  - `\includegraphics` shows the image itself; `---`, `--`, ``` `` ```, `''`, `\ldots`,
    `\LaTeX` and escapes such as `\&` show as the characters they produce.
  - TikZ drawings (`tikzpicture`, `circuitikz`, `forest`) and tables (`tabular`,
    `tabular*`, `tabularx`, `tabulary`) show typeset, with the document's own preamble,
    on a small piece of white paper so their colours stay true in Dark Mode. A whole
    `figure` or `table` float shows as one piece of paper — its picture, drawing or
    table, centred, with the caption typeset beneath (as "Table: …", since the number
    depends on the rest of the document) — instead of `\begin{table}[H]`, `\centering`
    and `\caption` around it. Click one, or move the insertion point into it, to edit
    its source. They're typeset in the background in a run of their own, so a slow or
    broken drawing never holds up the formulas, and one TeX can't typeset stays as source
    (a float that can't be typeset shows the drawing or table in it instead).
  - `\input`, `\include` and `\subfile` show as chips like references', naming the part
    by its first heading (a file that isn't there is marked). A file holding a figure
    shows its picture with the caption beneath, and one holding a drawing or table
    shows it typeset, so `\input{Figures/results}` looks like the figure. ⌘-click a chip
    to open the file.
  - `\begin{document}` and `\end{document}` are hidden; `\tableofcontents`, lists of
    figures and tables and the bibliography show as headings; page breaks and
    `\appendix` as chips.
- **Code folding** — collapse sections (the heading stays visible), the preamble, blocks
  of comments and any environment of two or more lines with the chevron beside a line
  number, or View ▸ Code Folding, which can also fold every section or the preamble at
  once. A collapsed figure or table shows its
  caption, line count and a thumbnail of its image; click it to expand it again. Fold
  Figures and Tables tidies a long document in one step, and Settings can do this for
  every document you open. Folding never changes the text: moving the insertion point
  into a collapsed environment, or deleting next to it, expands it.
- **Completion as you type** — a list like Xcode's appears under the insertion point:
  - `\` and a letter: commands, with what common ones do, and the ones your project
    defines (with their arguments);
  - `\ref{`, `\eqref{`, `\cref{` …: every label in the project, with the caption, heading
    or kind of environment it names and the file it's in, those of the file on screen first;
  - `\cite{` and its variants: the project's bibliography, matched by key, author, title or
    year, with the entry shown in full at the bottom — and again after each comma;
  - `\input{`, `\include{`, `\includegraphics{`, `\bibliography{` …: the project's files,
    with the paths TeX expects;
  - `\begin{` and `\end{`: environments, the one to close first; `\usepackage{` and
    `\documentclass{`: packages and classes, the project's own included.
  It refines as you type (prefixes first, then word starts such as `res` for
  `fig:results`, then letters in order); ↑ ↓ choose, Return or Tab accepts, Esc
  dismisses, and Esc opens it anywhere. Accepting a command adds its braces (Tab moves
  between them), opens the list for its argument where that helps, and accepting an
  environment closes it.
- **Customisable toolbar** — View ▸ Customize Toolbar offers more than 50 tools to drag
  in, so each writer can lay it out their way. The default set, like Xcode's:
  - at the leading edge, before the window's title, Typeset and Code | Visual — Typeset
    is Stop while TeX runs, like Xcode's Run, and holding it offers the engine, automatic
    typesetting, the log and a clean start;
  - the title, which is the project's name; the bar above the editor names the file shown;
  - at the trailing edge, in three groups of Liquid Glass: the status — "Typeset · 12
    pages", "Typesetting…" with a spinner, or what went wrong, beside the number of errors
    and warnings; click it for the log, or the counts for the Issues navigator — then
    Heading, Figure, Table, Math, Theorem, Symbols and Add Package, and last Preview and
    Share.

  Items side by side share one capsule; dragging Space from the palette between two
  items separates them, and dragging items next to each other groups them. No tool or
  space sits over the sidebar, so hiding it hides none. The palette adds Cite and
  Reference (quick to type with completion), a List menu and individual headings; images,
  lists, footnotes, links, quotes and code listings; inline, display, numbered and
  aligned math, matrices and fractions; text styles, comments and indentation; Beamer
  slides, columns and blocks; Stop, the engine, issues and an issue count, the log, zoom,
  folding, find, go to line and word count; and export, print, New File and Show in
  Finder.
- **Packages a command needs** — type `\mathbb{R}` without amssymb, or
  `\begin{align}` without amsmath, and a small bar of Liquid Glass above the line asks
  "\mathbb needs the amssymb package. Add amssymb · Not Now"; typing carries on, and
  nothing is added without a click. The use is also a live issue with an Add button, and
  the editor's context menu offers it. Nearly 300 commands and environments of about 70
  packages are known — symbols, amsmath and mathtools, graphicx, xcolor, hyperref,
  cleveref, booktabs, siunitx, TikZ and pgfplots, listings, biblatex and natbib, and more
  — each checked with TeX Live to be missing from plain LaTeX and defined by the package
  offered. `\usepackage` counts however it's written, options and lists over several
  lines included. Packages the class loads (Beamer loads amsmath, amssymb and hyperref, say),
  packages other packages load (mathtools loads amsmath), the project's own packages and
  preamble files, and commands the project defines all count; with a class it doesn't
  know, the check stays quiet. Settings ▸ Editor turns it off.
- **Add Package** — the toolbar's Add Package and Insert ▸ Package… list common packages
  with what each is for, mark those the document already loads, and add any other by
  name, with options such as `margin=2cm`; the package goes in after the others, in the
  main file's preamble for a part of a project.
- **Cite and Reference** — Cite searches the project's bibliographies by key, author,
  title or year and inserts `\cite` (or `\citep`, `\autocite`, …) for one or more
  entries; Reference lists every label by kind and inserts `\eqref` for equations and
  `\ref` otherwise.
- **Tools that keep documents working** — inserting a figure loads graphicx, a table
  file booktabs, a drawing tikz, a link
  hyperref, aligned equations amsmath, a code listing listings, `\cref` cleveref, and a
  theorem loads amsthm and adds its `\newtheorem` definition.
- **Insert menu** — headings, lists, figures and images, tables of any size, math,
  theorems, references, environments, slides, spacing and breaks, fitted to the current
  indentation.
- **Placeholders** — what you insert marks the places still to fill in: a figure's
  caption and label, a fraction's denominator, a table's cells. Tab moves to the next
  place and Shift-Tab to the previous one, and each place shows as a faint insertion
  point. Completing `\frac`, `\href`, `\newcommand` and other commands with several
  arguments works the same way. The text holds nothing extra, and Tab indents as usual
  once you leave the snippet.
- **Format menu** — ⌘B, ⌘I and ⌘U wrap the selection in `\textbf`, `\textit` and
  `\underline` (and unwrap it again), plus emphasis, monospace, small caps and sans serif.
- **Symbols palette** — searchable Greek letters, relations, operators, arrows and text
  symbols; math symbols get `$…$` when inserted outside math.
- **Drag and drop** — drop images, `.tex` or `.bib` files onto the editor to insert
  `\includegraphics`, `\input` or `\bibliography` with a path relative to the document.
- **Templates** — File ▸ New from Template: Article, Report, Thesis, Lecture Notes,
  Assignment, Presentation (Beamer), Letter and Blank, each as one document — the same
  templates New Project makes as folders.

**Projects**

- **One window for the whole project** — like Xcode, a project window shows any text
  file of its project: click a chapter in the project navigator (or step through files
  with the arrow keys) and the editor shows it, while the preview keeps showing the whole
  document. Search results, issues, ⌘-clicks in the PDF and Jump to Definition open files
  the same way, and so does opening a chapter from the Finder or Open Recent while its
  project is open. The window's title is the project's name, as in Xcode, and otherwise
  the window is the shown file's: its proxy icon and edited dot are that file's, and
  File ▸ Save, Rename, Move To, Duplicate and Revert To act on it.
  Every file is a Mac document that saves itself and keeps versions, its own undo history,
  insertion point, scroll position and folds, and picks up changes other apps make. The
  bar above the editor goes back and forward through the files you've shown (⌃⌘← and
  ⌃⌘→), lists the files open in the window, and returns to the main file (⌃⌘↑); File ▸
  Close File (⌃⌘W) closes one, and closing the window closes them all. Typesetting from a
  chapter typesets the whole document, with the unsaved text of every open file.
- **Navigators** — the sidebar has five, like Xcode's, chosen from the row of icons at its
  top or with ⌘1–⌘5: Project, Outline, Find, References and Issues; the Issues icon
  shows how many there are. The row of icons, the search and filter fields and the bars
  of buttons float on Liquid Glass over the lists, which scroll beneath them.
- **Document section** — the project navigator lists the main file and the chapters it
  includes (`\input`, `\include`, `\subfile`, `\import`) in reading order, each with its
  first heading, nested as deeply as they are included, then the bibliographies; click
  one to write in it. A filter field at the bottom finds any file of the project by name.
- **Outline of the whole document** — the Outline navigator can show the file on screen
  or the whole document across all its files, in reading order; selecting a heading in
  another chapter opens that chapter at it.
- **Jump to Definition** — ⌘-click (or ⌃⌘J, or the context menu) goes from a reference
  to its `\label`, from a citation to its bibliography entry, from `\input`,
  `\includegraphics` or `\bibliography` to the file, from a command to its
  `\newcommand`, and from `\begin{…}` to its `\end{…}` — in any file of the project.
- **Find in Project** (⇧⌘F) searches every LaTeX file, bibliography and package as you
  type, including unsaved changes, with Match Case and Whole Words; selecting a result
  shows it.
- **References navigator** — every label (by kind) and bibliography entry in the project;
  double-click to refer to it, drag it into the text, or go to its definition.
- **Project navigator** — the first sidebar tab lists the files of the project's folder in
  a native sidebar outline, like Xcode's and the Finder's: LaTeX files, bibliographies,
  packages, images and folders, with the main file marked. As in Xcode, files go by their
  names — `introduction`, not `introduction.tex` — and the icon says what each is, in its
  kind's colour: green for LaTeX, orange for bibliographies, purple for packages, classes
  and bibliography styles (each with its own symbol), teal for images and red for PDFs.
  Other files keep their extension, the help tag shows the whole name and VoiceOver says
  the kind. Renaming edits the name and keeps the extension unless you type another one.
  The bar above the editor, Find, the Issues list and the reference pickers name files
  the same way. Click a file to show it in the
  editor; the arrow keys and type-to-select step through files with the keyboard still in
  the list, and the selection follows the file on screen. Double-click or ⌘↓ goes to the
  file (images and PDFs open in their usual app), Return renames it in place, ⌘⌫ moves it
  to the Trash, and dragging moves files between folders, copies files in from the
  Finder, or drops a reference into the editor — `\input`, `\includegraphics`,
  `\bibliography` or `\usepackage` with the right relative path. The context menu opens,
  opens in a new window, references, renames, shows in Finder or moves to the Trash the
  clicked row or the selection; New Folder names the folder in place. Copy Path copies a
  file's path relative to the main file — what `\includegraphics` and `\input` expect —
  and Copy LaTeX Reference the whole command. Renames and moves are coordinated, so open
  files follow them, and the list follows changes made in the Finder.
- **New File in Project** (⌥⌘N, or + in the navigator) works like Xcode's New File: pick
  what to make from the list on the left, fill in what it needs on the right, and it's
  made ready to use, in the folder the project keeps such files in unless you choose
  another:
  - **Section or Chapter** — starts with the heading its document uses (a chapter in a
    report or thesis, a section in an article, a section and a first slide in a
    presentation), goes in Sections, Chapters, Lectures or Slides, and its `\input{…}`
    goes in the main file after the last part — before the references, the appendices
    and the page break or slide in front of them, never in the title page.
  - **Empty File** — a LaTeX file with nothing in it, or any other text file when you
    give it an extension, such as `.txt` or `.cfg`.
  - **Figure** — a picture from your Mac, copied into Figures, in a `figure` environment
    of its own file: centred, sized to the line, with a caption and a `fig:` label. It's
    named after the picture, and without one it has a frame to replace later.
  - **Table** — the rows and columns you choose, with booktabs rules, the caption above
    and a `tab:` label.
  - **TikZ Drawing** — a figure drawn with TikZ, to edit, with a caption and a label.
  - **Images** — pictures or PDFs from your Mac, copied into Figures, with a figure for
    each inserted where you're writing; the insertion point waits in the first caption
    and Tab moves to the next. Add Images… in the navigator's + and context menus goes
    straight to choosing them.
  - **Document from Template** — a complete document of its own, from any template.
  - **Bibliography** and **Package** — added to the main file as `\bibliography` (or
    `\addbibresource` for biblatex) and `\usepackage`.

  A figure, table or drawing goes in where you're writing as `\input{…}` — in the body,
  never the preamble, when the insertion point is still at the top of a file just
  opened — and the package it needs (graphicx, booktabs or tikz) joins the preamble. The
  sheet shows the file's path before it's made, and every change to an open file is
  undoable. Insert ▸ Figure from Image copies a picture from elsewhere into the project
  too, so the project keeps working when it's moved or shared.
- **New Project** (⇧⌘N) opens a template chooser like Xcode's, a gallery with a sketch of
  each template's first page:
  - **Article** — a title page with the title, author, affiliation, date, the abstract
    and a copyright notice; then the introduction and the sections, one file each in
    `Sections/`; then the references on a page of their own. `Figures/` holds the
    pictures, found by name, and `references.bib` the bibliography, read with biblatex
    and biber.
  - **Report** — a title page, the abstract and contents, and chapters in `Chapters/`.
  - **Thesis** — a title page with the degree and university, abstract,
    acknowledgements, contents and lists of figures and tables in `FrontMatter/`,
    chapters in `Chapters/`, appendices in `Appendices/`, then the references.
  - **Lecture Notes** — numbered theorems, definitions, examples and exercises with
    `cleveref`, a running head with the course and section, and a file per lecture in
    `Lectures/`.
  - **Assignment** — numbered problems with solutions, and the course and your name at
    the top of every page.
  - **Presentation** — Beamer slides without the navigation clutter, a file per part of
    the talk in `Slides/`, and references on a slide of their own.
  - **Letter** and **Blank**.

  Beside the gallery go the project's name, title, author and affiliation, the language
  (for hyphenation, quotation marks and the names TeX prints, such as "References"), the
  paper (A4 or US Letter, from your region) and font size — or widescreen or standard
  slides — the engine, and whether to include the bibliography. TexLab then asks where to
  save the folder, and remembers your choices for the next project. Every template but
  Blank typesets as created, with pdfLaTeX, XeLaTeX and LuaLaTeX, with or without the
  bibliography.
- **Main file** — a part of a project is typeset through the file that includes it, found
  automatically when it has no `\documentclass`, or named with `% !TEX root` (the
  navigator's "Use as Main File for This Document" writes that comment). Completion
  offers `\label`s from every file of the project and keys from all its bibliographies,
  and file paths are relative to the main file, where TeX looks for them.

**Typesetting and preview**

- **Typeset** with ⌘R, or automatically after a pause in typing. Unsaved changes are
  included, and auxiliary files stay out of your folders.
- **Engines** — pdfLaTeX, XeLaTeX or LuaLaTeX, chosen per document with Typeset ▸ Engine
  (which writes a `% !TEX program` comment other editors understand — into the main file
  when a chapter is on screen) or by default in Settings. latexmk is used when installed; otherwise TexLab runs BibTeX/Biber, makeindex
  and repeated passes itself.
- **Bibliography problems explained** — what Biber and BibTeX report goes into the Issues
  navigator with TeX's own: a mistake in a `.bib` file at its line, an
  `\addbibresource` naming a file that isn't there (or leaving out `.bib`), and, when
  TeX still asks for Biber at the end, that Biber isn't installed and how to install it,
  or why it couldn't run, in its own words — rather than citations quietly undefined and
  an empty bibliography. Show Output opens what the tools printed, and any issue's
  message can be copied from its context menu. latexmk won't run Biber again after it failed until its files
  change, so when the bibliography is still missing and latexmk didn't try, TexLab has it
  run every step once more.
- **Multi-file projects** — add `% !TEX root = main.tex` to a chapter and typesetting it
  typesets the whole project, including the chapter's unsaved text.
- **Live preview** that keeps its place and zoom as the document changes.
- **SyncTeX** — ⌘-click the PDF (or Show in Source) to jump to the source line, even in
  another file; ⇧⌘J (or Show in PDF) highlights the text a line produced.
- **Issues** — errors, warnings and bad boxes with file and line in the sidebar, grouped
  by file, and in the gutter; ⌘' moves through them. The full log is one click away.
- **Live issues** — like Xcode's, found as you type, before typesetting: environments
  and braces that aren't closed or don't match, references to labels nothing defines,
  citations missing from the bibliography, and labels defined twice. They read the text
  as TeX does (comments, `\verb`, verbatim environments, URLs, definitions and
  conditionals) and stay quiet when they can't be sure. Settings can turn them off.
- **Outline** — a sidebar tree of parts, chapters, sections, Beamer frames, figures and
  tables that follows the insertion point.
- **Share, export and print** the PDF, named after the document.
- **Encodings** — UTF-8, UTF-16, Windows-1252, Latin-1 and Mac OS Roman files are opened
  and saved in their own encoding.

## Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| Typeset / Stop | ⌘R / ⌘. |
| Show in PDF (forward search) | ⇧⌘J |
| Show in Source (inverse search) | ⌘-click in the PDF |
| Next / Previous Issue | ⌘' / ⇧⌘' |
| Show Log | ⇧⌘L |
| Clean Build Files | ⇧⌘K |
| Bold / Italic / Underline | ⌘B / ⌘I / ⌘U |
| Comment Selection | ⌘/ |
| Shift Right / Left | ⌘] / ⌘[ or Tab / ⇧Tab |
| Next / Previous placeholder (in an inserted snippet) | Tab / ⇧Tab |
| Show completions / dismiss | Esc |
| Choose / accept a completion | ↑ ↓ / Return or Tab |
| Go to Line (`line` or `line:column`) | ⌘L |
| Code / Visual editor | ⌃⌘1 / ⌃⌘2 |
| Project, Outline, Find, References, Issues navigators | ⌘1 … ⌘5 |
| Find in Project | ⇧⌘F |
| Go Back / Go Forward (files shown) | ⌃⌘← / ⌃⌘→ |
| Show Main File | ⌃⌘↑ |
| Close File / Close Window | ⌃⌘W / ⌘W |
| Project navigator: go to file / rename / move to Trash | ⌘↓ or double-click / Return / ⌘⌫ |
| Jump to Definition | ⌘-click or ⌃⌘J |
| Fold / Unfold | ⌥⌘← / ⌥⌘→ |
| Fold Figures and Tables / Unfold All | ⌃⌥⌘← / ⌃⌥⌘→ |
| Bigger / Smaller Text | ⌘+ (or ⌘=) / ⌘- |
| Show/Hide Preview | ⌥⌘P |
| Show/Hide Sidebar | ⌃⌘S |
| PDF Zoom In / Out / Actual Size / Fit | ⌘> / ⌘< / ⌘0 / ⌘9 |
| Export PDF / Print | ⇧⌘E / ⌘P |
| New Project / Open Project | ⇧⌘N / ⇧⌘O |
| Welcome window | ⇧⌘1 |
| New File in Project | ⌥⌘N |

## Requirements

- macOS 27 or later, Xcode 27 or later.
- A TeX distribution — [MacTeX](https://tug.org/mactex/) is recommended; BasicTeX,
  TeX Live, Homebrew and MacPorts installations are found too.
- Clone Git Repository uses git from Xcode or its command line tools
  (`xcode-select --install`).

## Getting started

1. Open `TexLab/TexLab.xcodeproj` in Xcode.
2. Choose your team under **Signing & Capabilities** for the TexLab target.
3. Check that App Sandbox is off (see below; the project already has it off).
4. Build and run (⌘R).

### Manual steps in Xcode

These are left to you on purpose, because Xcode owns them:

- **App Sandbox (off — done).** TexLab typesets with the TeX distribution installed on
  your Mac, like TeXShop and TeXstudio. A sandboxed app can't run programs from
  `/Library/TeX` or `/usr/local/texlive`, and anything it runs inherits the sandbox, so TeX
  couldn't read the chapters, images and bibliographies next to your documents either.
  Select the **TexLab** target ▸ **Signing & Capabilities** ▸ **App Sandbox** ▸ click the
  trash button. Hardened Runtime can stay on. If the sandbox is ever turned back on,
  TexLab still runs and explains in the preview and in Settings that TeX is blocked.
- **App icon (done).** The icon was drawn in Pixelmator Pro and assembled in Icon
  Composer; its sources live in `icon/` (`TexLab.icon`, the layer SVGs and the Pixelmator
  document), and the exported sizes, including dark and tinted variants, are in
  `Assets.xcassets/AppIcon`. The Welcome window shows it too. Update it in those tools
  rather than by editing the asset catalog by hand.
- **Localization (optional).** All user-facing text uses `String(localized:)` or SwiftUI
  string keys. Add a String Catalog (File ▸ New ▸ File ▸ String Catalog) and Xcode will
  collect every string at build time.
- **Tests (optional).** The project has no test target yet. The parsers
  (`LaTeXTokenizer`, `LaTeXLogParser`, `SyncTeXData`, `OutlineParser`, `MagicComments`,
  `WordCounter`) are pure, `nonisolated` code designed to be unit-tested once a test
  target is added in Xcode.

## Architecture

The Xcode project uses a synchronized folder group, so every Swift file under
`TexLab/TexLab/` belongs to the app target automatically — no project file edits needed.

```
TexLab/TexLab/
├── App/            App entry point, project windows and menu commands
├── Document/       NSDocument per file, templates, per-window session, outline
├── Editor/         Source editor (AppKit text system), syntax, completion, snippets
├── Typesetting/    TeX discovery, typesetting pipeline, log parsing, SyncTeX
├── Preview/        PDF preview and navigation
├── Project/        Project folders and templates, main file detection, new files and references
├── Views/          Window layout, sidebar, toolbar, sheets, Settings
└── Support/        Settings keys and defaults, paths, text statistics
```

- **Documents** — TexLab uses AppKit's document architecture, the one Xcode is built on.
  Each text file is a `TeXDocument` (`NSDocument`) holding its text and encoding, with
  autosave in place, versions, and NSDocument's handling of renames, moves and changes
  made by other apps. `Info.plist` names it as the class for every document type; the
  types are imported UTIs (`org.tug.tex`, `.bib`, `.sty`, `.cls`), the identifiers other
  Mac TeX editors use, so TexLab cooperates rather than claiming ownership.
  `TeXDocumentController` (made first, in the app delegate, so it is the shared one) gives
  new documents the Article template, opens text files without a type of their own as
  plain text, and keeps files a window opens for itself out of Open Recent.
- **Project windows** — `ProjectWindowController` is an `NSWindowController` hosting the
  SwiftUI window content (`ProjectWindowView`, through `NSHostingController`, whose
  toolbar it bridges; each open window has its own toolbar identifier, as AppKit links
  toolbars that share one and SwiftUI's bridge inserts items one by one). A project's documents share it: showing one moves the window
  controller to that document (`removeWindowController` / `addWindowController`), so
  the proxy icon, edited dot and the File menu's document commands follow the file on
  screen, while `windowTitle(forDocumentDisplayName:)` gives the project's name, as in
  Xcode. A document opened from the Finder or Open Recent finds its
  window by its main file, or by the folder for a bibliography or package. Closing the
  window asks each document to close (`canClose`, which autosaves), and closing a
  document shows another; the window remembers its other open files for state
  restoration. SwiftUI keeps the Welcome, New Project and Settings windows and the menu
  bar; `ActiveSession` tells the menu commands which project window is main.
- **Session** — `DocumentSession` (`@Observable`) is the per-window model: editor and
  preview controllers, caret position, word count, outline, typesetting state and issues.
  Extensions add typesetting (`+Typesetting`) and SyncTeX navigation (`+Sync`).
- **Editor** — `SourceTextView` is a TextKit 1 `NSTextView` subclass hosted by
  `SourceEditor` (`NSViewRepresentable`) inside `EditorScrollView`, which sizes the text
  view to the visible area on every layout. TextKit 1 gives precise line geometry for the
  gutter (`LineNumberRulerView`) and current line highlight. `LaTeXTokenizer` is a
  single-pass scanner shared by colouring, spelling suppression and the word count;
  `SyntaxHighlighter` re-colours only the paragraph block around an edit (TeX resets math
  mode at blank lines), as its own attribute-only edit straight after the change —
  changing attributes inside the character edit would make NSTextView move the insertion
  point to the end of the paragraph. `SyntaxTheme` builds fonts and colours from the
  settings and the editor mode. `LineIndex` maps offsets to lines incrementally.
  Snippet placeholders (`SourceTextView+Placeholders`) are positions kept in step with
  each edit, like the folds, never characters in the text, so a placeholder can't be
  saved or typeset by mistake.
- **Live preview in the editor** — `MathScanner`, `VisualScanner` and `FoldScanner` (in
  `Editor/Presentation/`) find formulas and foldable environments after each pause in
  typing. `PresentationLayoutManager` shows a range as a drawing without touching the
  text, with the standard TextKit 1 technique: its first character becomes a control
  glyph as wide as the drawing, the rest get null glyphs, line breaks inside get zero
  advancement, and the line grows to fit. `MathRenderer` typesets every new formula in
  one TeX run with the `preview` package, whose `auctex` option reports each formula's
  depth so it sits on the baseline, and TikZ drawings and tables (`MathRegion` with
  `isBlock`) in a second run, outside math; the session (`+Math`) caches images per
  formula and preamble and renders in the background. `InclusionPreview` works out what
  an `\input` shows — the part's heading, or the included figure's picture, drawing or
  table — from the file's text, which the session reads again only when it changes.
- **Completion** — `CompletionEngine` (pure) decides what is being completed at the
  insertion point and ranks candidates from `CompletionSources`, which the session gathers
  from the file on screen and the project snapshot (labels with what they name, bibliography
  entries, files, defined commands and environments). `CompletionPopup` is a borderless,
  non-activating child panel with a SwiftUI list, so the keyboard stays with the text;
  `SourceTextView+Completion` opens, refines and accepts.
- **Live issues** — `LiveChecker` reads the text in one pass, as TeX does — comments,
  control sequences, braces, `\if … \fi` and environments, skipping verbatim text —
  off the main thread after each pause in typing; environments begun inside a brace
  group or a conditional belong to it, so definitions don't look unbalanced. The session
  (`+LiveIssues`) gives it what the project snapshot knows: labels in other files,
  bibliography entries and verbatim environments defined in packages.
- **Typesetting** — `TeXDistribution` finds TeX without relying on the shell `PATH`.
  `Typesetter` writes the editor text to a build folder in
  `~/Library/Caches/com.gdinisio.TexLab/Typeset` and runs TeX in the document's folder
  through `ProcessRunner` (async `Process` wrapper with cancellation, a time limit and
  file-based output so pipes can't stall). `LaTeXLogParser` turns the log into issues;
  `SourceMap` maps the paths TeX reports (build copy, overlay, relative paths) back to the
  files you edit; `SyncTeXData` parses uncompressed SyncTeX with a byte-level parser.
- **Document structure** — `DocumentStructure` follows the main file through what it
  includes, in the order TeX reads it, as part of the project scan: the parts listed in
  the navigator and the outline of the whole document, with each included file's
  headings spliced in where it is read.
- **Documents of a window** — one `SourceTextView` shows a window's documents in turn
  (`DocumentSession+Files`): switching stores the insertion point, scroll position and
  folds, puts the other document's text in, and the text view takes its undo manager from
  the document, so undo never reaches a file that isn't on screen and the document knows
  from it whether it has unsaved changes. The document controller keeps each file to one
  document, and so to one window. The session's `fileURL` and `text` describe the shown
  document, so the outline, live preview, live issues and Jump to Definition follow it;
  typesetting overlays the unsaved text of the window's other documents for TeX.
- **Project navigator** — `ProjectNavigatorOutline` wraps an `NSOutlineView` in the
  source-list style: SwiftUI's `List` on macOS stops selecting rows that can be dragged,
  and the outline view brings the Finder's behaviour — type-select, inline renaming,
  drag and drop, a context menu for the clicked row or the selection, and folders that
  stay open per project. Rows are `NavigatorNode` objects reused by path, so open folders
  and the selection survive each rescan. `FileOperations` moves files through
  `NSFileCoordinator`, off the main thread, so open documents follow.
- **Projects** — a project is the main file's folder, not a new file format, so projects
  stay plain folders other TeX tools understand. `ProjectIndex` builds a
  `ProjectSnapshot` off the main thread (file tree, main file, labels and citation keys of
  the other files); `DirectoryWatcher` (a dispatch source per folder) and app activation
  keep it current.
- **Templates** — `DocumentTemplate` lists the templates; `ProjectTemplates.swift` holds
  each one's folders and files as plain LaTeX with placeholders (`⟨title⟩`, `⟨paper⟩`,
  `⟨language⟩`…) and line markers (`⟨bib⟩`, `⟨nobib⟩`, `⟨pdf⟩`, `⟨unicode⟩`) that
  `ProjectSetup` fills in from the New Project window, so each template reads as the
  document it makes. New from Template inlines each `\input` to make the same document
  as one file.
- **Toolbar and navigators** — `EditorToolbar` is SwiftUI `CustomizableToolbarContent`,
  split into groups of related tools so AppKit's customisation palette offers them all,
  attached to the split view's detail column so nothing lands over the sidebar, with
  Typeset and Code | Visual in the `.navigation` placement before the title and
  `ToolbarSpacer`s between the trailing groups so each has its own glass;
  tools insert through `DocumentSession+Insert`, which adds the packages and definitions
  they need. `ProjectSearch` and `ReferenceScanner` back the Find and References
  navigators and the Cite and Reference pickers. `DefinitionFinder` reads what is under
  the pointer for Jump to Definition, and the project snapshot also lists the commands
  the project's other files and packages define.
- **Welcome window** — a SwiftUI `Window` scene presented at launch
  (`defaultLaunchBehavior`), dismissed when a project window opens; the app delegate
  stops the untitled document at launch, keeps TexLab open without windows and reopens
  the Welcome window from the Dock. `RecentProjects` keeps recent folders,
  with their titles and pins, in the user defaults; `ProjectThumbnails` draws the first
  page of the PDF in each project's build folder in the background. `ProjectOpener`
  finds a folder's main file, `GitCloner` runs `git clone` through `ProcessRunner`
  without ever waiting for a password prompt, and the New Project window
  (`NewProjectView`, its own `Window` scene) turns a `ProjectSetup` into `main.tex`.
- **Preview** — `SyncPDFView` (`PDFView` subclass) restores the scroll position when a
  new PDF arrives, handles ⌘-click and highlights forward-search results.
- **Imports** — the target enables `MemberImportVisibility`, so each file imports every
  framework whose members it uses (Foundation, CoreGraphics, AppKit, PDFKit, SwiftUI,
  UniformTypeIdentifiers); re-exports from another framework don't count.
- **Concurrency** — the project builds with Swift's default `MainActor` isolation. Code
  that runs off the main thread (decoding, typesetting, parsing) is explicitly
  `nonisolated` and `Sendable`; typesetting runs in a detached task and results are
  applied on the main actor.

## Implementation notes

- The log parser and SyncTeX search were validated against real TeX Live 2023 output
  (pdfTeX, XeTeX, LuaTeX logs; `synctex` command-line results).
- Typesetting uses `-interaction=nonstopmode -file-line-error -synctex=-1` and sets
  `max_print_line=10000` so log lines aren't wrapped.
- `% !TEX root` projects: the edited file's unsaved text is written to an overlay folder
  that TeX searches first (`TEXINPUTS`). Paths written as `./chapter` bypass TeX's search
  path, so for those the saved file is used.
- An untitled document is typeset in its build folder, so files it references by
  relative path are found once the document is saved.
- Rendered formulas are typeset at 10 pt in `article` with the document's preamble (the
  root file's for `% !TEX root` chapters) and scaled to the editor font. If that preamble
  doesn't typeset on its own, `amsmath` and `amssymb` are used instead. This needs the
  `preview` package, which MacTeX includes; Settings ▸ Editor says when it's missing.
- Shell escape is off by default and can be enabled in Settings for packages such as
  minted.

## License

Copyright © 2026 Giovanni Di Nisio. All rights reserved.
