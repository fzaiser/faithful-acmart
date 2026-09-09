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
The date parser handles calendar dates, partial dates, uncertainty, seasons, and intervals before the renderer formats them.

## Corrections

The bundled LaTeX sources contain defects that faithful output reproduces.
The `fix-quirks` option corrects the ones listed here while keeping ACM formatting; it is off by default, so the paired fixtures keep checking the LaTeX-compatible output.
Enabling it is not a claim that every upstream defect is fixed, and leaving it off is not a claim of exact LaTeX identity.

| Correction | Applies to |
|---|---|
| A DOI that already carries a `doi.org` or `dx.doi.org` resolver URL produces one resolver link instead of a doubled one. | The `doi` option; the BibLaTeX backend |
| An `inbook` entry that has an author leads with that author, and its editor follows the book title. | The BibLaTeX backend |
| An entry with no printable date contributes no empty parentheses and no separator of its own. | The BibLaTeX backend |
| An opening author, editor, or organization that already ends in a sentence period takes no second one. | The BibLaTeX author–year style |
| A page or section locator survives on author-only and year-only numeric citations. | The BibTeX backend |
| A space separates `See` from the cross-referenced entry. | The BibTeX backend |
| Terminal punctuation is recognized after an uppercase letter, so a heading, proof name, author note, or contact line that ends in an abbreviation keeps one period. | Headings, proofs, and front matter |

Typst's native CSL backend is unaffected: its formatting comes from Typst.

## Compatibility

The user reference lists [capabilities and compatibility limits](docs/reference.md#compatibility).
For a measured layout difference, record the bounded expectation in [test_matrix.py](tools/test_matrix.py) and follow the [comparison workflow](CONTRIBUTING.md#investigating-a-difference).
