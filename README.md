# TexLab

TexLab is a native LaTeX editor for macOS. It is a document-based SwiftUI app built on
the Mac text system and PDFKit: every window is a `.tex` document with the standard File
menu (New, Open Recent, Save, Duplicate, Rename, Move To, Revert To and versions,
autosave), window tabs and full screen. Projects are plain folders, opened from a Welcome
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
    serif (or sans) typeface in a page-like column, large headings, rendered formulas
    and images, lists and references as they will look, and the preamble collapsed.
    Markup appears, in the code font, wherever the insertion point is.
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
  in, so each writer can lay it out their way. The default set covers most writing: Code
  | Visual, Typeset, Heading, Figure, Table, Math, Symbols, Cite, Reference, Preview and
  Share. The palette adds individual headings; images, lists, footnotes, links, quotes
  and code listings; inline, display, numbered and aligned math, matrices, fractions and
  theorems; text styles, comments and indentation; Beamer slides, columns and blocks;
  typesetting, engine, issues, log, zoom, folding, find, go to line and word count; and
  export, print and project files.
- **Cite and Reference** — Cite searches the project's bibliographies by key, author,
  title or year and inserts `\cite` (or `\citep`, `\autocite`, …) for one or more
  entries; Reference lists every label by kind and inserts `\eqref` for equations and
  `\ref` otherwise.
- **Tools that keep documents working** — inserting a figure loads graphicx, a link
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
- **Templates** — File ▸ New from Template: Article, Report, Book, Presentation (Beamer),
  Letter and Blank.

**Projects**

- **One window for the whole project** — like Xcode, a window shows any text file of its
  project: click a chapter in the project navigator (or step through files with the
  arrow keys) and the editor shows it, while the preview keeps showing the whole
  document. Search results, issues, ⌘-clicks in the PDF and Jump to Definition open files
  the same way. Each file keeps its own undo history, insertion point, scroll position
  and folds. The bar above the editor goes back and forward through the files you've
  shown (⌃⌘← and ⌃⌘→), lists the files open in the window, and returns to the main file
  (⌃⌘↑). Files other than the window's own document are saved a moment after you stop
  typing, when you switch away and when the window closes, and changes made by other
  apps are picked up. Typesetting from a chapter typesets the whole document, with the
  unsaved text of every open file. A file is only ever edited in one window: opening one
  that another window shows brings that window forward.
- **Navigators** — the sidebar has five, like Xcode's, chosen from the row of icons at its
  top or with ⌘1–⌘5: Project, Outline, Find, References and Issues; the Issues icon
  shows how many there are.
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
- **Project navigator** — the first sidebar tab lists the files of the document's folder,
  like Xcode's: LaTeX files, bibliographies, packages, images and subfolders, with the
  main file marked. Select a file to show it in the editor (double-click images and PDFs
  to open them in their usual app, or use Open in New Window), drag it into the editor to insert `\input`,
  `\includegraphics`, `\bibliography` or `\usepackage` with the right relative path, and
  use the context menu to open, reference, rename, show in Finder or move to the Trash.
  Copy Path copies a file's path relative to the main file — what `\includegraphics`
  and `\input` expect — and Copy LaTeX Reference the whole command.
  The list follows changes made in the Finder.
- **New File in Project** (⌥⌘N, or + in the navigator) creates a section or chapter, a
  BibTeX bibliography, a package or a complete document in any folder of the project, and
  can add it to the main file: `\input{…}` before `\end{document}`, the bibliography
  (`\bibliography` or `\addbibresource` for biblatex), or `\usepackage` in the preamble —
  in the main file's window if it's open, as an undoable edit.
- **New Project** (⇧⌘N) opens a template chooser like Xcode's: a gallery of Article,
  Report, Book, Presentation, Letter and Blank, each with a sketch of its first page,
  beside the project's name, title and author, the paper (A4 or US Letter, from your
  region) and font size — or widescreen or standard slides — the engine, and a
  `references.bib` already wired up. TexLab then asks where to save the folder, and
  remembers your choices for the next project. Every combination typesets as created.
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
├── App/            App entry point and menu commands
├── Document/       FileDocument, templates, per-window session, outline
├── Editor/         Source editor (AppKit text system), syntax, completion, snippets
├── Typesetting/    TeX discovery, typesetting pipeline, log parsing, SyncTeX
├── Preview/        PDF preview and navigation
├── Project/        Project folder scanning, main file detection, new files and references
├── Views/          Window layout, sidebar, toolbar, sheets, Settings
└── Support/        Settings keys and defaults, paths, text statistics
```

- **Document** — `TexLabDocument` is a `FileDocument` holding the text and its encoding.
  File types are imported UTIs in `Info.plist` (`org.tug.tex`, `.bib`, `.sty`, `.cls`),
  the identifiers other Mac TeX editors use, so TexLab cooperates rather than claiming
  ownership.
- **Session** — `DocumentSession` (`@Observable`) is the per-window model: editor and
  preview controllers, caret position, word count, outline, typesetting state and issues.
  Extensions add typesetting (`+Typesetting`) and SyncTeX navigation (`+Sync`). Menu
  commands reach the focused window's session through `FocusedValues.documentSession`.
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
  depth so it sits on the baseline; the session (`+Math`) caches images per formula and
  preamble and renders in the background.
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
- **Files of a window** — `EditorFile` holds each file a window shows: the window's own
  document, saved by the document system, and project files opened beside it, which the
  window saves itself (coordinated, replacing the file safely). One `SourceTextView`
  shows them in turn (`DocumentSession+Files`): switching stores the insertion point,
  scroll position and folds, puts the other file's text in, and the text view takes its
  undo manager from the file, so undo never reaches a file that isn't on screen.
  `EditorFileRegistry` keeps each file to one window. The session's `fileURL` and `text`
  describe the shown file, so the outline, live preview, live issues and Jump to
  Definition follow it; typesetting overlays the unsaved text of the window's other files
  for TeX.
- **Projects** — a project is the main file's folder, not a new file format, so projects
  stay plain folders other TeX tools understand. `ProjectIndex` builds a
  `ProjectSnapshot` off the main thread (file tree, main file, labels and citation keys of
  the other files); `DirectoryWatcher` (a dispatch source per folder) and app activation
  keep it current. Each file is still its own document, so saving, undo and versions
  work per file; the navigator opens files as native window tabs.
- **Toolbar and navigators** — `EditorToolbar` is SwiftUI `CustomizableToolbarContent`,
  split into groups of related tools so AppKit's customisation palette offers them all;
  tools insert through `DocumentSession+Insert`, which adds the packages and definitions
  they need. `ProjectSearch` and `ReferenceScanner` back the Find and References
  navigators and the Cite and Reference pickers. `DefinitionFinder` reads what is under
  the pointer for Jump to Definition, and the project snapshot also lists the commands
  the project's other files and packages define.
- **Welcome window** — a SwiftUI `Window` scene presented at launch
  (`defaultLaunchBehavior`); an `NSApplicationDelegate` stops the untitled document at
  launch and reopens the window from the Dock. `RecentProjects` keeps recent folders,
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
