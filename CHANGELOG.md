# Changelog

All notable changes to TexLab are recorded here, grouped by version. Each version
corresponds to a commit labelled `vX.Y - "…"`.

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
