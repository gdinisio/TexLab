# Changelog

All notable changes to TexLab are recorded here, grouped by version. Each version
corresponds to a commit labelled `vX.Y - "…"`.

## v1.16 — Build fix

- `DocumentSession+Navigators.swift` imports SwiftUI for `NavigationSplitViewVisibility`,
  and `SettingsView.swift` imports CoreGraphics, as `MemberImportVisibility` requires.

## v1.15 — A Welcome window for projects

- A Welcome window like Xcode's appears when TexLab opens: Create New Project, Open
  Existing Project (a folder, or a single document), New Document, and recent projects
  on the right (double-click to open; context menu to show in Finder or remove). A
  checkbox, also in Settings ▸ General, turns it off at launch.
- TexLab no longer opens an empty untitled document at launch. The Welcome window comes
  back from Window ▸ Welcome to TexLab (⇧⌘1) and when the Dock icon is clicked with no
  windows open, and closes when a document opens.
- File ▸ Open Project (⇧⌘O) opens a whole folder at its main file — main.tex, the only
  complete document, or the most recently changed one — and offers to create main.tex in
  a folder without a LaTeX document.
- Recent projects are remembered whenever a project or document opens.
- README brought up to date with v1.12–v1.15.

## v1.14 — Find and References navigators, copying paths

- The sidebar has five navigators, like Xcode's, on ⌘1–⌘5: Project, Outline, Find,
  References and Issues.
- Find (⇧⌘F, Edit ▸ Find in Project) searches every LaTeX file, bibliography and package
  in the project as you type, including unsaved changes to the open document, with Match
  Case and Whole Words options. Results are grouped by file with the match in bold;
  selecting one shows it in the editor or opens the file at that line.
- References lists every label (grouped as figures, tables, equations, sections, …) and
  bibliography entry (key, authors, year, title) of the project, with a filter.
  Double-click inserts `\ref`/`\eqref` or `\cite` at the insertion point, drag inserts it
  where you drop it, and the context menu offers `\cref`, `\pageref`, `\citep`, …, Show
  Definition and Copy.
- The project navigator can copy a file's path relative to the main file (what
  `\includegraphics` and `\input` expect), its full path, or the LaTeX command that uses it.

## v1.13 — A customisable toolbar

- The toolbar is fully customisable with View ▸ Customize Toolbar: drag tools in and out,
  reorder them, and choose icons with or without text.
- Default set, for most writing: Code | Visual, Typeset, Heading, Figure, Table, Math,
  Symbols, Cite, Reference, Preview and Share.
- More than 40 further tools in the palette, so the toolbar can fit each way of working:
  - Structure: Chapter, Section, Subsection, Subsubsection, Paragraph.
  - Content: Image, bulleted, numbered and description lists, Footnote, Link, Quote, Code.
  - Math: Inline, Display, Equation, Align, Matrix, Fraction, and a Theorem menu
    (theorem, lemma, corollary, proposition, definition, remark, example, proof).
  - References: Label and the full Insert menu.
  - Formatting: a Bold/Italic/Underline group, Bold, Italic, Emphasis, Monospace, Small
    Caps, Comment, Indentation.
  - Presentations: Slide, Columns, Block, Pause.
  - Typesetting and view: Stop, Auto Typeset, Engine, Issues, Log, Clean, Show in PDF,
    Zoom, Fit, Two Pages, Folding, Find, Go to Line, Word Count.
  - Document: Export, Print, New File, Show in Finder.
- Cite opens a searchable list of the project's bibliography entries (key, authors, year,
  title) and inserts `\cite`, `\citep`, `\autocite` or another command for one or more of
  them. Reference lists every label in the project, grouped by figures, tables,
  equations and sections, and inserts `\eqref` for equations and `\ref` otherwise.
- Tools add what they depend on: inserting a figure loads graphicx, a link hyperref,
  aligned equations amsmath, a code listing listings, `\cref` cleveref, and a theorem
  loads amsthm and defines the environment with `\newtheorem` — so documents keep
  typesetting.
- The Insert menu gains Theorem and Presentation submenus and a plain Image item.

## v1.12 — Code and Visual editors, and customisation

- Two editor modes per window, switched from the toolbar or with ⌃⌘1 / ⌃⌘2:
  - **Code**: the source in the code font, with colouring and folding; no rendered
    formulas or visual formatting.
  - **Visual**: close to the typeset document, like Overleaf's Visual Editor — text in a
    serif (or sans) typeface, large headings, rendered formulas and images, lists,
    references and formatting shown as they will look, markup in the code font where you
    edit it, the preamble collapsed, and an optional page-like line length.
- Visual mode also hides `\begin{document}`/`\end{document}` and shows `\tableofcontents`,
  lists of figures and tables, the bibliography, page breaks and `\appendix`.
- Settings: editor font family (any installed monospaced font), line spacing, five colour
  themes (Xcode, Classic, Soft, High Contrast, Monochrome) with a live sample, and a new
  Visual Editor pane (default mode, typeface, text size, line length, formulas, images,
  preamble). The status bar option moved to General.

## v1.11 — Fix: crash when opening a document with visual preview elements

- Fixed a crash (`EXC_BREAKPOINT`) when a document with headings or `\maketitle` opened, for
  example a new project's `main.tex`. Visual labels are sized to the text width, which is
  unbounded when lines don't wrap and zero before the first layout; converting it to an
  integer overflowed. The width is now kept finite (100–4000 points) and never converted.
- All 51 regular expressions in the app were compiled with ICU, the engine behind
  `NSRegularExpression`, to rule them out as a cause.

## v1.10 — Build fix

- The split view's minimum pane widths are computed properties: generic types (the
  coordinator is nested in `PaneSplitView<Leading, Trailing>`) can't have static stored
  properties.

## v1.9 — Projects

- Project navigator: a new first sidebar tab lists the document's folder (files,
  subfolders, the main file marked), follows changes on disk, opens files as tabs of the
  same window, and has a context menu to open, reference, rename, show in Finder, use as
  the main file and move to the Trash. Files can be dragged into the editor.
- New File in Project (⌥⌘N): sections or chapters (with `% !TEX root`), bibliographies,
  packages and documents, optionally referenced from the main file in its open window or
  on disk.
- New Project (⇧⌘N): a folder with `main.tex` from a template and an optional
  `references.bib`.
- Parts of a project without `\documentclass` are typeset through the file that includes
  them, also for rendered math; completion includes labels and citation keys from the
  whole project; inserted paths are relative to the main file.
- The sidebar tabs are now icons: Project, Outline and Issues.

## v1.8 — Fix: the insertion point jumping while typing

- Fixed the insertion point moving to the next row, or the one after, after every typed
  character. Syntax colouring recoloured the whole paragraph inside the same edit that
  inserted the character, so NSTextView treated the paragraph as replaced and put the
  insertion point at its end. Colouring now runs as its own attribute-only edit straight
  after the change (and restores the selection if anything moved it), and waits while an
  input method is composing text.
- Text changed outside the editor (Revert To, undo through the document) is applied as a
  minimal replacement, so the insertion point and scroll position are kept.
- Inline predictive text is turned off in the editor; it inserts suggestions as marked
  text, which conflicts with LaTeX completion.
- The outline only moves the editor when you pick a different item, never while it
  follows the insertion point.

## v1.7 — Visual preview, a native divider and reliable fold controls

- Visual preview, modelled on Overleaf's Visual Editor: headings as large titles, the
  title block for `\maketitle`, Abstract and theorem/proof headings, bullets and numbers
  for list items with the list markers hidden, chips for references, citations and
  labels, links for `\url` and `\href`, small grey footnotes, images in place of
  `\includegraphics`, and typographic dashes, quotes and escaped characters. Markup
  reappears at the insertion point, and clicking a drawn element edits it.
- The divider between the editor and the preview is now a native `NSSplitView` divider
  with a grab area 4 points either side, so the resize pointer appears reliably; its
  position is remembered.
- Fold chevrons appear whenever the pointer is over the gutter (the tracking area is
  now always active and covers the whole gutter), with the one under the pointer
  emphasised.

## v1.6 — Build fixes

- Handled hidden formatting markup in the editor's click handling (the switch over
  replacement kinds wasn't exhaustive).
- Removed an unused binding in the current line highlight.

## v1.5 — Formatting preview, more folding and an editor layout fix

- Fixed typed text wrapping onto a new line after every character. The editor no longer
  follows the transient zero widths SwiftUI passes through while laying out the window,
  keeps its text container exactly as wide as the text area whenever the scroll view
  lays out, and no longer asks for line geometry in the middle of layout.
- Display math is now centred when drawn instead of widening its glyph to the whole line,
  so it can never push the rest of the line onto the next one; editing the line of a
  formula shown alone on it drops the rendering until the source is scanned again.
- Formatting preview: `\emph`, `\textbf`, `\textit`, `\textsl`, `\texttt`, `\textsc`,
  `\textsf`, `\textrm`, `\textup`, `\textmd`, `\textnormal`, `\underline`, `\uline`
  and `\sout` hide their markup and show their argument styled; nested commands combine.
- View ▸ Live Preview (⌃⌘M) replaces Render Math and covers formulas and formatting;
  Settings ▸ Editor can turn either off.
- Folding now covers section bodies (the heading stays visible, each section folds up to
  the next heading of the same or a higher level), the preamble and blocks of three or
  more comment lines. New Fold Sections and Fold Preamble commands, and an option to
  collapse the preamble when opening a document.

## v1.4 — Live preview in the editor: rendered math and code folding

- Formulas are shown typeset in the source, with the document's own macros and packages,
  and switch back to their source while the insertion point is inside them. Inline math
  sits on the text baseline; display math alone on its lines is centred like in the PDF.
  Covers `$…$`, `$$…$$`, `\(…\)`, `\[…\]` and math environments (`equation`, `align`,
  `gather`, `multline` and their starred forms), without labels and tags.
- Rendering runs in the background in one TeX run per batch using the `preview` package,
  is cached per formula, and redone only when the preamble or engine changes. Formulas
  TeX can't typeset stay as source.
- Code folding: collapse any multi-line environment from a chevron in the gutter (shown
  on hover, like Xcode) or View ▸ Code Folding (⌥⌘←, ⌥⌘→, ⌃⌥⌘←, ⌃⌥⌘→). Collapsed
  figures and tables show their caption, line count and a thumbnail of the image.
- Folding and rendering only change the layout, never the text; editing into a collapsed
  environment expands it first, and line numbers skip hidden lines.
- New View ▸ Render Math (⌃⌘M) and a Live Preview section in Settings ▸ Editor, with an
  option to collapse figures and tables when opening a document.

## v1.3 — Fix: gutter painting over the editor text

- Fixed the editor text being invisible while line numbers showed. Since macOS 14, views
  don't clip their drawing by default and can be asked to redraw an area larger than
  themselves; the line number gutter filled that whole area with the background colour,
  covering the text beside it. The gutter now clips to its bounds and only fills inside
  itself, and the current line highlight is clamped the same way.

## v1.2 — Fix: editor text not visible

- Fixed the editor showing no text. The text view was created before SwiftUI gave its
  scroll view a size and relied on autoresizing to grow, which didn't happen, so the text
  was laid out in a zero-width container. A new `EditorScrollView` now sizes the text
  view to the visible area every time it lays out, and the text view always fills the
  visible height so clicking below the last line places the insertion point.

## v1.1 — Build fix: explicit framework imports

- Fixed the first Xcode build: with the `MemberImportVisibility` upcoming feature
  enabled, `CGRect`/`CGPoint` members in `SyncTeX.swift` weren't visible because the file
  didn't import CoreGraphics.
- Every file that uses geometry types now imports CoreGraphics, and every file imports
  Foundation explicitly, so members are never visible only through another framework.

## v1.0 — Review and polish

- Full review of every source file for correctness, concurrency isolation and Apple API
  usage, with a mechanical syntax check of all Swift files.
- Fixed: typesetting twice without changes (latexmk has nothing to do) was reported as
  "Typesetting Failed"; an up-to-date PDF now counts as success.
- Fixed: shifting or commenting a selection of whole lines also changed the line after it.
- Documents saved as UTF-16 are typeset from a UTF-8 copy, since not every TeX engine
  reads UTF-16.
- Untitled documents that reference files by relative path now get a clear hint to save
  the document, instead of only "file not found" errors.
- Text replaced outside the editor (Revert To, versions) is applied after the SwiftUI
  update that delivered it, avoiding state changes during a view update.
- Menu commands are split so no builder has more than ten children, and nested menu
  content is grouped.
- Value types used as SwiftUI selections are `nonisolated`; explicit optional patterns
  when switching on optional enums.
- README rewritten: features, shortcuts, setup, manual Xcode steps (App Sandbox, app
  icon, localization, tests), architecture and implementation notes.

## v0.6 — Menus, Settings, export and printing

- Full menu bar, acting on the focused window:
  - **File**: New from Template, Export PDF… (⇧⌘E, standard Save panel, the PDF exactly
    as TeX wrote it), Print… (⌘P, prints the typeset PDF as a sheet).
  - **Edit**: Find and Replace, spelling, substitutions and transformations from the
    text system, plus Go to Line… (⌘L, accepts `line` or `line:column`).
  - **View**: Show/Hide Sidebar, Preview (⌥⌘P) and Status Bar; Line Numbers and Wrap
    Lines; PDF Zoom In (⌘>), Zoom Out (⌘<), Actual Size (⌘0), Zoom to Fit (⌘9) and Two
    Pages; Customize Toolbar.
  - **Insert**: the same items as the toolbar menu.
  - **Format**: Bold (⌘B), Italic (⌘I), Underline (⌘U), Emphasis, Monospace, Small Caps
    and Sans Serif wrap the selection in the LaTeX command and unwrap it when applied
    again; Comment Selection (⌘/), Shift Right (⌘]) and Shift Left (⌘[); Text Size.
  - **Typeset**: Typeset (⌘R), Stop (⌘.), Typeset Automatically, Engine, Show in PDF
    (⇧⌘J), Next/Previous Issue (⌘' / ⇧⌘'), Show Log (⇧⌘L), Clean Build Files (⇧⌘K).
  - **Help**: LaTeX documentation, the LaTeX Wikibook, CTAN package search and MacTeX.
- Settings window (⌘,) with General, Editor and Typesetting tabs: automatic typesetting
  and its delay, two-page preview, issue filters, font size with a live sample, line
  numbers, current line, wrapping, status bar, indentation (spaces or tabs), bracket and
  environment closing, completion, spelling, TeX location (detected automatically, with
  the version shown, or chosen), default engine, latexmk, shell escape (off, with a
  clear warning), and build folder management.

## v0.5 — Main window: sidebar, toolbar and palettes

- The window now has a sidebar (NavigationSplitView) with two views, switched by a
  segmented control:
  - **Outline** — parts, chapters, sections, Beamer frames, and figures and tables by
    caption, nested as in the document. Selecting an item jumps to it in the editor and
    the preview; the selection follows the insertion point, so the outline always shows
    where you are. Commented-out headings are ignored.
  - **Issues** — errors, warnings and bad boxes with file and line; clicking one shows
    its source (opening other project files as needed). Filter buttons for warnings and
    bad boxes, and a button for the full log.
- Customizable toolbar (View ▸ Customize Toolbar): **Typeset** (click to typeset, hold
  to stop or choose the engine), **Insert**, **Symbols**, **Preview** and **Share**.
- Choosing an engine writes or removes a `% !TEX program` comment, so the choice is
  visible, undoable and understood by other TeX editors.
- **Insert** menu: headings, lists, figure, table, math (inline, display, equations,
  fractions, matrices…), references, environments, spacing and breaks. Inserted text is
  indented to fit, wraps the selection, and places the insertion point where you type
  next. Undo names the insertion ("Undo Insert Figure").
- **Image…** inserts a figure for a chosen image with a path relative to the document and
  the insertion point in the caption. **Table…** builds a table of any size, alignment,
  rules and header row.
- **Symbols** palette: searchable Greek letters, relations, operators, arrows and text
  symbols. Math symbols are wrapped in `$…$` when inserted outside math; the footer
  shows the command and any package it needs.
- **Share** sends the PDF named after the document.
- The status bar shows error and warning counts; clicking them opens Issues.

## v0.4 — Live PDF preview with SyncTeX

- The typeset PDF appears beside the editor in a native PDFKit preview that keeps its
  scroll position and zoom when a new version arrives, so live typesetting never makes
  it jump. The preview can be shown or hidden from the toolbar; the choice is remembered
  per window.
- Command-click in the PDF, or choose Show in Source from its context menu, to jump to
  the line that produced it — in another window if it came from another file.
- Show in PDF in the editor's context menu scrolls the preview to that line and
  highlights it with the same animation Preview uses for Find (figures get a brief
  outline instead).
- When there is no PDF, the preview explains why and offers the next step: Typeset,
  Show Log, Get MacTeX, Open Settings, or how to lift the App Sandbox restriction.
- New log window with the TeX log and the tools' console output, searchable with ⌘F.
- Printing and zoom helpers (`PreviewController`) ready for the menus.

## v0.3 — Typesetting

- Typeset with ⌘R (toolbar button for now; menus arrive in a later version). The window
  subtitle shows progress and the result ("Typeset · 3 pages", "Typeset with 2 errors").
- Typesetting runs off the main thread from a copy of the editor text in a private build
  folder (`~/Library/Caches/com.gdinisio.TexLab/Typeset`), so unsaved changes are
  included, untitled documents can be typeset, and auxiliary files never clutter the
  document's folder. TeX runs in the document's folder, so relative `\input`,
  `\includegraphics` and bibliography paths work.
- Uses latexmk (`-f`, reruns only when needed) when available, otherwise runs the engine,
  BibTeX or Biber, makeindex and repeated passes directly — so BasicTeX works too.
- Engines: pdfLaTeX, XeLaTeX and LuaLaTeX, chosen with a `% !TEX program = …` magic
  comment or the default engine setting.
- `% !TEX root = main.tex` typesets a multi-file project from any of its files, using the
  unsaved text of the file being edited (placed in an overlay folder TeX searches first).
- Finds MacTeX, BasicTeX, TeX Live, Homebrew and MacPorts installations even though
  Finder-launched apps don't inherit the shell `PATH`.
- Log parser extracts errors (with file, line and the undefined command's name),
  warnings (including multi-line package warnings) and bad boxes; noise such as rerun
  notices and summaries is dropped. Validated against real pdfTeX, XeTeX and LuaTeX logs.
- Issue markers appear in the editor gutter after typesetting.
- Uncompressed SyncTeX output is parsed by a byte-level parser with a sorted line index,
  ready for source ↔ PDF navigation (validated against the `synctex` tool).
- Automatic typesetting after a pause in typing (on by default), with runs queued rather
  than overlapping, cancellation, and a five-minute safety limit per tool.

## v0.2 — Native source editor

- New source editor built on the Mac text system (TextKit 1 `NSTextView`), so Find and
  Replace, spelling, dictation, services, Look Up and undo all work as in other Mac apps.
- LaTeX syntax colouring for commands, environments, math, comments, keys and verbatim
  text, using Xcode's default light and dark palettes. Section titles appear in bold.
  Colouring is incremental — only the edited paragraph block is re-scanned.
- Spelling is checked in prose and comments only; commands, math, labels and keys are
  never marked as misspelled.
- Line number gutter with the current line emphasised, issue markers, and click-to-select.
- Subtle current line highlight.
- Smart editing: automatic indentation, `\begin{…}` + Return closes the environment
  (adding `\item` for lists), Return continues `\item` lists and leaves them on an empty
  item, bracket and `$` pairing with step-over, wrap-selection when typing an opening
  bracket, soft tabs with indent-aware delete, Tab/Shift-Tab to indent selected lines.
- Completion (Esc, or automatically after `{`) for commands, environments, labels,
  citation keys from `.bib` files and `\bibitem`s, macros defined in the document,
  packages, document classes, and files next to the document.
- Drag image, `.tex` or `.bib` files onto the editor to insert `\includegraphics`,
  `\input` or `\bibliography` with a relative path.
- Status bar showing line, column, selection length and a word count of the document
  body (commands, math and the preamble are excluded).
- Command-= also makes the editor text bigger.

## v0.1 — Document model, LaTeX file types and templates

- `TexLabDocument` now opens and saves LaTeX (`.tex`, `.ltx`, `.latex`), BibTeX (`.bib`),
  package (`.sty`), class (`.cls`) and plain text files.
- Text encoding is detected on open (UTF-8, UTF-16 with BOM, Windows-1252, Latin-1,
  Mac OS Roman) and preserved on save; text that no longer fits the original encoding is
  saved as UTF-8 instead of losing characters.
- Declared the TeX file types in `Info.plist` as imported types (`org.tug.*`) with proper
  names, so Finder and the Open panel describe them correctly. Removed the template's
  placeholder `com.example.plain-text` type.
- Added File ▸ New from Template with Article, Report, Book, Presentation, Letter and
  Blank templates. New documents start from the Article template instead of
  "Hello, world!".
- Added `SettingsKey`/`AppSettings` for settings keys and defaults, and
  `TypesettingEngine` (pdfLaTeX, XeLaTeX, LuaLaTeX).
- Organised sources into feature folders and added a `.gitignore`; Finder metadata and
  Xcode per-user state are no longer tracked.

## v0.0 — Xcode template

- Xcode macOS document app template.
