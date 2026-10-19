# Changelog

All notable changes to TexLab are recorded here, grouped by version. Each version
corresponds to a commit labelled `vX.Y - "…"`.

## v1.40 — Why the bibliography is empty

A document using biblatex could typeset with every citation undefined and an empty
bibliography, and TexLab said nothing: TeX's log only asks for Biber to be run.
Biber's and BibTeX's own logs (`.blg`) say what went wrong, and TexLab now reads them.

- **Biber's and BibTeX's errors and warnings are issues.** A syntax error or runaway
  string in a `.bib` file shows at its line in that file (Biber names a temporary copy;
  TexLab puts it down to the data source Biber was reading), as do BibTeX's "I was
  expecting a `,' or a `}'" and repeated entries. "Too many commas in name" and other
  errors found while the style runs, missing database or style files, and BibTeX's
  empty-field warnings are listed too. Unfound citation keys aren't repeated, as LaTeX
  already marks each one where it's cited.
- **A missing `.bib` explained.** Biber's "Cannot find 'references'!" becomes "Biber
  can't find “references”. \addbibresource needs the file's extension, as in
  \addbibresource{references.bib}"; with the extension, it says the path is taken from
  the main file's folder.
- **A missing Biber explained.** When TeX still asks for Biber at the end and the TeX
  distribution has no Biber, the issue says so and gives the command to install it
  (`sudo tlmgr install biber`, or TeX Live Utility). TexLab used to skip Biber
  without a word when it wasn't there. If Biber is installed but TeX still asks for
  it, a warning points to the log.
- **Typeset with Errors.** A bibliography that couldn't be made now counts as an error,
  so the status says so instead of a green tick over an empty bibliography.

Checked against real logs from Biber 2.19 and BibTeX 0.99d: a missing `.bib`, a
missing extension, syntax errors and runaway strings, a missing database, nothing
cited, and too many commas in a name.

## v1.39 — biblatex loaded over several lines

- **No more "\addbibresource needs biblatex" when it's loaded.** The package check read
  the preamble line by line, so a `\usepackage` whose options run over several lines —
  the usual way to load biblatex, with `backend`, `style` and `sorting` on lines of their
  own — went unseen, and so did a list of packages split over lines or a package name on
  the line after its options. The preamble is now read whole, without its comments, as
  TeX reads it; each of these was checked with pdfLaTeX to load biblatex. Add Package,
  its Loaded marks and the package offers all read packages this one way.
- **biblatex-chicago** counts as loading biblatex, as it does in TeX Live.

## v1.38 — A toolbar laid out like Xcode's

The window's toolbar is laid out the way Xcode's is: what's done to the whole document
leads, the project's name follows, and the tools and how typesetting went sit at the
trailing edge.

- **Typeset and Code | Visual lead.** They sit at the leading edge of the window's
  content, just after the sidebar, before the title — Typeset where Xcode has Run (Stop
  while TeX runs; hold it for the engine, automatic typesetting, the log and a clean
  start), then the editor's mode.
- **The project's name as the title.** The title is the project's, as the Welcome window
  lists it: the folder's name for a project of several files, the document's for one on
  its own. The bar above the editor, with its back and forward arrows, names the file
  shown. The proxy icon, edited dot and File menu still act on that file. The subtitle,
  which repeated the folder and the typesetting outcome, is gone.
- **A status item.** At the start of the trailing tools, like Xcode's activity view:
  "Ready", "Typesetting…" with a spinner, "Typeset · 12 pages" with a green tick,
  "Typeset with Errors", or what went wrong, with the time and engine in its help.
  Beside it, the number of errors and warnings. Click the status for the log, or the
  counts for the Issues navigator.
- **Theorem in the default set**, beside Math, which defines the theorem in the preamble
  if needed. A List menu (bulleted, numbered, description) joins the palette.
- **The default trailing set**, in three groups of Liquid Glass: the status; Heading,
  Figure, Table, Math, Theorem, Symbols and Add Package; and Preview and Share, last.
- **No spaces over the sidebar.** The toolbar belongs to the editor and preview rather
  than the whole split view, so the spaces between groups stay with their groups instead
  of collecting over the sidebar. The toolbar has a new identifier so this layout applies
  once; customise it again from View ▸ Customize Toolbar.

## v1.37 — A cleaner bibliography editor

The Visual bibliography editor keeps its structure — entries that open to show their
fields, BibTeX behind them — with a cleaner look that matches the rest of TexLab, in
place of a striped table.

- **Cards in a page-wide column.** Each entry is a card with rounded corners in a column
  as wide as the Visual editor's page, rather than a row of a full-width table with
  alternating stripes and column headers. Its header shows the kind as an icon in that
  kind's colour (blue for articles, orange for books, purple for conference papers, teal
  for websites, indigo for theses), the citation key, a one-line summary, how many
  required fields are still to fill in, and the kind as a quiet menu.
- **Labels and values.** An open card lists its fields as a column of labels beside
  their values, with no grid lines. Values read as text: hovering shows a soft field,
  clicking edits it with a ring around it, Return or clicking away writes it, and Esc
  puts it back. Titles, authors, abstracts, notes and other long values wrap onto more
  lines instead of running off the end of a cell.
- **Editing where you look.** A required field still to fill in has an orange dot and
  says Required; hovering any other field shows a − to remove it, as in Xcode's Info
  editor; Add Field sits at the foot of the card; and the card's ⋯ menu (or its context
  menu) copies the citation or key, duplicates the entry, shows it in Code or deletes it.
  A new entry is opened and brought into view.
- **Glass controls.** Add Entry, the filter, Open All / Close All and BibTeX Names float
  on Liquid Glass above the cards, like the sidebar's controls, with the cards scrolling
  beneath.

## v1.36 — Packages when they're needed, and a toolbar that makes sense

- **Offers the package a command needs.** Type `\mathbb{R}` without amssymb, or
  `\begin{align}` without amsmath, and a small bar of Liquid Glass appears just above the
  line: "\mathbb needs the amssymb package. Add amssymb · Not Now". Typing carries on
  underneath and nothing is added without a click; Add puts `\usepackage{amssymb}` after
  the preamble's other packages (in the main file for a part of a project) as an
  undoable edit, and Not Now stops asking about that package while the window is open.
  The bar goes once the insertion point leaves the line. (`\mathrm`, like other commands
  LaTeX has itself, never asks.)
  - Each such use is also a live issue in the Issues navigator, with an Add button like
    an Xcode Fix-It, and the editor's context menu offers Add \usepackage{…} on the
    command.
  - Nearly 300 commands and environments of about 70 packages are known: amssymb's and
    amsfonts' letters and symbols, amsmath's and mathtools', amsthm, mathrsfs, bm,
    graphicx, xcolor, hyperref and url, cleveref, booktabs, multirow, TikZ, pgfplots,
    tikz-cd, siunitx, listings, minted, enumitem, geometry, fancyhdr, caption and
    subcaption, csquotes, biblatex and natbib, todonotes, cancel, mhchem, physics,
    setspace, glossaries and more. Each was checked with TeX Live to be undefined in a
    plain article and defined by the package offered; three the kernel has already
    (`\mho`, `\selectlanguage`, `\foreignlanguage`) were left out.
  - What the document loads already counts: packages its class loads (Beamer loads
    amsmath, amssymb, amsthm, graphicx, hyperref and xcolor; amsart amsmath; memoir
    booktabs), packages other packages load (mathtools loads amsmath, tikz graphicx and
    xcolor, hyperref url), packages and classes of the project's own, files the preamble
    inputs, and commands and environments the project defines. With a class it doesn't
    know, or a preamble file it can't read, the check stays quiet. Comments and verbatim
    text don't count; math does.
  - Settings ▸ Editor ▸ "Offer to add the package a command needs" turns it off.
- **Add Package.** A toolbar item, and Insert ▸ Package…, list common packages with what
  each is for, mark those the document already loads (itself, through its class or
  through another package), and add any other by name, with options such as
  `margin=2cm`. More packages have descriptions in completion too.
- **A new default toolbar**, laid out left to right as the window is:
  - over the editor, Code | Visual, then Heading, Figure, Table, Math and Symbols;
  - Add Package;
  - over the preview, Typeset and Preview, the two things done to the PDF most;
  - Share.

  Typeset is now Stop while TeX runs, like Xcode's Run, and holding it offers the engine,
  Typeset Automatically, the log and Clean Build Files. Cite and Reference left the
  default set — `\cite{` and `\ref{` are quick to type with completion — and stay in the
  palette. Nothing is placed over the sidebar any more: Code | Visual and Typeset were
  in leading places that macOS puts over the sidebar, so hiding the sidebar could hide
  them, and a tool dragged there (Theorem, say) went with it. The palette gains an Issues
  count that opens the Issues navigator.
- **Grouping.** The default set comes in four groups separated by spaces, so each has its
  own Liquid Glass capsule. Items side by side share a capsule: drag Space from the
  palette between two items to separate them, or drag items next to each other to group
  them. The toolbar starts from the new default set once; customise it again with View ▸
  Customize Toolbar.

## v1.35 — Bibliographies like Xcode's Info editor

- **A Visual editor for bibliographies.** A `.bib` file in the Visual editor is shown as a
  table, like Xcode's Info editor shows a property list: BibTeX behind it, but laid out
  to read and edit. Code | Visual (⌃⌘1, ⌃⌘2) now works for bibliographies; Code shows the
  BibTeX as it is.
  - Each entry is a row with its citation key, its kind — Journal Article, Book,
    Conference Paper, Chapter in an Edited Book, Part of a Book, Website, PhD Thesis,
    Master's Thesis, Technical Report, Manual, Conference Proceedings, Booklet,
    Unpublished Work, Software, Dataset or Other — chosen from a menu, and a summary
    such as "Knuth · 1984 · The TeXbook". A short bibliography opens with every entry's
    fields in view.
  - Open an entry to see its fields by name — Authors, Title, Journal, Year, Publisher,
    Place, Organization, URL, DOI… — with what kind of value each holds, and edit them in
    place: Return or leaving the field writes the change, Esc puts back what was there.
    The fields the entry's kind needs come first and are always listed, ready to fill in
    ("Required"); an entry missing any is marked. Clearing a field removes it.
  - Add Field offers the fields the entry's kind usually has, then the others in common
    use, or any field by its BibTeX name. Add Entry adds any kind of entry, with a key of
    its own; the context menu copies the citation or key, duplicates the entry, shows it
    in the Code editor, or removes fields and entries, as the Delete key does.
  - A filter finds entries by key, author, title, year or any field. Accents, dashes and
    the TeX logos read as they print (M{\"u}ller as Müller, 12--34 as 12–34), fields say
    how to write them where it isn't obvious (names separated with "and", a DOI without
    https://doi.org/), and a URL or DOI opens in the browser.
  - The BibTeX names button shows `booktitle` and `inproceedings` instead of the
    readable names, as Xcode's Show Raw Keys does.
- **BibTeX stays as it is.** Each change is one undoable edit to the text that touches
  only what changed: comments between entries, the layout, `@string` abbreviations and
  `@preamble` stay put, braces or quotes around a value are kept, a number or an
  abbreviation stays bare, and a new field lines its `=` up with the others when they're
  lined up. A value with unmatched braces, or a key with spaces or one another entry
  has, is shown in red and not written until it's fixed. An entry that doesn't end
  properly is marked and left to the Code editor. Edits were checked with BibTeX and
  biber, including entries in parentheses, quoted values, `#` concatenation and
  abbreviations.

## v1.34 — Preview while editing, and whole floats typeset

- **Preview while editing.** While the insertion point is in a formula, a TikZ drawing,
  a table, a figure or table float, an `\includegraphics` or an `\input` of a figure, its
  typeset version floats just below the source in a small panel of Liquid Glass, so the
  source and what it makes are both in view as you edit. It works in the Code editor
  too, where formulas are otherwise never shown typeset.
  - It follows your changes. Until TeX has typeset the new version, the last one stays,
    dimmed, with a spinner; when the source can't be typeset as it is — an unfinished
    `\frac{`, a missing brace — a warning shows instead, and the last good version
    stays until it can.
  - It sits below the source, or above it when there's no room below or the completion
    list is open; for a table taller than the window it keeps to the edge away from the
    insertion point. It scrolls with the text, never takes clicks or the keyboard, and
    hides when the editor isn't in use or another file is shown.
  - One- and two-letter formulas such as `$n$` get none. Settings ▸ Editor ▸ "Preview
    formulas, drawings, tables and images while editing them" turns it off.
- **Whole figure and table floats typeset in the Visual editor.** A `table` or `figure`
  float (and `table*`, `figure*`) now shows as one piece of paper — its table, drawing
  or picture centred, with the caption typeset beneath it in the document's own style —
  instead of the table alone between `\begin{table}[H]`, `\centering`, `\caption{…}`
  and `\end{table}`. The caption reads "Table: …" without a number, since the number
  depends on the rest of the document. If the float can't be typeset, the table or
  drawing in it is shown as before. An `\input` of a figure file shows the whole float
  too, caption and all. Floats were typeset this way with pdfLaTeX, XeLaTeX and
  LuaLaTeX, with and without the caption package.

## v1.33 — Previews in the Visual editor, and a glass sidebar

- **TikZ drawings and tables typeset in the Visual editor.** `tikzpicture`, `circuitikz`
  and `forest` drawings, and `tabular`, `tabular*`, `tabularx` and `tabulary` tables,
  show as they will print, typeset with the document's own preamble (its packages,
  macros and TikZ libraries) and drawn on a small piece of white paper so their colours
  stay true in Dark Mode. Click one, or move the insertion point into it, to edit its
  source; the outermost drawing or table is the one shown, so a table in a TikZ node is
  part of its drawing. They're typeset in the background in a run of their own, a few
  dozen at a time, so a slow drawing never holds up the formulas, and a drawing TeX
  can't typeset stays as source while the others show. Drawings and tables were typeset
  this way with pdfLaTeX, XeLaTeX and LuaLaTeX, each cropped to its own page, with a
  broken one reported and skipped.
- **Included files as chips and previews.** `\input`, `\include` and `\subfile` show as
  chips like references', named by the part's first heading — "Introduction" rather
  than `Sections/introduction` — and marked when the file isn't there. A file holding a
  figure shows its picture with the caption beneath; one holding a TikZ drawing or a
  table shows it typeset. Files open in the window are read with their unsaved changes;
  others are read again only when they change. ⌘-click opens the file, as before.
- Settings ▸ Visual Editor's "Show formulas typeset" now reads "Show formulas, TikZ
  drawings and tables typeset", and turns all three on or off.
- **Liquid Glass sidebar.** The row of navigator icons floats on a capsule of glass,
  with the chosen navigator highlighted and the highlight sliding to the next one. The
  Find field, the References picker and filter, the Project navigator's add button and
  filter, the Outline's This File | Whole Document control and the Issues buttons float
  on glass too, with the lists scrolling beneath them, instead of sitting in opaque bars.
- **Outline:** the whole document's outline no longer shows each heading's file name on
  the right; clicking a heading still goes to it in its file, and the tooltip still
  names the file.
- **Fixes the Find and Issues navigators sitting in the middle of the sidebar.** With no
  results or no issues, the "Find in Project" or "No Issues" message didn't fill the
  sidebar, so the search field (or the Issues buttons) and the message floated in the
  middle together. Every navigator now fills the sidebar, with its field at the top,
  its buttons at the bottom and its message in between.

## v1.32 — New files ready to use

New File in Project offers many more kinds of file, each set up to use straight away.
Figure, table and drawing files, and figures for images with names containing spaces and
dots, were typeset in the Article template with pdfLaTeX, XeLaTeX and LuaLaTeX without a
warning.

- **A new sheet, like Xcode's New File** — the kinds of file are listed on the left, in
  groups, and what each needs is on the right: a description, the name, the folder, the
  path the file will have, and whether to use it from the main file or where you're
  writing. It starts with the kind chosen last time.
- **Empty File** — with nothing in it; without an extension it's a LaTeX file, input
  from the main file if you like, and with one, such as `.txt`, it's any text file.
- **Figure** — choose a picture (with a thumbnail in the sheet), and the figure file has
  it in a `figure` environment, centred and sized to the line, with a caption and a
  `fig:` label, named after the picture. The picture is copied into the project if it's
  elsewhere. Without one, a frame stands in for it.
- **Table** — a booktabs table of the rows and columns you choose, the caption above it
  and a `tab:` label.
- **TikZ Drawing** — a figure with a TikZ picture to start from.
- **Images** — add several pictures or PDFs at once: they're copied into Figures and,
  if you like, each gets a figure where you're writing, with the insertion point in the
  first caption and Tab moving to the next. Add Images… is in the navigator's + and
  context menus.
- **Document from Template** — a complete document from any of the templates, in the
  project.
- Figures, tables and drawings go in where you're writing as `\input{…}` on a line of
  their own, and the package each needs — graphicx, booktabs or tikz — is added to the
  preamble. If the insertion point is in the preamble, as it is in a main file just
  opened, they go after the body's last part instead of breaking the document.
- Figures, tables and drawings are suggested for the Figures folder (tables for Tables if
  there is one), parts for Sections or Chapters, as before.
- The sheet explains why a name won't do — it can't contain characters TeX reads as
  commands, such as `%` or `#`, in a LaTeX file's name — instead of just disabling Create.
- Insert ▸ Figure from Image and Insert ▸ Image copy a picture from outside the project
  into its Figures folder first, so the project keeps working when it's moved or shared.

## v1.31 — Project templates

New Project now makes whole projects — folders of parts, figures and a bibliography —
and has more templates. Every template but Blank, which starts empty, typesets as
created with pdfLaTeX, XeLaTeX and LuaLaTeX, with or without its bibliography, on A4 and
US Letter, without a warning; the Article, Lecture Notes and Presentation were also
typeset in each language offered.

- **Article** follows the layout of a real paper: `main.tex`, `references.bib`, a
  `Figures` folder and a `Sections` folder with `abstract.tex` (its own `abstract`
  environment) and `introduction.tex`. `main.tex` has a title page with the title,
  author, affiliation, date, the abstract and a copyright notice, defined once as
  `\papertitle`, `\paperauthor`, `\paperaffil` and `\paperdate`; then the introduction
  and each section, one file apiece; then the references on a page of their own, with
  biblatex and biber. `\graphicspath` finds pictures in `Figures` by name.
- **Report** — title page, abstract and contents, and chapters in `Chapters`.
- **Thesis** (new, in place of Book) — title page with the degree and university;
  abstract, acknowledgements, contents and lists of figures and tables in `FrontMatter`;
  chapters in `Chapters`, appendices in `Appendices`, then the references.
- **Lecture Notes** (new) — theorems, definitions, examples and exercises numbered by
  section, `\cref` references, the course and section at the top of each page, and a file
  per lecture in `Lectures`.
- **Assignment** (new) — numbered problems with optional titles, solutions, and the course
  and your name at the top of every page.
- **Presentation** — Beamer slides without navigation symbols, numbered, with a file per
  part of the talk in `Slides` and the references on a slide of their own.
- **Letter** and **Blank** take the language and paper too.
- The New Project window adds an affiliation (University, Institution, Course or
  Institute, as the template calls it) and the language — English (UK or US), Italian,
  French, German or Spanish — which sets hyphenation, quotation marks, the names TeX
  prints and the date. The gallery scrolls, and each new template has a sketch of its
  first page.
- **New File in Project** fits the templates: a new section or chapter goes in the
  Sections, Chapters, Lectures or Slides folder unless you pick another, starts with the
  heading its document uses (a chapter in a report or thesis, a section in an article, a
  section and a first slide in a presentation, each with a label), and its `\input` goes
  after the last part — before the references, the appendices and the page break in
  front of them, and never inside the title page. Before, it went just before
  `\end{document}`, after the bibliography.
- File ▸ New from Template makes the same templates as one document.
- An empty document, such as a new Blank one, says there's nothing to typeset yet instead
  of reporting a failure.

## v1.30 — Opening project files without crashing

- Fixes a crash when a second project window opened — for example after clicking a
  figure included from a chapter. AppKit links toolbars with the same identifier and
  copies every item one inserts into the others; SwiftUI inserts a window's items one by
  one, so the second window's toolbar put each item into the first window's again and
  AppKit stopped at the duplicate. Each open project window now has its own toolbar
  identifier, and a new window starts from the first window's customization.
- Fixes clicking a file in the project navigator opening it in a new window instead of
  showing it in the editor. A folder's canonical path ended with a slash, so no file was
  ever found to be inside a folder: the window didn't count the project's own files as
  its own. The same mistake kept chapters from being typeset with the unsaved text of
  the other open files, could switch the project to a chapter's folder, and stopped
  Move to Trash from closing the open files inside a trashed folder; all of these work
  now.

## v1.29 — Builds with main-actor isolation

- Fixes the build: `TeXDocument` overrides of `autosavesInPlace`, `fileURL` and
  `read(from:ofType:)`, and the navigator rows' `isEqual` and `hash`, are `nonisolated`
  like the AppKit declarations they override, instead of taking on the target's default
  main-actor isolation. A file moved from another app's queue is followed on the main
  thread.

## v1.28 — Native project windows

Selecting files in the project navigator didn't work, and the way windows held files was
TexLab's own. Both are now built the way Apple intends a project app like Xcode to be:
on AppKit's document architecture, with SwiftUI views inside.

- **Every file is a Mac document.** Chapters, bibliographies and packages are documents
  just like the main file (`NSDocument`), instead of files the window saved itself. Each
  saves automatically and keeps versions (File ▸ Revert To ▸ Browse All Versions), has
  its own undo history — undoing back to the saved text clears the edited dot again —
  follows its file when it's renamed or moved, and is read again when another app changes
  it. A file is only ever open once, so it can't be edited in two windows.
- **Project windows, like Xcode's.** A project's files share one window, which shows one
  at a time and is that file's window: the title, proxy icon and edited dot are the shown
  file's, and File ▸ Save, Duplicate, Rename, Move To and Revert To act on it. Opening a
  chapter, bibliography or package from the Finder, File ▸ Open or Open Recent while its
  project is open shows it in the project's window rather than a window of its own; a
  complete document of its own opens in a new window. The subtitle names the project and
  how typesetting went.
- **A native File menu**: New Document, New from Template, New Project, New File in
  Project, Open…, Open Project…, Open Recent, Open Recent Project, Close (⌘W), Close File
  (⌃⌘W), Save, Duplicate, Rename…, Move To… and Revert To.
- **Closing**: closing a window closes the project's files with it — each saves itself,
  and an untitled document asks as usual — and closing one file shows the one you were
  on before. TexLab stays open with no windows; the Dock icon brings the Welcome window
  back. A reopened window has its other files open again.
- **The project navigator is a native sidebar outline** (`NSOutlineView`), as in Xcode
  and the Finder. Clicking a file shows it in the editor — this didn't work before,
  because SwiftUI's list stops selecting rows that can be dragged — and the arrow keys
  and type-to-select step through files with the keyboard still in the list. The
  selection follows the file on screen, opening folders to reveal it. Double-click or ⌘↓
  goes to the file (images and PDFs open in their app), Return renames in place with the
  name selected up to its extension, ⌘⌫ moves to the Trash, and New Folder names the new
  folder in place. Drag files onto a folder to move them, from the Finder to copy them
  in, or into the editor to reference them. The context menu acts on the clicked row, or
  the whole selection if the row is in it. The Document section shows each included file
  inside the file that includes it, and open folders stay open per project.
- Renames and moves in the navigator are coordinated with open documents, so an open
  chapter follows its file instead of being saved back under the old name.

Technical: `TeXDocument`, `TeXDocumentController`, `ProjectWindowController`,
`ProjectWindowView` (was `ContentView`), `ProjectNavigatorOutline` and `FileOperations`
are new; `TexLabDocument` (a SwiftUI `FileDocument`) and `EditorFile` are gone, and the app
no longer uses `DocumentGroup`. `Info.plist` names `TeXDocument` as the class of every
document type.

## v1.27 — Fixes and polish

A pass over the whole app for bugs and rough edges.

**Completion**
- With Close brackets automatically on (the default), typing letters, digits or commas
  didn't open the completion list — only `{` did. `\sec`, `\ref{fig` and `\cite{knuth,`
  now open it as intended.
- As you type, the list selects the best match for what's typed so far, instead of
  holding on to an earlier item that no longer is; scrolling the editor keeps the item
  chosen with the arrow keys.
- Return after a command typed in full that takes no argument, such as `\item` or
  `\centering`, starts a new line instead of only closing the list.
- Clicking in the text closes the list.
- File suggestions no longer repeat their folder beside the path, and the details bar at
  the bottom of the list only appears for citations and labels, which have more to say.

**Editor**
- A figure that was missing when the editor first drew it now appears once the image is
  added to the project, and a figure changed in another app — a plot regenerated by a
  script — is redrawn when you come back to TexLab.

**Projects**
- Find in Project names the file on screen like any other, so its results still lead to
  it after switching files, and selects the match itself again.
- Choosing the engine while a chapter is on screen writes `% !TEX program` into the main
  file, which decides how the whole document is typeset, rather than into the chapter,
  where it had no effect.
- Choosing an outline entry in a file that opens in a window of its own no longer moves
  the preview to the wrong place.

**Windows and navigators**
- Issues: "Not Typeset Yet" only shows when nothing has been found at all, and Show Log is
  dimmed until there is a log.
- References: the label filter matches captions and headings too, and a filter that
  matches nothing says so.
- Preview: when TeX fails, Show Issues sits beside Show Log; a time-out now says what
  happened and offers Typeset Again.
- The log opens scrolled to the end, where TeX's summary and last error are.
- New Project: a click selects a template at once; it used to wait to rule out a
  double-click.
- New File: the Folder pop-up always shows the chosen folder; it could be blank.
- Go to Line names the file and counts its lines correctly ("1 line").

## v1.26 — Completion as you type

- A new completion list, like Xcode's, replaces the standard Mac completion window. It
  appears under the insertion point as you type, without taking the keyboard from the
  text, and refines with every key:
  - **Commands** after `\` and a letter, with what common commands do or the braces they
    take, and the commands the document and project define, with their argument counts.
    `\begin` and `\end` are now offered too.
  - **Labels** in `\ref`, `\eqref`, `\cref` (after each comma), `\autoref` and the others:
    every label in the project, each with what it names — the caption of its figure or
    table, the heading of its section, or Equation, Theorem, Item… — and the file it's
    in; those of the file on screen come first.
  - **Citations** in `\cite`, `\citep`, `\parencite`, `\autocite` and the others, after
    each comma: the entries of the project's bibliographies (and of databases it names
    outside the folder) and `\bibitem`s, matched by key, author, title or year, with
    "Author Year · Title" beside each and in full at the bottom of the list.
  - **Files** in `\input`, `\include`, `\subfile`, `\includegraphics`, `\includepdf`,
    `\bibliography`, `\addbibresource` and `\lstinputlisting`: the project's files of the
    right kind, as paths from the main file's folder, with or without the extension as
    the command expects.
  - **Environments** in `\begin{` (the project's own included) and `\end{`, where the
    environment to close comes first; **packages** in `\usepackage{`, with what common
    ones are for, and the project's `.sty` files; **classes** in `\documentclass{`.
- Ranking: exact-case prefixes, then other prefixes, then the start of a word inside a
  key (`res` finds `fig:results`), then any part of it, then its letters in order; for
  citations and labels, words of the authors, title or caption as well.
- ↑ and ↓ choose (Page Up and Page Down jump), Return or Tab accept, Esc dismisses, and
  Esc (or F5) opens the list anywhere there's something to complete. A click accepts too.
- Accepting a command adds its braces, with Tab moving between several; when its argument
  completes too — `\ref`, `\cite`, `\begin`, `\input` — the list opens for it at once.
  Accepting an environment adds the closing brace and, with Close environments on,
  `\end{…}` and an indented line. Accepting a label or file moves past the closing brace;
  a citation leaves the insertion point inside for another key.
- Settings ▸ Editor's completion option now reads "Suggest completions as you type"; with
  it off, Esc still shows the list.

## v1.25 — A better sidebar

- The navigators are chosen from a row of icons like Xcode's navigator bar, instead of a
  segmented control: the chosen one is tinted and filled, each has a tooltip with its
  shortcut (⌘1–⌘5), and the Issues icon carries a badge with the number of issues, red
  when there are errors.
- **Project navigator**
  - A Document section lists the main file (with the document's title) and the files it
    includes with `\input`, `\include`, `\subfile`, `\import` and `\subimport`, in reading
    order and nested as they are included, each with its first heading — the chapters of
    a thesis at a glance — followed by its bibliographies. Click one to write in it.
  - The project's folder follows under Files.
  - A filter field at the bottom lists the files whose name or path contains what you
    type, with their folders.
  - The file on screen is selected in the Document section when it's a part of the
    document, and its icon is tinted.
- **Outline navigator**: This File or Whole Document. The whole document's outline runs
  through every included file in reading order, with each chapter's headings where it
  is read; items in other files name their file, and selecting one opens that file at
  the heading. The selection follows the insertion point in both.
- **Issues navigator**: TeX's issues are grouped by file, in the order TeX reported
  them, and rows show just the line; live issues name the file they were found in.

## v1.24 — One window for the whole project

- Selecting a file in the project navigator now shows it in the window's editor, like
  Xcode, so the chapters of a document can be switched between without a window or tab
  for each. The arrow keys step through the files; double-click or Return goes to the
  text. Images and PDFs still open in their own app on double-click.
- Search results, issues, ⌘-clicks in the PDF (inverse search), the References navigator
  and Jump to Definition show other files of the project the same way.
- Each file keeps its own undo history, insertion point, scroll position, folds and
  Visual editor state, so switching back picks up where you were. Undo only ever changes
  the file on screen.
- A bar above the editor shows the file and its path in the project, goes back and
  forward through the files shown (⌃⌘← and ⌃⌘→, also in the View menu), lists the files
  open in the window with Close, Show in Project Navigator and Show in Finder, and has a
  button back to the main file (⌃⌘↑). The window subtitle names the file on screen.
- Files other than the window's own document are saved two seconds after the last
  change, when you switch to another file or app, when the window closes and when TexLab
  quits. Saving replaces the file safely and keeps its encoding and Finder metadata.
  Changes other apps make (a `git pull`, another editor) are picked up when TexLab
  becomes active, unless the file has changes of its own.
- Typesetting from any file of the project typesets the whole document, including the
  unsaved text of every file open in the window, and the PDF and SyncTeX stay linked to
  the right files. A file without `\documentclass` is always typeset through the main
  file, even straight after switching to it.
- The outline, live preview, live issues, folding and Jump to Definition follow the file
  on screen, and the project stays the same while you move around it.
- Inserting a figure, link, aligned equations or a theorem in a chapter adds the packages
  and `\newtheorem` it needs to the main file — in the editor, in another window, or on
  disk — instead of doing nothing.
- A file is edited in one window only: opening a file another window shows brings that
  window forward, and a window opened on a file saves and gives up its copy elsewhere.
  Open in New Window in the navigator's context menu still gives a file a window of its
  own.
- Exported and printed PDFs are named after the document, not the chapter on screen.

## v1.23 — A better Welcome window and New Project

- **New Project** (⇧⌘N, or Create New Project in the Welcome window) is now a template
  chooser like Xcode's:
  - a gallery of the six templates, each with a sketch of its first page drawn in place;
  - beside it, the project's name, title and author (your name to begin with);
  - the paper (A4 or US Letter, from your region) and font size, or for slides
    widescreen (16:9) or standard (4:3);
  - the engine (XeLaTeX and LuaLaTeX get fontspec and a `% !TEX program` line);
  - whether to add `references.bib`.
  Create… then asks where to save the folder. Titles and names are escaped, so any
  characters typeset as typed, and the choices are remembered for the next project.
  Every template, engine and page set-up was typeset with TeX Live to check it works.
- **Welcome window**
  - Clone Git Repository… clones a project from GitHub, GitLab or Overleaf with git and
    opens it. It never hangs on a password prompt: saved passwords come from the
    keychain, and failures are explained (missing command line tools, a password or
    token needed, an SSH key refused, a server that can't be reached, a repository
    that doesn't exist). A half-finished clone is removed.
  - Drop a project folder or a document on the window to open it.
  - Actions show their keyboard shortcuts.
- **Recent projects**
  - Each shows a thumbnail of its typeset first page (when TexLab has typeset it), its
    title, its location and when it was last opened.
  - A search field filters them by name, title or location.
  - Pin to Top keeps a project above the others, and pinned projects survive Clear
    Recent Projects.
  - A project that was moved or renamed can be found again with Locate…, starting in
    the nearest folder that still exists; or removed, along with any others that can't
    be found.
  - Copy Path in the context menu.
  - File ▸ Open Recent Project lists them in the menu bar too.
- **Opening a folder** with several complete documents and no `main.tex` now asks which
  one is the main file, listing each with its title, instead of guessing; the answer is
  remembered with the recent project.

## v1.22 — Live issues

- Like Xcode's live issues, TexLab now finds problems as you type, a moment after you
  pause, without typesetting. They appear in the Issues navigator under Found While
  Typing, in the gutter and in the status bar, and ⌘' moves through them:
  - an environment that isn't closed, is closed by the wrong `\end`, or has an `\end`
    without a `\begin`;
  - a `{` that isn't closed, or a `}` without a `{`;
  - a reference to a label nothing in the project defines (as a warning);
  - a citation missing from the bibliography (as a warning);
  - a label defined twice in the file (as a warning).
- The checks read the text the way TeX does, and stay quiet when they can't be sure:
  - Comments, `\{` and `\}`, `\verb`, `\lstinline`, `\url` and `\href` addresses,
    `\iffalse … \fi` and verbatim environments are understood. That includes verbatim
    environments the document or project defines with `\lstnewenvironment`,
    `\DefineVerbatimEnvironment`, `\newminted` or tcolorbox listings.
  - Environments inside a definition, such as the arguments of `\newenvironment`, and
    inside `\if … \fi` branches are left alone.
  - References aren't checked until the project has been scanned, nor in documents that
    use `xr` to refer to others.
  - Citations are only checked when every bibliography the document names is in the
    project.
- Settings ▸ General ▸ Show live issues turns them off.
- The status bar and the Issues tab count live issues with TeX's; the window subtitle
  still summarises the latest typesetting.

## v1.21 — Jump to Definition

- ⌘-click, Edit ▸ Jump to Definition (⌃⌘J) or the editor's context menu go from what is
  under the pointer to where it is defined, as in Xcode:
  - a reference (`\ref`, `\eqref`, `\cref`, …) goes to its `\label`, in this file or
    another file of the project;
  - a citation goes to its entry in the project's bibliography, or its `\bibitem`; with
    several keys, to the one clicked;
  - `\input`, `\include`, `\includegraphics`, `\bibliography`, `\addbibresource` and a
    project's own `\usepackage` or `\documentclass` open the file, found relative to the
    main file as TeX finds it;
  - a command the document or project defines goes to its `\newcommand`, `\def`,
    `\DeclareMathOperator` or `\NewDocumentCommand`, including those in the project's
    `.sty` files;
  - `\begin{…}` goes to its `\end{…}` and back, counting nested environments.
- In the Visual editor, ⌘-clicking a reference chip jumps to its label.
- The context menu names the jump: Jump to Definition, Open File, or Jump to `\end{…}`.
- ⌘-click anywhere else still selects as usual, and commented-out text is ignored.

## v1.20 — Placeholders: Tab through what a snippet needs

- Snippets now mark the places still to fill in, such as a figure's caption and label
  name, a fraction's denominator, a table's cells, a link's address and a frame's body.
  Tab moves to the next place and Shift-Tab to the previous one. Each place still to fill
  in shows as a faint insertion point. Tab at the last one moves past the snippet.
- The text itself contains nothing extra; the editor only remembers the positions. They
  are forgotten once the insertion point leaves the snippet, so Tab and Shift-Tab indent
  as usual everywhere else.
- Completing a command with several arguments inserts a pair of braces for each, with Tab
  moving between them: `\frac`, `\binom`, `\textcolor`, `\href`, `\newcommand`,
  `\newenvironment`, `\SI` and others.
- Insert ▸ Table makes every cell a place to fill in, along with the caption and label.

## v1.19 — App icon

- The TexLab app icon, drawn in Pixelmator Pro and assembled in Icon Composer, with its
  sources in `icon/` and the exported sizes (default, dark and tinted) in
  `Assets.xcassets/AppIcon`. It also appears in the Welcome window.
- App Sandbox is off in the project, as TeX needs; the shared Xcode scheme is committed.

## v1.18 — Fixes: crash opening a second file, preview divider, theorem labels

- Fixed a crash when opening another file from the project navigator. The editor/preview
  split view replaced its panes' SwiftUI content while the new window was being laid out
  and refreshed cursor areas from `layout()`, which could keep asking for another layout
  pass until AppKit gave up. Content is now updated after layout, cursor areas after a
  resize, and the Visual editor's centred column no longer depends on whether a scroll bar
  is showing (another way two layouts could chase each other).
- Hiding the preview now takes it out of the split view, so no divider line is left at the
  edge of the editor; showing it again restores its width.
- Visual editor: Definition, Proof and other environment headings no longer lose their
  last letter. Labels are drawn on the text's baseline without a width limit, and theorem
  headings use the text's typeface and size — bold, with Proof in italic, as LaTeX sets
  them.

## v1.17 — Build fix

- The line length slider's two value labels are the same view type, as `Slider` requires.

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
