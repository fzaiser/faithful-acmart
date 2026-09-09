# Design

This port targets the `acmart` sources bundled in [acmart/](acmart/).
Layout values come from those sources or measurements of their rendered output.
The tests establish agreement for specific documents; they do not imply identical layout for every paper.

## Architecture

[src/lib.typ](src/lib.typ) exposes the public API and applies the document's styles.
[Options](src/parts/options.typ) and [metadata](src/parts/metadata.typ) are resolved before rendering, so layout functions receive a format configuration and normalized paper metadata.
Body-level functions, such as theorems and citations, read the active configuration through Typst state.

Explicit top-matter arguments override format defaults where LaTeX distinguishes preamble settings from later `\settopmatter` calls.
This allows, for example, `print-acm-reference: true` with `nonacm`.

Formats are dictionaries built from shared defaults in [formats/_base.typ](src/formats/_base.typ).
Each [format builder](src/formats/) supplies its geometry and typography choices.
This keeps layout rules shared across formats and centralizes font-size-dependent measurements.

[Front matter](src/parts/frontmatter.typ), [body styles](src/parts/body.typ), [headings](src/parts/headings.typ), and [page headers and footers](src/parts/page-chrome.typ) handle rendering.
In two-column formats, a page-wide title float precedes the abstract in the first column.
Bottom floats reserve space for the first-page footnote streams.

## Layout model

TeX and Typst use different point units.
The `tp` constant converts TeX measurements to Typst lengths; paper dimensions can use physical units directly.
Use [spacing.typ](src/parts/spacing.typ) for leading and vertical gaps.
It compensates for the difference between TeX's baseline spacing and Typst's line boxes, using the following block's font metrics.
The title uses its measured cap height to position the first line.

Font-size steps and some spacing come from `amsart`, and begin-document hooks can override acmart's earlier settings.
Consult the executed class or a probe before changing a value that appears inconsistent with a source declaration.
Keep the relevant upstream macro or constraint beside the code when the reason would otherwise be hard to recover.

## Bibliography model

The custom backends reproduce ACM's BibTeX and BibLaTeX formatting without requiring a TeX installation to compile a paper.
Typst's native CSL backend remains available, with its own field mapping and formatting limits.

[bibtex.typ](src/parts/bibtex.typ) reads raw fields; the [BibTeX](src/parts/acmref-bst.typ) and [BibLaTeX](src/parts/acmref-biblatex.typ) renderers apply their respective styles.
[acmref-cite.typ](src/parts/acmref-cite.typ) resolves cited entries, inheritance, sorting, and citation labels.
Fields retain TeX syntax until rendering because braces and control sequences affect name parsing, capitalization, and sorting.
[tex.typ](src/parts/tex.typ) interprets a bounded set of TeX commands and rejects unknown commands; `tex-render` provides an extension point for field presentation.

The package replaces `bibliography` because Typst validates native bibliography input before a show rule can intercept it.
It replaces `cite` to support grouped citations and routes unresolved `@key` references through the same backend.

BibLaTeX name disambiguation alternates name expansion and list expansion until they stabilize, matching Biber's dependency between those passes.
Its date parser deliberately covers the forms in the date fixtures, including uncertain dates, seasons, and intervals.
Keep that coverage tied to executable comparisons with Biber when changing the parser.

## Compatibility limits

### Page layout

- Typst lacks TeX's stretchable page glue, final-column balancing, and `microtype` font expansion and protrusion.
  Pages remain ragged at the bottom, and line and page breaks can differ.
- Math uses Libertinus Math and approximate display spacing.
  TeX's short-display skips and exact math metrics are not reproduced.
- First baselines on continuation pages, captions, floats, and footnote stream boundaries can differ slightly because the engines use different line-box depths.
  Measured allowances belong in [test_matrix.py](tools/test_matrix.py).
- Wrapped numbered headings do not have LaTeX's hanging indent.
  The simple layout preserves tagged-PDF reading order.
- Term lists lack acmart's label-column geometry, and the separate LaTeX `quotation` layout is unsupported.
- Text after display equations or code blocks continues without indentation.
  Typst cannot distinguish a continued paragraph from LaTeX's blank-line-separated new paragraph there; add explicit horizontal spacing when an indent is needed.
- Widow and orphan avoidance uses Typst's layout costs; TeX's hard break penalties, including its penalty after a hyphen, have no exact equivalent.

### Special formats and metadata

- `sigchi-a` footnotes remain in the body.
  Margin notes can shift near block boundaries and overlap when placed at the same anchor; place consecutive notes at different paragraphs.
- The narrow `acmcp` infobox wraps long URLs and email addresses differently from LaTeX.
- Top-matter note marks use a consistent superscript size; LaTeX's oversized section-sign mark is not reproduced.
  Corresponding-author marks have a fixed order relative to other notes.
- A draft timestamp contains the compile date without the time of day.
  The `draft` option for overfull-line markers is unsupported; `author-draft` provides the review watermark.
- PDF Subject metadata is unavailable through Typst's document API.
  Additional affiliations can be expressed as author notes.

### References

- BibLaTeX sorting approximates Unicode collation.
  Ordering can differ for accent-only ties, punctuation, and unsupported character commands.
- BibLaTeX citation disambiguation can expand name lists, but that expansion does not propagate to long reference-list names or sort keys.
- Punctuation-only initials retain their period throughout a grouped citation; BibLaTeX can omit it after a preceding entry.
- The TeX field renderer supports a subset of bibliography commands and inline math.
  In math, `/` becomes a fraction and `\left`/`\right` do not resize delimiters.
  URLs bypass TeX rendering, and inline math is unsupported in plain-text citation labels.
- BibTeX's warning diagnostics are not reproduced.

For a particular mismatch, inspect the fixture's expected differences in [test_matrix.py](tools/test_matrix.py) and use the [comparison workflow](CONTRIBUTING.md#investigating-a-difference).
