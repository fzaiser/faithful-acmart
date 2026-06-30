"""Test matrix — the single source of truth for the regression harness.

`tools/test.py` is the command runner; this module is its data. Everything the
gates need lives here as typed Python: the test list (one `Test` per stem), the
text assertions, the Tier 2 metric tolerances, the expected compile-error cases,
the copyright/option validation variants, the pinned Typst version, and the
golden raster DPI.

Test kinds
----------
- ``twin``  matched ``NAME.tex`` (real LaTeX acmart) + ``NAME.typ`` (ours),
            compared page-by-page; assets (bib, images) in ``tests/twins/``.
- ``smoke`` Typst-only doc with no LaTeX twin: compiled (warning-free) and,
            when deterministic, golden-hashed. Alias/feature paths the
            matched twins don't cover.

The Tier 1 goldens are captured with `TYPST_VERSION` + the bundled fonts at
`GOLDEN_DPI`; bumping Typst means regenerating them (`tools/test.py accept`).
"""

from __future__ import annotations

from dataclasses import dataclass, field

# The engine the Tier 1 goldens were captured with. Bumping Typst means
# regenerating the golden hashes (`tools/test.py accept`).
TYPST_VERSION = "0.14.2"

# Raster resolution (dpi) for the Tier 1 page-hash snapshots.
GOLDEN_DPI = 150

# Tier 2 gate tolerances (PDF points; both engines emit 1/72in big points).
# Only robust, renderer-agnostic invariants are gated. Right margin and line
# count depend on cross-engine line-breaking, so metrics report them but does
# not gate on them.
METRICS_TOLERANCE = {
    "left": 1.0,   # text-block left edge — true horizontal invariant, gated tightly
    "top": 4.5,    # first-content vertical position — loose: absorbs glyph-bbox
                   # ascent conventions and title-page variance, still catches gross shifts
    "pitch": 0.6,  # median baseline-to-baseline pitch — gated only on uniform_pitch tests
    "line_pitch": 0.8,  # max single-line pitch deviation — gated on uniform_pitch tests
                        # whose lines break identically across engines (so the per-line
                        # pitch sequences align). Catches one mis-spaced line that the
                        # median absorbs; skipped when line counts diverge.
}


@dataclass(frozen=True)
class Assertion:
    """A targeted text-layer assertion for a noisy twin (Tier 1.5).

    ``engine``: which PDF(s) to scan — ``typst``, ``latex``, or ``both``.
    ``kind``:   ``contains`` (text must be present) or ``absent`` (must not be).
    ``page``:   1-based page to scan, or ``None`` for the whole document.
    """

    text: str
    kind: str = "contains"
    engine: str = "typst"
    page: int | None = None


@dataclass(frozen=True)
class Test:
    """One test stem and how the gates treat it.

    ``page_parity`` defaults to ``True`` for twins (LaTeX/Typst page counts must
    match) and ``False`` otherwise; pass an explicit bool to override.
    ``uniform_pitch`` marks tests whose body is on a single baseline grid, so
    median baseline pitch is meaningful and gated. ``page1_only`` gates absolute
    vertical positions on page 1 only (multi-page docs drift downward via
    acmsmall's \\flushbottom, which Typst can't replicate). ``text_equal`` /
    ``text_reason`` / ``text_assertions`` drive Tier 1.5. ``note`` is
    documentation only.

    ``text_equal`` selects the Tier 1.5 whole-document text gate:
    ``True`` exact normalized-sequence equality (strictest; single-column docs
    whose lines extract in the same order); ``"bag"`` exact word-MULTISET equality
    — order-independent, for twins whose blocks reorder under extraction (two
    -column flow, footnotes, the acmcp cover infobox), but still catches any single
    word that goes missing or appears; ``False`` not gated (give ``text_reason``);
    ``None`` unset.

    Independently of ``text_equal``, EVERY twin is also gated by an exact char
    -multiset check (``char_bag``) — a stricter tripwire that keeps punctuation and
    so catches a stray comma/period the word bag's edge-strip drops. Set
    ``char_diff`` to a one-line reason to exempt a twin whose char bags cannot
    match (a known content difference, or a pdftotext extraction artifact).

    EVERY twin is ALSO gated by the Tier 1.8 per-letter FONT check (``font_bag``,
    via PyMuPDF): each alphabetic character must render in the same family (serif/
    sans/mono), weight, italic, size, and colour as LaTeX. Set ``font_diff`` to a
    one-line reason to exempt a twin whose fonts cannot match (a known content
    difference, or a math-fidelity gap).

    EVERY twin is ALSO gated by the Tier 1.9 per-chunk reading-ORDER check
    (``pdf_chunks``, via pikepdf): the tagged Typst PDF's logical chunks (title,
    each author line, contact-info, headings, bib entries) must appear in the flat
    LaTeX stream in the same intra-chunk order — catching an element emitted out of
    order (an affiliation/email swap, a reordered citation field) that the order
    -independent word/char bags cannot see. Set ``order_diff`` to a one-line reason
    to exempt a twin whose chunk order cannot be checked (an extraction asymmetry).
    """

    kind: str
    pages: int
    reference: str | None = None
    _page_parity: bool | None = None
    metrics: bool = True
    golden: bool = True
    page1_only: bool = False
    uniform_pitch: bool = False
    text_equal: bool | str | None = None
    text_reason: str | None = None
    text_assertions: tuple[Assertion, ...] = ()
    char_diff: str = ""
    font_diff: str = ""  # exempt a twin from the Tier 1.8 per-letter font/size/colour gate
    order_diff: str = ""  # exempt a twin from the Tier 1.9 per-chunk reading-order gate
    link_check: bool = False  # compare hyperlink (/URI) sets LaTeX vs Typst
    note: str = ""

    @property
    def ref_stem(self) -> str:
        return self.reference if self.reference is not None else ""

    @property
    def subdir(self) -> str:
        """Tests live in tests/<subdir>/: ``twins`` for the matched
        ``NAME.tex``+``NAME.typ`` pairs, ``typst-only`` for everything else
        (smoke docs and the upstream-ref port, which have no local ``.tex``)."""
        return "twins" if self.kind == "twin" else "typst-only"

    @property
    def page_parity(self) -> bool:
        if self._page_parity is not None:
            return self._page_parity
        return self.kind == "twin"


def reference_for(name: str, t: Test) -> str:
    """LaTeX stem to compare/diff a test against (defaults to the test name)."""
    return t.reference if t.reference is not None else name


# Shared gate settings for all bundled-sample twins. Visual fidelity is checked
# via `test.py overlay`; text/font/metrics/order gates are all exempted:
# - text_equal=False / char_diff: \\LaTeX logo → "LATEX" in LaTeX vs "LaTeX" in
#   Typst, ACM bibstrip/copyright wording, math glyph encoding differences, and
#   multi-column extraction ordering all cause word/char bag divergence.
# - font_diff: math + verbatim blocks cause per-letter font-count differences as
#   body text reflows between engines; not a body-text font bug.
# - metrics=False: mode-specific layout (line numbers, anonymous margins, Huge
#   title positions) causes Tier-2 geometry differences not worth gating here —
#   the specialized -test twins gate each mode's geometry precisely.
# - order_diff: the reading-order gate assumes structural regularity not met by
#   complex multi-page docs with floats, appendices, and multi-column flow.
_SAMPLE_COMMON = dict(
    _page_parity=False, page1_only=True, metrics=False,
    text_equal=False,
    text_reason="whole-doc word bag diverges on \\LaTeX logo rendering, ACM "
                "bibstrip/copyright wording, and multi-column extraction order; "
                "visual fidelity is checked via test.py overlay instead",
    char_diff="\\LaTeX logo → different codepoints, ACM bibstrip wording, and math "
              "glyph encoding differ between engines across the full sample document",
    font_diff="math + verbatim blocks cause per-letter font-count divergence as body "
              "reflows between engines; not a body-text font bug",
    order_diff="complex multi-page layout (floats, appendices, multi-column); "
               "reading-order gate does not apply to the full bundled sample",
)

# --- The test matrix -------------------------------------------------------
#
# Order is the run/report order. Twins come first, then smoke-only docs.
TESTS: dict[str, Test] = {
    "body-test": Test(
        kind="twin", pages=1, uniform_pitch=True, text_equal=True,
        note="body typography: font, size, baseline grid, justification, indent",
    ),
    "head-test": Test(
        kind="twin", pages=1, uniform_pitch=True,
        note="section / subsection / subsubsection / paragraph (run-in) headings",
    ),
    "body2-test": Test(
        kind="twin", pages=1,
        note="figure & table captions, theorems (plain/definition/proof+QED), lists",
    ),
    "list-test": Test(
        kind="twin", pages=1,
        note="isolated itemize/enumerate geometry: bullet size, zero itemsep, "
             "topsep, and paragraph indentation after lists.",
    ),
    "fn-test": Test(
        kind="twin", pages=1,
        note="body footnotes + code/verbatim",
    ),
    "full-test": Test(
        kind="twin", pages=2, page1_only=True, uniform_pitch=True,
        note="multi-page cumulative spacing (reveals the \\flushbottom difference)",
    ),
    "title-test": Test(
        kind="twin", pages=1,
        note="frontmatter in isolation: title block, author fields, abstract, CCS, keywords",
    ),
    "manuscript-test": Test(
        kind="twin", pages=1,
        note="format=manuscript: single-column draft geometry (letterpaper, 9pt default) "
             "with the generic sans-bold section fonts shared with acmsmall.",
    ),
    "manuscript-pages-test": Test(
        kind="twin", pages=2, page1_only=True, text_equal="bag",
        text_assertions=(
            Assertion(engine="both", page=2, text="Lovelace and Hopper"),
            Assertion(engine="both", page=2, text="Manuscript submitted to ACM"),
        ),
        note="Continuation-page header/footer + multi-page body. Body flow reorders "
             "across engines, so text is gated order-independently (word-bag).",
    ),
    "acmlarge-test": Test(
        kind="twin", pages=1,
        note="format=acmlarge: large single-column journal geometry (10pt) with the "
             "\\sffamily\\large (regular-weight) section headings (acmart.dtx:8424).",
    ),
    "acmlarge-pages-test": Test(
        kind="twin", pages=2, page1_only=True, text_equal="bag",
        text_assertions=(
            Assertion(engine="both", page=2, text="Lovelace and Hopper"),
            Assertion(engine="both", page=2, text="111:2"),
            Assertion(engine="both", page=2, text="J. ACM, Vol. 37, No. 4, Article 111"),
        ),
        note="acmlarge continuation page header/footer; body reorders, so text is "
             "gated order-independently (word-bag).",
    ),
    "acmtog-test": Test(
        kind="twin", pages=1, page1_only=True,
        note="format=acmtog: two-column JOURNAL. Spanning left @i title + author list, "
             "contact-info footnote + ACM bibstrip + journal footer, 9pt parindent, "
             "sans-large sections.",
    ),
    "acmtog-pages-test": Test(
        kind="twin", pages=2, page1_only=True, text_equal="bag",
        text_assertions=(
            Assertion(engine="both", page=2, text="Lovelace and Hopper"),
            Assertion(engine="both", page=2, text="111:2"),
            Assertion(engine="both", page=2,
                      text="ACM Trans. Graph., Vol. 37, No. 4, Article 111"),
        ),
        note="acmtog two-column continuation page; column order differs under "
             "extraction, so text is gated order-independently (word-bag).",
    ),
    "sigconf-test": Test(
        kind="twin", pages=1, page1_only=True, text_equal="bag",
        text_assertions=(
            Assertion(engine="both", text="Abstract"),
            Assertion(engine="both", text="Keywords"),
            Assertion(engine="both", text="In Proceedings of ACM Conference"),
            Assertion(engine="both", text="ACM, New York, NY, USA"),
            Assertion(engine="both", kind="absent", text="Additional Key Words and Phrases"),
            Assertion(engine="typst", kind="absent", text="Journal of the ACM"),
        ),
        note="format=sigconf: two-column proceedings. Spanning centered title + author "
             "grid, first-column copyright block, serif-bold Large sections. Two columns "
             "break differently across engines (higher pixel mismatch expected); "
             "page1_only gates absolute positions on the title page only.",
    ),
    "sigconf-pages-test": Test(
        kind="twin", pages=2, page1_only=True, text_equal="bag",
        text_assertions=(
            Assertion(engine="both", page=2, text="Lovelace and Hopper"),
            Assertion(engine="both", page=2,
                      text="Conference'17, June 2018, Washington, DC, USA"),
        ),
        note="sigconf two-column continuation page; column order differs under "
             "extraction, so text is gated order-independently (word-bag).",
    ),
    "sigconf-authors-test": Test(
        kind="twin", pages=1, page1_only=True,
        note="Conference author grid with a PARTIAL last row (5 groups at 3-per-row => "
             "3 + 2). Guards make-authors-grid's per-row centering: the final row of 2 "
             "is centered, not left-aligned (validated against LaTeX).",
    ),
    "sigplan-test": Test(
        kind="twin", pages=1, metrics=False,
        note="format=sigplan: sigconf variant — serif-bold Huge title (no sans), 10pt, "
             "1in/0.75in margins, serif-bold sections, sans URLs. Tier 2 top-position is "
             "report-only: the Huge serif title pins its cap-top to the margin, but "
             "topmost-ink overshoots LaTeX's baseline placement by ~5pt of glyph bbox.",
    ),
    "acmengage-test": Test(
        kind="twin", pages=1, metrics=False,
        note="format=acmengage: sigconf variant (10pt, booktitle copyright line). Tier 2 "
             "top-position is report-only (same reason as sigplan): the 10pt Huge title "
             "pins its cap-top to the margin but topmost-ink overshoots by ~5pt. Left "
             "edge matches.",
    ),
    "acmcp-test": Test(
        kind="twin", pages=1, metrics=False, text_equal=False,
        text_reason="the cover-infobox code/data link now shows the full URL (matching "
                    "\\url), so the exact char bag gates cleanly. The URL is wider than the "
                    "5pc box: Typst wraps it (example.com / data) where LaTeX overflows the "
                    "box on one line, so only the word bag would split that one token.",
        text_assertions=(
            Assertion(engine="both", text="Research Article"),
            Assertion(engine="both", text="Keywords: datasets"),
            Assertion(engine="both", text="BT designed the study"),
            Assertion(engine="both", text="Authors' Contact"),
            Assertion(engine="both", text="Information: Ben"),
            Assertion(engine="both",
                      text="Journal of the ACM, Volume 37, Issue 4, Article 111"),
            Assertion(engine="typst", kind="absent",
                      text="Permission to make digital or hard copies"),
            Assertion(engine="typst", kind="absent",
                      text="Additional Key Words and Phrases"),
        ),
        note="format=acmcp: ACM cover page (best-effort). Single-column, unnumbered "
             "sections, ACM reference format off; the JDS cover frame + infobox ARE "
             "reproduced (only the infobox's vertical anchoring is approximated). Tier 2 "
             "is report-only: the page's first ink is the cover frame/logo, not the text "
             "block.",
    ),
    "sigchi-a-test": Test(
        kind="twin", pages=2, page1_only=True, metrics=False, text_equal="bag",
        note="format=sigchi-a: landscape SIGCHI extended abstracts. The @mktitle@iv head "
             "(5pc-leftskip title under a 2pt rule), the @mkauthors@iv author grid (bold "
             "mixed-case name + email + affiliation, 2 per row, left-aligned), the one-sided "
             "running head (shorttitle + dated conference), and the 'Legacy document' "
             "watermark (breaking before 'ACM venue') now all match LaTeX — char AND word "
             "bags are exact. Remaining approximation: margin-note footnotes (\\marginpar) "
             "are omitted, so cross-engine geometry is report-only (metrics off); the twin "
             "gates page-count parity and the exact text bags.",
    ),
    "fontsize-8-test": Test(
        kind="twin", pages=1, uniform_pitch=True, text_equal=True,
        note="Base font-size option `8pt`: amsart \\@typesizes ladder + "
             "baselineskip-derived heading/skip scaling. Body is on one grid, so pitch is gated.",
    ),
    "fontsize-9-test": Test(
        kind="twin", pages=1, uniform_pitch=True, text_equal=True,
        note="Base font-size option `9pt`.",
    ),
    "fontsize-11-test": Test(
        kind="twin", pages=1, uniform_pitch=True, text_equal=True,
        note="Base font-size option `11pt`.",
    ),
    "fontsize-12-test": Test(
        kind="twin", pages=1, uniform_pitch=True, text_equal=True,
        note="Base font-size option `12pt`.",
    ),
    "bib-test": Test(
        kind="twin", pages=1, uniform_pitch=True,
        char_diff="vendored ACM CSL now matches the .bst on doi:/month/genre/conf-date; "
                  "residual gaps are hayagriva BibTeX->CSL mapping limits (dropped "
                  "lastaccessed date, @periodical journal name, thesis school+advisor and "
                  "\"Ph. D.\" vs \"Doctoral dissertation\" wording, conference address)",
        font_diff="same CSL-vs-bst content differences (above): the reference list reflows, "
                  "so per-letter font counts differ on the diverging words (all serif, same "
                  "sizes — not a font bug)",
        note="bibliography. src/styles/acm-reference-format.csl is forked to track the "
             "bundled ACM-Reference-Format.bst (doi: prefix, abbreviated months, report "
             "genre label, thesis note, conference-location parens). The remaining "
             "divergences are data hayagriva never populates from the .bib, so the list "
             "reflows slightly and line count is reported, not gated. Margins/pitch are "
             "held to the same bar.",
    ),
    "biblatex-test": Test(
        kind="twin", pages=1,
        char_diff="isolates the BibLaTeX acmnumeric-vs-Typst bibliography gap: "
                  "BibLaTeX/biber uses different title casing, journal names, DOI "
                  "punctuation, and online retrieval fields than both the CSL and "
                  "bst renderers.",
        font_diff="same BibLaTeX formatting gap: the reference entries reflow across "
                  "different words, so the per-letter font bag is not meaningful.",
        order_diff="intentional BibLaTeX-vs-Typst bibliography formatting comparison; "
                   "reference chunks reflow and do not share stable ordering.",
        text_assertions=(
            Assertion(engine="latex", text="Communications of the ACM"),
            Assertion(engine="typst", text="References"),
        ),
        note="small BibLaTeX acmnumeric isolator so the full sample-sigconf-biblatex "
             "reference-format difference can be inspected without the full upstream "
             "sample body.",
    ),
    "bib-all": Test(
        kind="twin", pages=1,
        note="Every ACM-Reference-Format entry type via the `bst` bibliography backend "
             "(acmart.with(bibliography-backend=\"bst\") + acm-cite/acm-bibliography). A "
             "pure-Typst port of ACM-Reference-Format.bst (src/parts/{bibtex,acmref}.typ) "
             "that reproduces the .bst's reference text exactly — char bag gated with NO "
             "exemption (contrast bib-test's CSL gaps). One representative of each handler: "
             "article, periodical, book, inbook, incollection, inproceedings, mastersthesis, "
             "phdthesis, techreport, online, misc, manual, presentation, underreview, "
             "preprint, software, dataset, proceedings, booklet. Reads sample-base.bib plus "
             "the crafted tests/twins/bib-all-extra.bib (clean proceedings/booklet/manual). "
             "Pitch reported, not gated (heading + hanging-indent grid mix leadings). "
             "link_check gates the DOI/URL/arXiv hyperlink set against bibtex+hyperref.",
        link_check=True,
    ),
    "bib-edge": Test(
        kind="twin", pages=1,
        note="Field/path edge cases of the bst backend that bib-all's type sweep doesn't "
             "hit, each source-audited against ACM-Reference-Format.bst: strip.doi host "
             "prefix, reduce.pages.to.page.count, format.bookpages, book \"pages\" label, "
             "issue, howpublished in article/inproceedings, format.key fallback, journal "
             "MACRO + canon.abbrev, @string/# concatenation, von-name parsing, unpublished, "
             "and TeX accent/special-letter decoding (\\\"o->ö, \\H{o}->ő, \\ss->ß) via the "
             "single-pass lexer in bibtex.typ. Char bag gated, no exemption; pitch reported.",
        link_check=True,
        # Word-level guards for things the whitespace-free char bag can't see.
        text_assertions=(
            Assertion(engine="both", text="Tech Press, Ltd."),       # concat keeps the space
            Assertion(engine="both", text="Comput. Surveys"),        # csur macro -> canon.abbrev
            Assertion(engine="both", text="Submitted to Mind"),      # @unpublished note
            Assertion(engine="both", text="Maria de la Cruz"),       # von-name parsing
            Assertion(engine="both", kind="absent", text="doi.acm.org"),  # strip.doi drops the host prefix
            Assertion(engine="both", text="Article 17"),             # articleno path
            Assertion(engine="both", text="9:1"),                    # reduce.pages keeps n:1--n:m verbatim
            Assertion(engine="both", text="250 book pages"),         # format.bookpages
            Assertion(engine="both", text="Issue 7"),                # issue field
            Assertion(engine="both", text="Preprint"),               # howpublished in @article
            Assertion(engine="both", text="Jan von der Berg"),       # comma von-name
            Assertion(engine="both", text="Ludwig van Beethoven"),   # no-comma von-name
        ),
    ),
    "crossref": Test(
        kind="twin", pages=1,
        note="BibTeX crossref handling reproduced by the bst backend (this is BibTeX "
             "engine behaviour, not the .bst): field inheritance from the crossref'd "
             "parent + the min_crossrefs=2 listing threshold. xparent is crossref'd "
             "twice -> listed, so its children render the .bst's \"See [N]\" "
             "(format.incoll.inproc.crossref); xlonely is crossref'd once -> not listed, "
             "so xsolo inherits its booktitle/series/editor/publisher/address and renders "
             "in full. Also covers the organization->key label fallback for "
             "proceedings/manual (prockey) and the per-entry distinctURL field (durl: "
             "url printed alongside the doi). Char bag gated, no exemption.",
        link_check=True,
        text_assertions=(
            Assertion(engine="both", text="See ["),                  # crossref "See [N]"
            Assertion(engine="both", text="Workshop on Small Things"),  # inherited booktitle (excluded parent)
            Assertion(engine="both", text="GangOfFour"),             # proceedings org->key fallback
        ),
    ),
    "authoryear": Test(
        kind="twin", pages=1,
        note="bst backend in author-year citation mode (\\citestyle{acmauthoryear} / "
             "cite-style=\"author-year\"): short \"Author et al. Year\" labels "
             "(format.lab.names), the \\natexlab a/b year disambiguation on the two "
             "colliding 2020 articles, and a reference list with NO leading numbers. "
             "\\citep -> \"[Label Year]\" (with natbib year compression \"2020a,b\"); "
             "\\citet -> \"Label [Year]\". Char bag gated, no exemption.",
        text_assertions=(
            Assertion(engine="both", text="2020a"),                  # \natexlab suffix
            Assertion(engine="both", text="Jones et al."),           # >2-author short label (\citet)
        ),
    ),
    "mathfields": Test(
        kind="twin", pages=1,
        font_diff="residual math-rendering gap (variables now match — both slant via the "
                  "math-italic codepoints): \\log renders in LaTeX's serif text font but "
                  "Typst's math font, and math subscripts use a slightly different "
                  "scriptstyle size (6 vs 5.5pt); not a body-text font bug",
        note="inline math ($...$) in reference fields via the bst backend, rendered as "
             "REAL Typst math (tex.typ tokenizer -> math evaluator -> eval): greek "
             "letters, ^/_ grouping, relations/operators (\\leq, \\log), \\frac, "
             "\\oplus, and \\mathbb. Real Typst math extracts to the same char bag as "
             "LaTeX's math-italic output (𝜆, scripts as plain digits, ℝ->R under NFKC). "
             "Also exercises the `tex-render` override (composed with default-tex-render) "
             "for custom commands (\\widget, \\RR). Char bag gated, no exemption.",
        text_assertions=(
            Assertion(engine="both", text="-calculus"),              # $\lambda$-calculus
        ),
    ),
    "keycite": Test(
        kind="twin", pages=1,
        note="native `@key` citation routing for the bst backend: acmart installs a "
             "`show ref:` rule (lib.typ, gated to bibliography-backend=\"bst\") that "
             "intercepts bare `@Cohen07` refs whose target is no document label "
             "(it.element == none) and renders them via the bst engine — the same "
             "show-rule hook alexandria/pergamon use. The LaTeX twin uses \\cite. "
             "Char bag gated, no exemption.",
        link_check=True,
    ),
    "notes-test": Test(
        kind="twin", pages=1,
        note="title/subtitle/author notes, corresponding mark, received line, and acks. "
             "The title block and footnote stack mix leadings, so pitch is reported, not gated.",
    ),
    "options-test": Test(
        kind="twin", pages=2, page1_only=True,
        note="toggles nonacm / printccs=false / printfolios=false plus the single-column "
             "no-ops balance=false / natbib=false. Two pages so page 2 shows suppressed "
             "folios in the running head. Mixed leadings, so pitch is reported, not gated.",
    ),
    "authorversion-test": Test(
        kind="twin", pages=1,
        note="author-version copyright block (suppressed permission text + \"author's "
             "version ... Version of Record\" notice). Mixed leadings, so pitch is reported.",
    ),
    "language-test": Test(
        kind="twin", pages=1,
        note="multilingual paper (acmart `language` option): French main language with "
             "English translated title/abstract/keywords. Verifies localized fixed strings "
             "(keywordsname/acksname/proofname) and French hyphenation.",
    ),
    "language-de-test": Test(
        kind="twin", pages=1,
        note="German `language=german`: keywordsname/acksname/proofname + tablename "
             "(\"Tabelle\") localized, figure label still \"Fig.\"",
    ),
    "language-es-test": Test(
        kind="twin", pages=1,
        note="Spanish `language=spanish`: keywordsname/acksname/proofname + tablename "
             "(\"Cuadro\") localized, figure label still \"Fig.\"",
    ),
    # Full twins of the bundled acmart samples (acmart/samples/*.tex).
    # Each has a matched .tex/.typ pair in tests/twins/; assets (sample-base.bib,
    # sample-franklin.png, sampleteaser.*) are vendored into tests/twins/ so the
    # build does not depend on the acmart/ reference folder. They share one body via
    # _sample-common.typ; only the preamble (format + options) differs.
    # _page_parity is off: acmart's \flushbottom rubber-fills full pages, Typst is
    # ragged-bottom, so Typst typically runs 1-2 pages shorter on multi-page docs.
    # text_equal=False / order_diff: see _SAMPLE_COMMON above.
    "sample-acmsmall": Test(
        kind="twin", pages=11, **_SAMPLE_COMMON,
        note="full twin of the upstream acmsmall sample.",
    ),
    "sample-manuscript": Test(
        kind="twin", pages=10, **_SAMPLE_COMMON,
        note="upstream manuscript sample (manuscript,screen,review + proceedings "
             "metadata). Single-column review style with margin line numbers.",
    ),
    "sample-acmlarge": Test(
        kind="twin", pages=11, **_SAMPLE_COMMON,
        note="upstream acmlarge sample (wide single-column journal, POMACS).",
    ),
    "sample-sigconf": Test(
        kind="twin", pages=6, **_SAMPLE_COMMON,
        note="upstream sigconf sample: two-column proceedings, spanning title, "
             "centred author grid, teaser figure.",
    ),
    "sample-sigplan": Test(
        kind="twin", pages=7, **_SAMPLE_COMMON,
        note="upstream sigplan sample (two-column SIGPLAN proceedings, 10pt).",
    ),
    "sample-acmsmall-submission": Test(
        kind="twin", pages=10, **_SAMPLE_COMMON,
        note="upstream acmsmall double-anonymous review sample "
             "(screen,anonymous,review): anonymized author strip + line numbers.",
    ),
    "sample-acmsmall-conf": Test(
        kind="twin", pages=11, **_SAMPLE_COMMON,
        note="upstream acmsmall-for-a-conference sample (acmsmall journal format "
             "with conference metadata replacing the journal metadata).",
    ),
    "sample-acmtog": Test(
        kind="twin", pages=6, **_SAMPLE_COMMON,
        note="upstream acmtog sample (two-column TOG journal). Uses the author-year "
             "citation style (\\citestyle{acmauthoryear}) via the bst backend.",
    ),
    "sample-acmtog-conf": Test(
        kind="twin", pages=6, **_SAMPLE_COMMON,
        note="upstream acmtog-for-a-conference sample (acmtog two-column with "
             "conference metadata + teaser; author-year citations via the bst backend).",
    ),
    "sample-sigconf-i13n": Test(
        kind="twin", pages=7, **_SAMPLE_COMMON,
        note="upstream sigconf internationalization sample: \\translatedtitle + "
             "translatedabstract in French/German/Spanish (English main), each "
             "abstract headed by its babel \\abstractname.",
    ),
    "sample-sigconf-authordraft": Test(
        kind="twin", pages=6, golden=False, **_SAMPLE_COMMON,
        note="upstream sigconf authordraft sample: draft watermark + line numbers "
             "+ inner-edge timestamp. The timestamp embeds the compile date, so "
             "output is non-deterministic — compile-only (no golden), like draft-test.",
    ),
    "sample-acmsmall-biblatex": Test(
        kind="twin", pages=11, **_SAMPLE_COMMON,
        note="upstream acmsmall-biblatex sample: acmsmall with BibLaTeX acmauthoryear "
             "style (author-year). Software artifact cites from software.bib "
             "(@software/@softwaremodule/@codefragment) are omitted — these biblatex-"
             "software entry types have no equivalent in the bst backend.",
    ),
    "sample-sigconf-biblatex": Test(
        kind="twin", pages=6, **_SAMPLE_COMMON,
        note="upstream sigconf-biblatex sample: sigconf with BibLaTeX acmnumeric style "
             "(numeric). The Typst port still uses the bst/CSL bibliography machinery, "
             "so BibLaTeX-specific reference formatting and software artifact entries "
             "are tracked separately by biblatex-test.",
    ),
    "sample-acmcp": Test(
        kind="twin", pages=1, **_SAMPLE_COMMON,
        note="upstream acmcp sample: single-column JDS format, rotated article-type "
             "banner, cover infobox with code/data links and author contributions. "
             "No abstract, CCS, keywords, or bibliography in this variant.",
    ),
    "sample-acmengage": Test(
        kind="twin", pages=3, **_SAMPLE_COMMON,
        note="upstream acmengage sample: two-column ACM EngageCSEdu course-material "
             "format, Synopsis abstract, CC license. Engage metadata "
             "(\\setengagemetadata) is printed before the Synopsis heading.",
    ),
    # Smoke-only docs (no LaTeX twin).
    "siggraph-test": Test(
        kind="smoke", pages=1, _page_parity=False, metrics=False, golden=False,
        note="obsolete public option `siggraph` aliases to sigconf (matching the bundled "
             "LaTeX class). Typst-only alias compile check: it must compile warning-free "
             "down the sigconf path. The rendered proceedings layout is covered by "
             "sigconf-test, so no twin/golden/metrics here.",
    ),
    "sigchi-test": Test(
        kind="smoke", pages=1, _page_parity=False, metrics=False, golden=False,
        note="obsolete public option `sigchi` aliases to sigconf (matching the bundled "
             "LaTeX class). Typst-only alias compile check (see siggraph-test).",
    ),
    "draft-test": Test(
        kind="smoke", pages=1, _page_parity=False, metrics=False, golden=False,
        note="author-draft / timestamp mode. The footer embeds the compile date "
             "(datetime.today), so output is non-deterministic — compile-only (Tier 0): "
             "no golden hash, no geometry gate, no LaTeX twin.",
    ),
    "urlbreak-test": Test(
        kind="smoke", pages=1, _page_parity=False, metrics=False,
        note="`urlbreakonhyphens: false`. Not a twin — LaTeX and Typst pick different URL "
             "break points, so only the Typst output is pinned (golden) to prove the long "
             "hyphenated URL no longer breaks at its hyphens. Deterministic, so golden-hashed.",
    ),
    "feature-test": Test(
        kind="smoke", pages=1, _page_parity=False, metrics=False,
        note="no LaTeX twin: badges/teaser use synthetic shapes. Compiled (warning-free) "
             "and golden-hashed only, to guard the title-note/subtitle-note/teaser/badges "
             "paths that notes-test (text-only) and the sample don't all exercise together.",
    ),
}


# --- Tier 1.6: expected compile-error cases --------------------------------
#
# Each case compiles a tiny acmsmall document with the bad option spliced in and
# asserts the compile fails with a diagnostic containing the expected substring.
# name -> (extra acmart.with(...) argument, expected diagnostic substring)
# name -> (extra acmart.with arg, expected substring[, custom body]).
ERROR_CASES: dict[str, tuple] = {
    "bad-copyright": ('copyright: "definitely-not-a-mode",', "unsupported copyright mode"),
    "bad-cc-type": ('copyright: "cc", cc-type: "by-mystery",', "unsupported Creative Commons type"),
    "bad-cc-version": ('copyright: "cc", cc-version: "2.5",', "unsupported Creative Commons version"),
    "bad-font-size": ('font-size: "13pt",', "font-size"),
    "bad-language": ('language: "klingon",', "unsupported language"),
    "draft-option": ("draft: true,", "option `draft` has no effect"),
    # the "bst" backend errors on an unsupported TeX command rather than passing
    # it through silently, pointing the user at the tex-render callback.
    "bst-unknown-cmd": (
        "",
        "unsupported TeX command",
        '#import "/src/lib.typ": default-tex-render\n'
        '#default-tex-render("a \\\\frobnicate{x} title")',
    ),
}


# --- Copyright / option validation variants --------------------------------
#
# A representative visual suite (NOT exhaustive): for each variant `validate`
# builds a matched LaTeX + Typst page and reports a page-1 mismatch %. The acmart
# package supports every copyright mode; this suite samples the common ones plus
# the document options whose effect shows on page 1.
# name -> (LaTeX class options, LaTeX preamble, Typst acmart.with args)
VARIANTS: dict[str, tuple[str, str, str]] = {
    "acmlicensed":    ("", r"\setcopyright{acmlicensed}",    '  copyright: "acmlicensed",\n'),
    "acmcopyright":   ("", r"\setcopyright{acmcopyright}",   '  copyright: "acmcopyright",\n'),
    "rightsretained": ("", r"\setcopyright{rightsretained}", '  copyright: "rightsretained",\n'),
    "usgov":          ("", r"\setcopyright{usgov}",          '  copyright: "usgov",\n'),
    "usgovmixed":     ("", r"\setcopyright{usgovmixed}",     '  copyright: "usgovmixed",\n'),
    "cc-by-nc-sa":    ("", "\\setcopyright{cc}\n\\setcctype{by-nc-sa}",
                       '  copyright: "cc", cc-type: "by-nc-sa",\n'),
    "screen":    (",screen", r"\setcopyright{acmlicensed}", '  screen: true,\n'),
    "review":    (",review", r"\setcopyright{acmlicensed}", '  review: true,\n'),
    "anonymous": (",anonymous", r"\setcopyright{acmlicensed}", '  anonymous: true,\n'),
    # nonacm drops the journal footer line and, for non-cc copyright, the whole
    # page-1 copyright/permission block (acmart.dtx:6599) — both visible on page 1.
    "nonacm":    (",nonacm", r"\setcopyright{acmlicensed}", '  nonacm: true,\n'),
    # authorversion swaps the page-1 copyright block: no permission text, and the
    # ACM bibstrip becomes the "author's version ... Version of Record" notice
    # naming the full journal + DOI (acmart.dtx:6612/6634).
    "authorversion": (",authorversion", r"\setcopyright{acmlicensed}",
                      '  author-version: true,\n'),
}
