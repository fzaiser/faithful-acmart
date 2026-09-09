from __future__ import annotations

from dataclasses import dataclass

TYPST_VERSION = "0.14.2"
MIN_TYPST_VERSION = "0.14.0"

GOLDEN_DPI = 150

ACTIVE_FORMATS = (
    "manuscript", "acmsmall", "acmlarge", "acmtog", "sigconf",
    "sigplan", "acmengage", "sigchi-a", "acmcp",
)
SWEEP_FONT_SIZES = (8, 9, 10, 11, 12)

METADATA_EXPECTATIONS: dict[str, dict[str, str]] = {
    "title-test": {
        "Title": "The Name of the Title Is Hope",
        "Author": "Ben Trovato, Lars Thørväld, Valerie Béranger",
        "Keywords": "datasets, neural networks, gaze detection, text tagging, "
                    "computational linguistics, human-computer interaction, "
                    "information retrieval, probabilistic graphical models, "
                    "distributed systems, reproducible research",
    },
    "anonymous-test": {
        "Title": "An Anonymous Submission",
        "Author": "Anonymous Author(s)",
        "Keywords": "datasets, anonymity",
    },
    "language-test": {
        "Title": "Une note sur la complexité de calcul",
        "Author": "Jean Dupont",
        "Keywords": "complexité, algorithmes, calcul",
    },
}

# Map fixture names to {metadata field: reason} for cross-engine exemptions.
METADATA_CROSS_EXEMPTIONS: dict[str, dict[str, str]] = {}

# Lengths are PDF points.
# Right margins and line counts are report-only because they depend on line breaking.
METRICS_TOLERANCE = {
    "left": 1.0,
    "top": 4.5,
    "pitch": 0.6,
    "line_pitch": 0.8,
    "width": 0.5,
    "height": 0.5,
}

RULE_THICKNESS_TOL = 0.05
RULE_XMID_TOL = 1.5
RULE_XWIDTH_TOL = 8.0

# Allows measured font-metric drift while catching lost indents and shifted lines.
WORD_POSITION_TOLERANCE = 1.25


@dataclass(frozen=True)
class Assertion:
    """A text assertion on a 1-based page, or the whole document when page is None.

    engine accepts typst, latex, or both; kind accepts contains or absent."""

    text: str
    kind: str = "contains"
    engine: str = "typst"
    page: int | None = None


@dataclass(frozen=True)
class LinkAssertion:
    """An exact hyperlink target expected in, or absent from, the Typst PDF.

    kind accepts present or absent."""

    uri: str
    kind: str = "present"


@dataclass(frozen=True)
class ExtractionArtifact:
    """A mismatch caused by PDF extraction."""

    reason: str


@dataclass(frozen=True)
class AcceptedTypstBehavior:
    """An accepted difference between the layout engines."""

    reason: str


@dataclass(frozen=True)
class TypstBug:
    """A known implementation gap that still needs a fix."""

    reason: str


DiffCause = ExtractionArtifact | AcceptedTypstBehavior | TypstBug
DIFF_CAUSE_TYPES = (ExtractionArtifact, AcceptedTypstBehavior, TypstBug)


@dataclass(frozen=True)
class ExpectedTextDiff:
    """Extracted text fragments that locate and explain a known mismatch."""

    latex: str
    typst: str
    cause: DiffCause
    page: int | None = None


@dataclass(frozen=True)
class ExpectedFontDiff:
    """Fragments identifying a font mismatch; the text itself may be identical."""

    latex: str
    typst: str
    cause: DiffCause
    page: int | None = None


@dataclass(frozen=True)
class ExpectedOrderDiff:
    """Fragments showing the differing extraction orders."""

    latex: str
    typst: str
    cause: DiffCause
    page: int | None = None


@dataclass(frozen=True)
class ResidualSignatures:
    """Hashes restrict exemptions to the measured differences explained by Expected*Diff entries."""

    text: str = ""
    font: str = ""
    order: str = ""


EXPECTED_RESIDUALS: dict[str, ResidualSignatures] = {
    "biblatex-names-test": ResidualSignatures(text="0fea833515e40ab0da35e185f5f9263e736bed8a0f21cdaa3305b94b9c97b1c8"),
    "head-test": ResidualSignatures(text="e61c9d8eb269cb52ade4868fba91b818e0f3f792f0902c8e95e2454a72551a75", font="2671b03db39c20ed5865d5f0284006c62af694b45b74bbd62e229b0cf97bbc6b"),
    "acmcp-test": ResidualSignatures(text="1391876e63685b7da0e6a923dc6c4c106590930a70cdf4665088614cae243c44"),
    "manuscript-pages-test": ResidualSignatures(text="13857b6c3436762b1c09a161ad0ba212a0fc064b6c149ce01b1dc4ec95b82cfd"),
    "mathfields": ResidualSignatures(font="33b5c052b30812736e907581e38b04c1be363ec608e59cd34c8a13ce193f5170"),
    "sample-acmsmall": ResidualSignatures(text="1391876e63685b7da0e6a923dc6c4c106590930a70cdf4665088614cae243c44", font="2a99fb5013b2bc11b626ce12e789074262b58076a2442236122e2b019da27af6", order="63571ea7fe48d9b439a405c7ab3b1bb383ec9e93d839d63c4816959c5db469bf"),
    "sample-manuscript": ResidualSignatures(text="1391876e63685b7da0e6a923dc6c4c106590930a70cdf4665088614cae243c44", font="537e9d72b7c5f85e28de58a03185fa0889def171e13399aa64c85ad5a752e88d", order="e35efb9f0fc720f589914f355ead6d5f4bf9923e8fdf8c24afa14bd20788d0f1"),
    "sample-acmlarge": ResidualSignatures(text="1391876e63685b7da0e6a923dc6c4c106590930a70cdf4665088614cae243c44", font="fed7b8e33a9c7a089f485b53b3e0f99b744b14cdd85ea18802f73b03fc8f0afe", order="367f4243c72b390a5969a6cddf713e2a9849004ae4d886298a7ef0812c4e8618"),
    "sample-sigconf": ResidualSignatures(text="1391876e63685b7da0e6a923dc6c4c106590930a70cdf4665088614cae243c44", font="92bbdb41398c3aa3d90f153873c4cb4cfdb2f6c43d5ecc1aaa6a7fd3f52a4e3c", order="eeb78fc9d2b4fff09d6029ef656d9f0c9c0ac12f1d6f3f3c6a754a06e628173c"),
    "sample-sigplan": ResidualSignatures(text="1391876e63685b7da0e6a923dc6c4c106590930a70cdf4665088614cae243c44", font="6ca344d1a37f477b4325c00120a1833d8f823d4659885c990acaf57ad0029e6b", order="eeb78fc9d2b4fff09d6029ef656d9f0c9c0ac12f1d6f3f3c6a754a06e628173c"),
    "sample-acmsmall-submission": ResidualSignatures(text="1391876e63685b7da0e6a923dc6c4c106590930a70cdf4665088614cae243c44", font="fed7b8e33a9c7a089f485b53b3e0f99b744b14cdd85ea18802f73b03fc8f0afe", order="eeb78fc9d2b4fff09d6029ef656d9f0c9c0ac12f1d6f3f3c6a754a06e628173c"),
    "sample-acmsmall-conf": ResidualSignatures(text="1391876e63685b7da0e6a923dc6c4c106590930a70cdf4665088614cae243c44", font="2a99fb5013b2bc11b626ce12e789074262b58076a2442236122e2b019da27af6", order="eeb78fc9d2b4fff09d6029ef656d9f0c9c0ac12f1d6f3f3c6a754a06e628173c"),
    "sample-acmtog": ResidualSignatures(text="1391876e63685b7da0e6a923dc6c4c106590930a70cdf4665088614cae243c44", font="5d42788d3f875717598b73c7e3270a1b5fd3486a5db609f46f4972bdfd1c1173", order="eeb78fc9d2b4fff09d6029ef656d9f0c9c0ac12f1d6f3f3c6a754a06e628173c"),
    "sample-acmtog-conf": ResidualSignatures(text="1391876e63685b7da0e6a923dc6c4c106590930a70cdf4665088614cae243c44", font="5d42788d3f875717598b73c7e3270a1b5fd3486a5db609f46f4972bdfd1c1173", order="eeb78fc9d2b4fff09d6029ef656d9f0c9c0ac12f1d6f3f3c6a754a06e628173c"),
    "sample-sigconf-i13n": ResidualSignatures(text="1391876e63685b7da0e6a923dc6c4c106590930a70cdf4665088614cae243c44", font="eba33dbf91c27c83138f0c73451d58a94d20ebf49ee920b7f4fbef1235e196c2", order="7670c039210868e04d5111c1c53fb3399558e09f012b1796727a07961be107fe"),
    "sample-sigconf-authordraft": ResidualSignatures(text="57a4481083f7716ddac8aa384c515bbb498a2281fce9d957465ad5347493f50d", font="92bbdb41398c3aa3d90f153873c4cb4cfdb2f6c43d5ecc1aaa6a7fd3f52a4e3c", order="eeb78fc9d2b4fff09d6029ef656d9f0c9c0ac12f1d6f3f3c6a754a06e628173c"),
    "sample-acmsmall-biblatex": ResidualSignatures(text="1391876e63685b7da0e6a923dc6c4c106590930a70cdf4665088614cae243c44", font="b80c937cac61c01d3dd391eddbda58dab0351b6d3e551164c90065076264f7e5", order="7b3f516263dd09f3a6d35956cb444a6766bade5d771d04c441c57f4a1e012b01"),
    "sample-sigconf-biblatex": ResidualSignatures(text="1391876e63685b7da0e6a923dc6c4c106590930a70cdf4665088614cae243c44", font="d7751f8c9188430c0e74dbcfeff722206b3ca1a1fa8d59730663d01e12bcde45", order="a7f323c7a7739f484386e5da419133bcce258e6578a0f7007d4ff95239b07b9d"),
    "sample-acmcp": ResidualSignatures(text="a9a95ef15c40d9c28beacacdc681edc7c834fcae0aba217e4764495993a5ac9e"),
    "authoryear": ResidualSignatures(text="96e3b378cf8c5ff278d12ecbd1c0d5493b7700768a2fe4d380c0b98bcc8870b9", font="604e5aedfa00fd6a5f2bb7e6e0022ecf19ecd9f664ef32ec60beff88f0a76ca8"),
    "sample-acmengage": ResidualSignatures(order="e1375d589c6da53376f20ce6acd938b50f3b317e20333dd6ab48744b32034f58"),
}


@dataclass(frozen=True)
class ExpectedLinkDiff:

    reason: str
    missing: tuple[str, ...] = ()
    extra: tuple[str, ...] = ()


@dataclass(frozen=True)
class ExpectedDashDiff:

    reason: str
    latex_only: int = 0
    typst_only: int = 0


_LINK_MULTIPLICITY = "exact annotation-multiplicity difference in the integration fixture"
EXPECTED_LINK_DIFFS: dict[str, ExpectedLinkDiff] = {
    "manuscript-pages-test": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, extra=("https://doi.org/XXXXXXX.XXXXXXX",)),
    "acmlarge-test": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, extra=("https://doi.org/XXXXXXX.XXXXXXX",)),
    "acmcp-test": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, extra=("https://example.com/data",)),
    "sample-acmsmall": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://orcid.org/0000-0002-1825-0037",)),
    "sample-manuscript": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://doi.org/10.1145/1188913.1188915", "https://doi.org/10.1145/1057270.1057278"), extra=("https://www.acm.org/publications/taps/describing-figures/",)),
    "sample-acmlarge": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://doi.org/10.1007/3-540-09237-4", "https://doi.org/10.1145/1057270.1057278"), extra=("https://orcid.org/0000-0002-1825-1297", "http://ccrma.stanford.edu/~jos/bayes/bayes.html")),
    "sample-sigconf": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://doi.org/10.1007/3-540-65193-4_29",), extra=("https://doi.org/XXXXXXX.XXXXXXX", "https://dl.acm.org/ccs/ccs.cfm")),
    "sample-sigplan": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://www.acm.org/publications/proceedings-template", "https://doi.org/10.1145/1057270.1057278"), extra=("https://doi.org/10.48550/arXiv.1403.1349", "https://doi.org/10.1145/1219092.1219093", "https://doi.org/10.1007/3-540-65193-4_29", "https://doi.org/10.1007/3-540-09237-4", "https://doi.org/10.1137/080734467", "https://doi.org/10.945/woot07-S422", "https://doi.org/10.1145/90417.90738")),
    "language-de-sigplan-test": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, extra=("https://doi.org/10.1145/1219092.1219093",)),
    "sample-acmtog": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://orcid.org/0000-0002-3225-0097", "https://doi.org/10.1145/1219092.1219093", "https://doi.org/10.1137/080734467")),
    "sample-acmtog-conf": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://orcid.org/0000-0002-3225-0097", "https://doi.org/10.1145/1219092.1219093", "https://doi.org/10.1137/080734467")),
    "sample-sigconf-i13n": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://doi.org/10.1007/3-540-65193-4_29",), extra=("https://doi.org/XXXXXXX.XXXXXXX", "https://dl.acm.org/ccs/ccs.cfm")),
    "sample-sigconf-authordraft": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://doi.org/10.1007/3-540-65193-4_29",), extra=("https://doi.org/XXXXXXX.XXXXXXX", "https://dl.acm.org/ccs/ccs.cfm")),
    "sample-acmsmall-biblatex": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://orcid.org/0000-0002-1825-0037", "https://doi.org/10.1145/1057270.1057278"), extra=("https://github.com/nuprl/tag-sound", "http://archive.softwareheritage.org/swh:1:dir:cd0b0abeee707e57cd699e2e2ebd075da8ebf1f7;origin=https://github.com/nuprl/tag-sound;visit=swh:1:snp:7967bc0abee8bf3bfffb9252207a07b73538525a;anchor=swh:1:rev:4cc09ca228947a99c8f4ac45eefb76e96ee96e53")),
    "sample-sigconf-biblatex": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://doi.org/10.1145/1188913.1188915", "https://hal.archives-ouvertes.fr/hal-02090402v1", "https://doi.org/10.1007/3-540-65193-4_29"), extra=("https://doi.org/XXXXXXX.XXXXXXX", "https://dl.acm.org/ccs/ccs.cfm", "https://github.com/scilab/scilab", "http://archive.softwareheritage.org/swh:1:cnt:43a6b232768017b03da934ba22d9cc3f2726a6c5;origin=https://github.com/rdicosmo/parmap;visit=swh:1:snp:2a6c348c53eb77d458f24c9cbcecaf92e3c45615;anchor=swh:1:rel:373e2604d96de4ab1d505190b654c5c4045db773;path=/src/parmap.ml;lines=192-228", "https://github.com/nuprl/tag-sound", "http://archive.softwareheritage.org/swh:1:dir:cd0b0abeee707e57cd699e2e2ebd075da8ebf1f7;origin=https://github.com/nuprl/tag-sound;visit=swh:1:snp:7967bc0abee8bf3bfffb9252207a07b73538525a;anchor=swh:1:rev:4cc09ca228947a99c8f4ac45eefb76e96ee96e53", "http://archive.softwareheritage.org/swh:1:rel:636541bbf6c77863908eae744610a3d91fa58855;origin=https://github.com/CGAL/cgal/", "http://video.google.com/videoplay?docid=6528042696351994555")),
    "sample-acmcp": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://orcid.org/0000-0002-1825-0197",), extra=("https://orcid.org/1234-5678-9012", "https://orcid.org/0000-2034-1825-0097", "https://orcid.org/0000-0002-1825-1297")),
    "sample-acmengage": ExpectedLinkDiff(reason=_LINK_MULTIPLICITY, missing=("https://www.engage-csedu.org/ontology", "https://doi.org/10.1145/1188913.1188915", "http://ccrma.stanford.edu/~jos/bayes/bayes.html"), extra=("https://doi.org/XXXXXXX.XXXXXXX", "https://creativecommons.org/licenses/by/4.0")),
}

@dataclass(frozen=True)
class ExpectedOutlineDiff:
    """Accepted (title, LaTeX page, Typst page) moves for bookmarks anchored on page 1."""

    reason: str
    moved: tuple[tuple[str, int, int], ...]


EXPECTED_OUTLINE_DIFFS: dict[str, ExpectedOutlineDiff] = {
    "sample-sigplan": ExpectedOutlineDiff(
        "microtype: pdfTeX's font expansion keeps \"Institute for Clarity in "
        "Documentation\" on one line of the author grid, and without it the "
        "affiliation wraps, the teaser figure and everything under it drop ~12pt, "
        "column 1 hands an abstract line to column 2, and the heading no longer fits "
        "on page 1. Rebuilding the reference with "
        "\\microtypesetup{expansion=false,protrusion=false} reproduces our author-grid "
        "wrap, our column split and our page-2 bookmark (DESIGN.md \"No microtype\")",
        moved=(("1 Introduction", 1, 2),),
    ),
}

_DASH_EXTRACTION = "exact normalized dash residual caused by cross-engine extraction/reflow"
EXPECTED_DASH_DIFFS: dict[str, ExpectedDashDiff] = {
    "figure-heading-test": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=1),
    "list-test": ExpectedDashDiff(_DASH_EXTRACTION, latex_only=1),
    "acmtog-test": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=2),
    "acmcp-test": ExpectedDashDiff(_DASH_EXTRACTION, latex_only=1),
    "biblatex-edge": ExpectedDashDiff(_DASH_EXTRACTION, latex_only=1),
    "notes-test": ExpectedDashDiff(_DASH_EXTRACTION, latex_only=1),
    "options-test": ExpectedDashDiff(_DASH_EXTRACTION, latex_only=2),
    "fontsize-sigconf-11-test": ExpectedDashDiff(_DASH_EXTRACTION, latex_only=1),
    "sample-acmsmall": ExpectedDashDiff(_DASH_EXTRACTION, latex_only=1),
    "sample-manuscript": ExpectedDashDiff(_DASH_EXTRACTION, latex_only=3),
    "sample-acmlarge": ExpectedDashDiff(_DASH_EXTRACTION, latex_only=2),
    "sample-sigconf": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=1),
    "sample-acmtog": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=1),
    "sample-acmtog-conf": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=1),
    "sample-acmsmall-submission": ExpectedDashDiff(_DASH_EXTRACTION, latex_only=1),
    "sample-acmsmall-conf": ExpectedDashDiff(_DASH_EXTRACTION, latex_only=1),
    "sample-sigconf-i13n": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=2),
    "sample-sigconf-authordraft": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=1),
    "sample-acmsmall-biblatex": ExpectedDashDiff(_DASH_EXTRACTION, latex_only=2),
    "sample-sigconf-biblatex": ExpectedDashDiff(_DASH_EXTRACTION, latex_only=3),
    "sample-acmcp": ExpectedDashDiff(_DASH_EXTRACTION, typst_only=1),
}


# Fixture pairs whose rendered pages must be identical.
GOLDEN_EQUIVALENT_PAIRS: tuple[tuple[str, str, str], ...] = (
    ("fix-quirks-doc-default-test", "fix-quirks-doc-off-test",
     "omitting fix-quirks must render exactly like passing it as false"),
)


@dataclass(frozen=True)
class MetricAllowance:
    """An expected metric difference with a maximum permitted delta."""

    page: int
    key: str
    max_delta: float


EXPECTED_METRIC_DIFFS: dict[str, tuple[MetricAllowance, ...]] = {
    "sigchi-a-test": (MetricAllowance(1, "left", 6.25),),
    "sample-acmsmall": (MetricAllowance(8, "left", 1.25),),
    "sample-acmsmall-conf": (MetricAllowance(8, "left", 1.25),),
    "sample-acmtog": (MetricAllowance(2, "left", 1.25),),
    "sample-sigconf-i13n": (MetricAllowance(3, "left", 1.25),),
    "sample-acmsmall-biblatex": (MetricAllowance(8, "left", 1.25),),
}


@dataclass(frozen=True)
class Test:
    """A document fixture and its gate configuration.

    kind is twin for a LaTeX/Typst pair or smoke for a Typst-only document.
    text_equal selects normalized sequence equality (True), word-bag equality ("bag"), an explained exemption (False), or no selection (None).
    Character, dash, font, link, and reading-order comparisons also run independently.

    Expected differences require a cause, supporting fragments or counts, and a bounded residual.
    They must fail if the difference disappears or exceeds its allowance.
    metrics_uniform_pitch and metrics_page1_only carry reasons for restricting layout comparisons.
    golden_exempt explains why a document cannot use raster goldens; note is descriptive only."""

    kind: str
    pages: int
    expected_page_count_diff: str = ""
    expected_metrics_diff: str = ""
    golden_exempt: str = ""
    metrics_page1_only: str = ""
    metrics_uniform_pitch: str = ""
    word_positions: str = ""
    rule_gate: str = ""
    text_equal: bool | str | None = None
    expected_text_diffs: tuple[ExpectedTextDiff, ...] = ()
    text_assertions: tuple[Assertion, ...] = ()
    link_assertions: tuple[LinkAssertion, ...] = ()
    expected_font_diffs: tuple[ExpectedFontDiff, ...] = ()
    expected_order_diffs: tuple[ExpectedOrderDiff, ...] = ()
    min_internal_links: int = 0
    min_internal_destinations: int = 0
    review_line_numbers: bool = False
    note: str = ""

    def __post_init__(self) -> None:
        if self.kind not in ("twin", "smoke"):
            raise ValueError(f"unknown test kind {self.kind!r}")
        if self.text_equal not in (None, True, False, "bag"):
            raise ValueError(f"unknown text_equal value {self.text_equal!r}")
        if self.metrics_page1_only and self.pages <= 1:
            raise ValueError("metrics_page1_only is only meaningful for multi-page tests")
        if self.metrics_page1_only and self.kind != "twin":
            raise ValueError("metrics_page1_only only applies to twin tests")
        if self.metrics_uniform_pitch and self.kind != "twin":
            raise ValueError("metrics_uniform_pitch only applies to twin tests")
        if self.word_positions and self.kind != "twin":
            raise ValueError("word_positions only applies to twin tests")
        if self.rule_gate and self.kind != "twin":
            raise ValueError("rule_gate only applies to twin tests")
        if self.min_internal_links < 0 or self.min_internal_destinations < 0:
            raise ValueError("minimum internal-link counts cannot be negative")
        if self.review_line_numbers and self.kind != "twin":
            raise ValueError("review_line_numbers only applies to twin tests")
        for a in self.link_assertions:
            if a.kind not in ("present", "absent"):
                raise ValueError(f"unknown link assertion kind {a.kind!r}")
        if self.kind != "twin" and any(a.engine != "typst" for a in self.text_assertions):
            raise ValueError("a smoke test has no LaTeX reference, so its text "
                             "assertions must use engine=\"typst\"")

    @property
    def subdir(self) -> str:
        return "twins" if self.kind == "twin" else "typst-only"


_FULL_SAMPLE_FONT_EVIDENCE = (
    ExpectedFontDiff(
        latex="A formula that appears in the running text",
        typst="A formula that appears in the running text",
        cause=AcceptedTypstBehavior(
            "Full samples include math/reference/sidebar font cases covered by focused twins."
        ),
    ),
)

# PDF extraction can fuse the CCS arrow with the following word when it loses the intervening space.
_CCS_ARROW_TEXT_EVIDENCE = (
    ExpectedTextDiff(
        latex="Do Not Use This Code →Generate the Correct Terms",
        typst="Do Not Use This Code → Generate the Correct Terms",
        cause=ExtractionArtifact(
            "the space after the CCS arrow is absorbed into its math box in "
            "LaTeX's extracted stream"),
    ),
)

_STACKED_SCRIPT_TEXT_EVIDENCE = (
    ExpectedTextDiff(
        latex="Used in business Ψ2 1 1 in 40,000 Unexplained usage",
        typst="Used in business Ψ21 1 in 40,000 Unexplained usage",
        cause=ExtractionArtifact(
            "the stacked scripts of the Ψ²₁ table cell: PyMuPDF reads LaTeX's "
            "superscript and subscript as two runs separated by a gap, Typst's as one"),
    ),
)

_LANDSCAPE_METRICS_DIFF = (
    "Landscape extended-abstract geometry is covered by page parity, text, links, "
    "and goldens instead of the generic portrait metric gate."
)
_FULL_SAMPLE_METRICS_DIFF = (
    "Full upstream samples include page-fill, column-flow, and float-placement "
    "drift; focused twins own exact geometry."
)
_PAGE1_METRICS_SCOPE = (
    "Only page 1 has stable absolute metrics; later pages include LaTeX page-fill/"
    "column-flow drift not mirrored by Typst."
)
_UNIFORM_PITCH_METRICS = (
    "Fixture is designed around a single baseline grid, so baseline pitch is gated."
)
_FONT_SIZE_PITCH_METRICS = (
    "Fixture isolates base font-size changes while keeping a single baseline grid, "
    "so pitch is gated."
)
_WORD_POSITIONS = (
    "Both engines break this fixture into the same lines, so per-word x/y positions "
    "align one-to-one and pin absolute placement (indent, centering, spacing)."
)
_RULE_BOOKTABS = "booktabs \\toprule/\\midrule/\\bottomrule weights and extent."
_RULE_FOOTNOTE = "footnote rule weight and extent."
_RULE_ACMCP_FOOT = "acmcp cover foot rule weight, colour, and extent."
_RULE_REVIEW_SAMPLE = (
    "review-mode sample: its tables and foot rule are drawn identically across "
    "engines (the line-number margin ticks are not horizontal rules)."
)
_ALIAS_GOLDEN_EXEMPT = (
    "Compile-only alias smoke; sigconf-test owns the rendered layout golden."
)

TESTS: dict[str, Test] = {
    # Word positions are unsuitable here because line breaks differ across engines.
    "body-test": Test(
        kind="twin", pages=1, metrics_uniform_pitch=_UNIFORM_PITCH_METRICS,
        text_equal=True,
        note="body typography: font, size, baseline grid, justification, indent",
    ),
    "head-test": Test(
        kind="twin", pages=1, metrics_uniform_pitch=_UNIFORM_PITCH_METRICS,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="A Part Division A Part Division This run-in part heading",
                typst="A Part Division This run-in part heading",
                cause=AcceptedTypstBehavior(
                    "acmart typesets a \\part title TWICE: \\ACM@NRadjust re-runs the "
                    "level-9 section format through hyperref's \\Sectionformat hook "
                    "(acmart.dtx:8353/8430), an upstream display-heading quirk (confirmed "
                    "on a minimal acmart doc). The port renders the \\part title once."),
            ),
        ),
        expected_font_diffs=(
            ExpectedFontDiff(
                latex="A Part Division A Part Division",
                typst="A Part Division",
                cause=AcceptedTypstBehavior(
                    "One extra copy of the \\part heading glyphs is present in LaTeX only "
                    "(the acmart.dtx:8353 double-typesetting quirk)."),
            ),
        ),
        note="section / subsection / subsubsection / paragraph (run-in) headings, plus "
             "\\part (a level-9 display heading acmart renders twice; see the diffs). "
             "Two subsubsections end in a period — one after math, one after an uppercase "
             "letter — which is where \\@adddotafter's space-factor test diverges.",
    ),
    "figure-heading-test": Test(
        kind="twin", pages=1,
        note="figures immediately followed by display/run-in/paragraph headings; "
             "guards the post-figure paragraph-indent shim from leaking into headings.",
    ),
    "body2-test": Test(
        kind="twin", pages=1, rule_gate=_RULE_BOOKTABS,
        note="figure & table captions, theorems (plain/definition/proof+QED), lists",
    ),
    # The theorem baseline residual exceeds the word-position tolerance.
    "theorem-transition-test": Test(
        kind="twin", pages=1, text_equal=True,
        note="theorem numbering survives section-star/acks; add-punct honors ,;:",
    ),
    "list-test": Test(
        kind="twin", pages=1,
        note="isolated itemize/enumerate/quote geometry under NONACM — the class's "
             "option-time-hook bug reverts the list dimensions to amsart's "
             "(labelsep 5pt, settowidth margins); list-plain-test covers the "
             "plain-document side.",
    ),
    "list-plain-test": Test(
        kind="twin", pages=1,
        note="the same list fixture WITHOUT review/nonacm: acmart's own dimensions "
             "apply (labelsep 4pt, leftmargini 24.5pt, nested 8.5pt).",
    ),
    "fn-test": Test(
        kind="twin", pages=1, word_positions=_WORD_POSITIONS, rule_gate=_RULE_FOOTNOTE,
        note="body footnotes + code/verbatim",
    ),
    "full-test": Test(
        kind="twin", pages=2, metrics_page1_only=_PAGE1_METRICS_SCOPE,
        metrics_uniform_pitch=_UNIFORM_PITCH_METRICS,
        note="multi-page cumulative spacing (reveals the \\flushbottom difference)",
    ),
    "title-test": Test(
        kind="twin", pages=1,
        note="frontmatter in isolation: title block, author fields, abstract, CCS, keywords",
    ),
    "ccs-xml-test": Test(
        kind="twin", pages=1,
        note="CCS concepts pasted as the ACM CCS tool's <ccs2012> XML; the LaTeX twin "
             "typesets the equivalent \\ccsdesc lines (interleaved repeated area, "
             "500/300/default-100 styling, area-only repeat ending the list in ';')",
    ),
    "ccs-forms-test": Test(
        kind="smoke", pages=1,
        note="a document rendered from the ACM tool's paste in a raw block; the "
             "\\ccsdesc-over-XML precedence shows as the bold specific in the golden "
             "(parse-ccs asserts: tests/unit/frontmatter.typ; rejections: ERROR_CASES)",
    ),
    "title-wrap-test": Test(
        kind="twin", pages=1,
        note="two-line acmsmall title: wrapped title lines keep the title baselineskip "
             "(cap-height top edge needs bls - cap-height leading)",
    ),
    "title-wrap-sigplan-test": Test(
        kind="twin", pages=1,
        note="two-line sigplan \\Huge serif-bold title: the largest title font, where a "
             "leading error shows as descender/capital collisions",
    ),
    "manuscript-test": Test(
        kind="twin", pages=1,
        note="format=manuscript: single-column draft geometry (letterpaper, 9pt default) "
             "with the generic sans-bold section fonts shared with acmsmall.",
    ),
    "manuscript-pages-test": Test(
        kind="twin", pages=2, metrics_page1_only=_PAGE1_METRICS_SCOPE,
        text_equal=False,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="2026-07-01 12:00. Page 2 of 1",
                typst="2026-07-01. Page 2 of 1",
                cause=AcceptedTypstBehavior(
                    "Typst has no wall-clock access, so the timestamp footer prints the "
                    "compile date without the HH:MM time (DESIGN.md)."),
                page=2,
            ),
        ),
        text_assertions=(
            Assertion(engine="both", page=2, text="Lovelace and Hopper"),
            Assertion(engine="both", page=2, text="Manuscript submitted to ACM"),
        ),
        note="Continuation-page header/footer + multi-page body with timestamp mode. "
             "Body flow reorders across engines; the timestamp time is Typst-omitted.",
    ),
    "acmlarge-test": Test(
        kind="twin", pages=1,
        note="format=acmlarge: large single-column journal geometry (10pt) with the "
             "\\sffamily\\large (regular-weight) section headings (acmart.dtx:8424).",
    ),
    "acmlarge-pages-test": Test(
        kind="twin", pages=2, metrics_page1_only=_PAGE1_METRICS_SCOPE,
        text_equal="bag",
        text_assertions=(
            Assertion(engine="both", page=2, text="Lovelace and Hopper"),
            Assertion(engine="both", page=2, text="111:2"),
            Assertion(engine="both", page=2, text="J. ACM, Vol. 37, No. 4, Article 111"),
        ),
        note="acmlarge continuation page header/footer; body reorders, so text is "
             "gated order-independently (word-bag).",
    ),
    "acmtog-test": Test(
        kind="twin", pages=1,
        note="format=acmtog: two-column JOURNAL. Spanning left @i title + author list, "
             "contact-info footnote + ACM bibstrip + journal footer, 9pt parindent, "
             "sans-large sections.",
    ),
    "acmtog-pages-test": Test(
        kind="twin", pages=2, metrics_page1_only=_PAGE1_METRICS_SCOPE,
        text_equal="bag",
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
        kind="twin", pages=1, text_equal="bag",
        text_assertions=(
            Assertion(engine="both", text="Abstract"),
            Assertion(engine="both", text="Keywords"),
            Assertion(engine="both", text="In Proceedings of ACM Conference"),
            Assertion(engine="both", text="ACM, New York, NY, USA"),
            Assertion(engine="both", kind="absent", text="Additional Key Words and Phrases"),
            Assertion(engine="typst", kind="absent", text="Journal of the ACM"),
        ),
        note="format=sigconf: two-column proceedings title page; text is word-bag gated.",
    ),
    "sigconf-pages-test": Test(
        kind="twin", pages=2, metrics_page1_only=_PAGE1_METRICS_SCOPE,
        text_equal="bag",
        text_assertions=(
            Assertion(engine="both", page=2, text="Lovelace and Hopper"),
            Assertion(engine="both", page=2,
                      text="Conference'17, June 2018, Washington, DC, USA"),
        ),
        note="sigconf two-column continuation page; column order differs under "
             "extraction, so text is gated order-independently (word-bag).",
    ),
    "sigconf-authors-test": Test(
        kind="twin", pages=1,
        note="Conference author grid with a centered partial final row (auto 3-per-row).",
    ),
    "sigconf-authors-per-row-test": Test(
        kind="twin", pages=1,
        note="Conference author grid with an EXPLICIT authorsperrow=2 (5 authors => "
             "2 + 2 + 1); sibling of sigconf-authors-test's default auto layout.",
    ),
    "sigplan-test": Test(
        kind="twin", pages=2, metrics_page1_only=_PAGE1_METRICS_SCOPE, text_equal="bag",
        note="format=sigplan: 10pt proceedings variant + the sigplan style overrides "
             "(1./a. enum labels, bold zero-indent theorem heads with upright notes, "
             "italic noindent proof, bold-label captions). Metrics are report-only for "
             "title bbox drift; two-column flow reorders, so text is word-bag gated.",
    ),
    "acmengage-test": Test(
        kind="twin", pages=1,
        note="format=acmengage: 10pt sigconf variant with Engage copyright metadata.",
    ),
    "acmcp-test": Test(
        kind="twin", pages=1, text_equal=False,
        rule_gate=_RULE_ACMCP_FOOT,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="Code and data links: https://example.com/data Keywords: datasets",
                typst="Code and data links: https://example.com/ data Keywords: datasets",
                cause=ExtractionArtifact("cover-infobox URL extraction"),
            ),
        ),
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
                      text="ACM Reference Format"),
            Assertion(engine="typst", kind="absent",
                      text="Additional Key Words and Phrases"),
        ),
        note="format=acmcp: JDS cover page, infobox, unnumbered sections, and author contributions.",
    ),
    "sigchi-a-test": Test(
        kind="twin", pages=3, metrics_page1_only=_PAGE1_METRICS_SCOPE,
        expected_metrics_diff=_LANDSCAPE_METRICS_DIFF, text_equal="bag",
        note="format=sigchi-a: landscape extended abstract with a bold-small captioned "
             "figure; text bags and page parity are gated.",
    ),
    "startpage-test": Test(
        kind="twin", pages=2, metrics_page1_only=_PAGE1_METRICS_SCOPE,
        text_equal="bag",
        text_assertions=(
            Assertion(engine="both", page=2, text="111:8"),
            Assertion(engine="both", page=2, text="Lovelace and Hopper"),
        ),
        note="\\startPage seeds the page counter: folios, running-head parity, and "
             "the journal footer follow the counter (acmart.dtx:6822-6825). Body "
             "reorders, so text is word-bag gated.",
    ),
    "fontsize-9-pages-test": Test(
        kind="twin", pages=2, metrics_page1_only=_PAGE1_METRICS_SCOPE,
        text_equal="bag",
        text_assertions=(
            Assertion(engine="both", page=2, text="111:2"),
            Assertion(engine="both", page=2, text="Lovelace"),
        ),
        note="multi-page acmsmall at the NON-DEFAULT 9pt base: heightrounded "
             "geometry (571pt), rescaled ladder, page parity, continuation "
             "head/folio. Body reorders, so text is word-bag gated.",
    ),
    "fontsize-8-test": Test(
        kind="twin", pages=1, metrics_uniform_pitch=_FONT_SIZE_PITCH_METRICS,
        word_positions=_WORD_POSITIONS, text_equal=True,
        note="Base font-size option `8pt`: amsart \\@typesizes ladder + "
             "baselineskip-derived heading/skip scaling. Body is on one grid, so pitch is gated.",
    ),
    "fontsize-9-test": Test(
        kind="twin", pages=1, metrics_uniform_pitch=_FONT_SIZE_PITCH_METRICS,
        word_positions=_WORD_POSITIONS, text_equal=True,
        note="Base font-size option `9pt`.",
    ),
    # The logo can wrap to a different line, preventing word-position comparison.
    "fontsize-11-test": Test(
        kind="twin", pages=1, metrics_uniform_pitch=_FONT_SIZE_PITCH_METRICS,
        text_equal=True,
        note="Base font-size option `11pt`.",
    ),
    "fontsize-12-test": Test(
        kind="twin", pages=1, metrics_uniform_pitch=_FONT_SIZE_PITCH_METRICS,
        word_positions=_WORD_POSITIONS, text_equal=True,
        note="Base font-size option `12pt`.",
    ),
    "fontsize-sigconf-11-test": Test(
        kind="twin", pages=1, text_equal="bag",
        note="sigconf (two-column proceedings) at the NON-DEFAULT 11pt base: the "
             "proceedings heading ladder is a distinct scaling axis from the "
             "single-column acmsmall fontsize twins. Two-column extraction reorders, "
             "so text is word-bag gated.",
    ),
    "longtable-test": Test(
        kind="twin", pages=2, metrics_page1_only=_PAGE1_METRICS_SCOPE,
        text_equal=True, rule_gate=_RULE_BOOKTABS,
        note="A booktabs `tabular` too tall for the page-1 remainder: LaTeX moves the "
             "single unbreakable box whole to page 2, and parts/tables.typ pins Typst's "
             "`tabular` non-breakable to match (both keep all rows on page 2).",
    ),
    "bib-test": Test(
        kind="smoke", pages=1,
        text_assertions=(
            Assertion(engine="typst", text="References"),
            Assertion(engine="typst", text="Ablamowicz"),
        ),
        note="Typst-only smoke for the opt-in \"typst\" (native CSL) bibliography backend: "
             "confirms it compiles and renders a reference list via Typst's built-in ACM CSL "
             "style. Not a faithfulness twin — \"typst\" is a documented approximation of "
             "LaTeX; the faithful default \"bibtex\" backend is validated by keycite / crossref "
             "/ bib-all / sample-* twins.",
    ),
    "review-ruler-test": Test(
        kind="smoke", pages=1,
        text_assertions=(
            Assertion(engine="typst", text="Body"),
            # This number can only come from the review ruler.
            Assertion(engine="typst", text="37", kind="absent"),
        ),
        note="review ruler follows the running head: suppressing the head takes the "
             "ruler with it, as \\pagestyle{empty} does in acmart (it hangs off "
             "\\fancyhead[LO], acmart.dtx:8107). review-ruler-on-test is the control.",
    ),
    "review-ruler-on-test": Test(
        kind="smoke", pages=1,
        text_assertions=(
            Assertion(engine="typst", text="Body"),
            Assertion(engine="typst", text="37"),
        ),
        note="control for review-ruler-test: the same document with its running head "
             "left in place still draws the ruler.",
    ),
    "bib-cite-links": Test(
        kind="smoke", pages=1,
        text_assertions=(
            Assertion(engine="typst", text="References"),
            Assertion(engine="typst", text="[1]"),
            Assertion(engine="typst", text="[8]"),
        ),
        min_internal_links=8,
        min_internal_destinations=8,
        note="Regression for the `bibtex` cite-path convergence edge (many `@key`s incl. "
             "dotted keys in one sentence used to crash with `read(none)`), and for the "
             "in-text cite -> reference-list hyperlinks. Golden-pins the linked numbers.",
    ),
    "biblatex-test": Test(
        kind="twin", pages=1,
        text_assertions=(
            Assertion(engine="latex", text="Communications of the ACM"),
            Assertion(engine="typst", text="References"),
        ),
        note="small BibLaTeX acmnumeric isolator so the full sample-sigconf-biblatex "
             "reference-format path is checked without the full upstream sample body.",
    ),
    "biblatex-edge": Test(
        kind="twin", pages=1,
        text_assertions=(
            Assertion(engine="both", text="Lecture Notes in Computer Science. Vol. 1494. "
                      "Ed. by Grzegorz Rozenberg and Frits W. Vaandrager"),
            Assertion(engine="both", text="Ed. by Ian Editor. \"The title of book one. "
                      "The book subtitle.\" (1st. ed.). Vol. 9."),
            Assertion(engine="both", text="Dave Novak. Mar. 2003. \"Solder man.\""),
            Assertion(engine="both", text="Barack Obama. Mar. 2008. A more perfect union. "
                      "Video. (Mar. 2008)."),
            Assertion(engine="both", text="isbn: 3-540-13829-3"),
            Assertion(engine="both", text="Institutional members of the TEX Users Group. "
                      "Retrieved May 27, 2017"),
        ),
        note="BibLaTeX author-year edge cases: book chapters, videos, authorless online entries, ISBNs.",
    ),
    "biblatex-uniquename": Test(
        kind="twin", pages=2, text_equal=True,
        text_assertions=(
            Assertion(engine="both", text="[E. Doe 2008; J. Doe 2008]"),
            Assertion(engine="both", text="[Kaur 2014; P. Kaur 2014]"),
            Assertion(engine="both", text="[Rita Fox 2012; Robert Fox 2012]"),
            Assertion(engine="both", text="[S. Fox 2012]"),
            Assertion(engine="both", text="[J.-P. Rho et al. 2002; J. Rho 2002]"),
            Assertion(engine="both", text="[J. Fig and M. Fig 2019]"),
            Assertion(engine="both", text="[Delta 2021; Zulu et al. 2021]"),
            Assertion(engine="both", text="[J. Nutmeg 2016; S. Nutmeg et al. 2016]"),
            Assertion(engine="both", text="[Brown 2010a,b]"),
            Assertion(engine="both", text="[Vogel, Acid, et al. 2001; Vogel, Beast, and "
                      "Garble 2000; Vogel, Beast, and Tremble 2000]"),
            Assertion(engine="both", text="[Prime and Quartz 2018; Prime, Quartz, et al. 2018]"),
            Assertion(engine="both", text="[Ash, Birch, et al. 2015, 2016; Ash and Dogwood 2015]"),
            Assertion(engine="both", text="[Coral et al. 2022a,b]"),
            Assertion(engine="both", text="[Ackee, Balsa, and Cocoa 2024a,b; Ackee, Balsa, "
                      "Cocoa, and Dill 2024]"),
            Assertion(engine="both", text="[Jane Hill et al. 2005; John Hill et al. 2005]"),
            Assertion(engine="both", text="[Oak, Pine, and C. Quill 2003; Oak, Pine, and "
                      "D. Quill 2003]"),
            Assertion(engine="both", text="[Alpha, Beta, et al. 2005; Chi, Drum, Eta, et al. "
                      "2006; Chi, Drum, Eta, and Phi 2006]"),
            Assertion(engine="both", text="[Lime et al. 2020; O. Nib 2020]"),
        ),
        note="BibLaTeX author-year cite-label disambiguation: uniquename levels, "
             "uniquelist widening, and the extradate letters left over.",
    ),
    "biblatex-driver-test": Test(
        kind="twin", pages=1,
        text_assertions=(
            Assertion(engine="both", text="Series book. (1st ed.). Book Series 11. "
                      "Vol. 3. Companion volume."),
            Assertion(engine="both", text="Ed. by Evan Editor. \"A contributed chapter.\" "
                      "Beatrice Bookauthor. Big Book of Drivers. (2nd ed.). Vol. 5."),
            Assertion(engine="both", text="Driver Series 7. (3rd ed.). Vol. 2. "
                      "Ed. by Eve Editor and Oscar Organizer"),
            Assertion(engine="both", text="isbn: 978-1-23456-789-7"),
            Assertion(engine="both", text="A translator-led book. Trans. by Trevor Translator. "
                      "Translation House, London."),
            Assertion(engine="both", text="Avery Author. 2019. \"An article in translation.\" "
                      "Trans. by Tina Translator."),
            Assertion(engine="both", text="Pat Inventor. May 4, 2020. "
                      "\"A carefully specified widget.\" (May 4, 2020). "
                      "Utility Patent Patent No. US-123456"),
            Assertion(engine="both", text="Holding Company. Filed electronically. doi:10.1000/patent"),
            Assertion(engine="both", text="A book with several publishers. First Press and "
                      "Second Press, Bern, Basel, and Bonn."),
            Assertion(engine="both", text="A report from several institutions. Tech. rep. "
                      "First Institute, Second Institute, and Third Institute, Kiel"),
            Assertion(engine="both", text="Ann Protect. 2022. “A title ending in protected "
                      "JSON: The continuation.” J."),
            Assertion(engine="both", text="In: A doubled book title: The book continuation, 1–9."),
            Assertion(engine="both", text="Cleo Mainline, (Ed.) . 2022. A main title ending in "
                      "protected XML: Component."),
            Assertion(engine="both", text="In: Proceedings of the Example Conf. "
                      "Ed. by Emil Chair. Conf Press."),
            Assertion(engine="both", text="In: Proceedings of the Example Conf. 1–9."),
            Assertion(engine="both", text="A proceedings in two languages. English and klingon."),
            Assertion(engine="both", text="First Society, Second Society, and Third Society . 2024. "
                      "An organization-led manual."),
            Assertion(engine="both", text="A nameless report. 2025. Tech. rep. Nameless Institute."),
            Assertion(engine="both", text="“A nameless thesis. ”2025. “With a subtitle of its own.” "
                      "Ph.D. Dissertation. Nameless University."),
            Assertion(engine="both", text="Short report. 2025. A report with a long title. "
                      "Tech. rep. Short Institute."),
            Assertion(engine="both", text="[Short report 2025]"),
            Assertion(engine="both", text="A dateless report. N.d. Tech. rep. Dateless Institute."),
            Assertion(engine="both", text="A shared report title. 2026a. Tech. rep. First Institute."),
            Assertion(engine="both", text="A shared report title. 2026b. Tech. rep. Second Institute."),
            Assertion(engine="both", text="[A dateless report n.d.]"),
            Assertion(engine="both", text="Ed. by Elsa Editor. Trans. by Tilly Translator."),
            Assertion(engine="both", text="In: Translated Collection. Ed. by Elsa Editor. "
                      "Trans. by Tilly Translator."),
            Assertion(engine="both", text="Mona Misc. 2017. A translated note. Ed. by Elsa Editor. "
                      "Trans. by Tilly Translator. (2017)."),
        ),
        note="BibLaTeX driver order for book/chapter, translator, and patent fields, "
             "including the editor and translator that byeditor+others prints as one unit.",
    ),
    "biblatex-driver-numeric-test": Test(
        kind="twin", pages=1,
        text_assertions=(
            Assertion(engine="both", text="Riley Report. 2023. MIXED Case Report Title. "
                      "Research Note RN-7. Example Lab, Ann Arbor, MI."),
            Assertion(engine="both", text="Tara Techreport. 2024. UPPERCASE Techreport Title. "
                      "Technical Memorandum TM-9. Legacy Lab, Palo Alto, CA."),
            Assertion(engine="both", text="2018. A translator-led book. "
                      "Trans. by Trevor Translator. Translation House, London."),
            Assertion(engine="both", text="Avery Author. 2019. An article in translation. "
                      "Trans. by Tina Translator."),
            Assertion(engine="both", text="Pat Inventor. 2020. A carefully specified widget. "
                      "(May 4, 2020). Utility Patent Patent No. US-123456"),
            Assertion(engine="both", text="A book with several publishers. First Press and "
                      "Second Press, Bern, Basel, and Bonn."),
            Assertion(engine="both", text="A report from several institutions. Tech. rep. "
                      "First Institute, Second Institute, and Third Institute,"),
            Assertion(engine="both", text="Ann Protect. 2022. A title ending in protected "
                      "JSON: The continuation. J."),
            Assertion(engine="both", text="In A doubled book title: The book continuation, 1–9."),
            Assertion(engine="both", text="In Proceedings of the Example Conf. Emil Chair, (Ed.) "
                      "Conf Press."),
            Assertion(engine="both", text="In Proceedings of the Example Conf. 1–9."),
            Assertion(engine="both", text="A proceedings in two languages. English and klingon, "
                      "(2023)."),
            Assertion(engine="both", text="First Society, Second Society, and Third Society. 2024. "
                      "An organization-led manual."),
            Assertion(engine="both", text="2025. A nameless report. Tech. rep. Nameless Institute."),
            Assertion(engine="both", text="2025. A nameless thesis. With a subtitle of its own. "
                      "Ph.D. Dissertation. Nameless University."),
            Assertion(engine="both", text="2025. A report with a long title. Tech. rep. Short Institute."),
            Assertion(engine="both", text="[n. d.] A dateless report. Tech. rep. Dateless Institute."),
            Assertion(engine="both", text="Elsa Editor, (Ed.) Trans. by Tilly Translator. 2019. "
                      "A translated chapter. Translated Book of Drivers."),
            Assertion(engine="both", text="In Translated Collection. Elsa Editor, (Ed.) "
                      "Trans. by Tilly Translator."),
            Assertion(engine="both", text="Mona Misc. 2017. A translated note. Elsa Editor, (Ed.) "
                      "Trans. by Tilly Translator. (2017)."),
        ),
        note="BibLaTeX numeric report sourcemap plus translator and patent drivers, "
             "including the editor and translator that byeditor+others prints as one unit.",
    ),
    "biblatex-names-test": Test(
        kind="twin", pages=2, text_equal=False,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="[Abe 2001; “ Ward 2018]",
                typst="[Abe 2001; “. Ward 2018]",
                cause=AcceptedTypstBehavior(
                    "punctuation-only initials retain their period regardless of citation position"),
            ),
        ),
        text_assertions=(
            Assertion(engine="both",
                      text="[Abe 2001; Æ-Zed 2001; Fox 2001; al-Hakim 2001; de-Zed 2001]"),
            Assertion(engine="both", text="[Ibn-Sina 2001]"),
            Assertion(engine="both", text="[Abe 2001; de-Wolf 2001; Fox 2001]"),
            Assertion(engine="both",
                      text="de-Zulu keeps its prefix in a title. (2001). ínigo Dotless."),
            Assertion(engine="both", text="Alice de-Zed. 2001."),
            Assertion(engine="both", text="P. Quirk R. Quirk D.-P. Rho D. Rho"),
            Assertion(engine="both", text="J. Sage K. Sage"),
            Assertion(engine="both", text="H. Tell O. Tell"),
            Assertion(engine="both", text="J.-P. Vane K. Vane"),
            Assertion(engine="both", text="æ.-P. Zeta R. Zeta"),
            Assertion(engine="both", text="Ö.-P. Yew R. Yew"),
            Assertion(engine="both", text="‘A. Ward B. Ward"),
            Assertion(engine="both", text="left out of the count “. Ward “. Xu B. Xu"),
            Assertion(engine="both", text="[“. Ward 2018; ‘A. Ward 2016; B. Ward 2017]"),
            Assertion(engine="latex", text="[Abe 2001; “ Ward 2018]"),
            Assertion(engine="typst", text="[Abe 2001; “. Ward 2018]"),
            Assertion(engine="both",
                      text="[!Bang at the front 2044; .NET at the front 2043]"),
            Assertion(engine="both", text="[Normalize 2019a,b]"),
            Assertion(engine="both", text="[Dotless 2020a,b]"),
            Assertion(engine="both", text="Fay Æ-Zed. 2001."),
        ),
        note="biber's default nosort and noinit filters on a name part, under acmauthoryear.",
    ),
    "biblatex-names-numeric-test": Test(
        kind="twin", pages=2, text_equal=True,
        text_assertions=(
            Assertion(engine="both", text="[3, 4, 31, 8, 7]"),
            Assertion(engine="both", text="[3, 5, 7]"),
            Assertion(engine="both", text="[9]"),
            Assertion(engine="both", text="[4] Fay Æ-Zed."),
            Assertion(engine="both", text="[31] Alice de-Zed."),
            Assertion(engine="both", text="[13, 12]"),
            Assertion(engine="both", text="[10, 11]"),
            Assertion(engine="both", text="Quirk Quirk Rho Rho"),
            Assertion(engine="both", text="Zeta Zeta"),
            Assertion(engine="both", text="Yew Yew"),
        ),
        note="the same fixtures under acmnumeric, which disambiguates no cite label.",
    ),
    "biblatex-fields-test": Test(
        kind="twin", pages=4, text_equal=True,
        text_assertions=(
            Assertion(engine="both", text='Ada Adams. June 14, 2026. "An article dated to '
                      'the day." Journal of Dates, (June 14, 2026).'),
            Assertion(engine="both", text="Gus Grant. Jan. 5, 2026. A misc dated in an "
                      "abbreviated month. (Jan. 5, 2026)."),
            Assertion(engine="both", text="Eve Ellis. June 2026. A misc dated to the month. "
                      "(June 2026)."),
            Assertion(engine="both", text="Fay Foster. June 2026. A misc with a day field "
                      "biber drops. (June 2026)."),
            Assertion(engine="both", text="[Ingle 2026]"),
            Assertion(engine="both", text="Ivy Ingle. June 14, 2026. A date beside the legacy "
                      "fields it overwrites. (June 14, 2026)."),
            Assertion(engine="both",
                      text="[Joyner 2024; Kirby 2024–2025; Mabry 2020–2022]"),
            Assertion(engine="both", text="[Lyman 2025–]"),
            Assertion(engine="both", text="Jan Joyner. Jan. 2–Mar. 4, 2024."),
            Assertion(engine="both", text="Kay Kirby. Jan. 2, 2024–Mar. 4, 2025."),
            Assertion(engine="both", text="Lou Lyman. May 6, 2025–."),
            Assertion(engine="both", text="Mel Mabry. 2020–2022."),
            Assertion(engine="both", text="[Nesbit –2025]"),
            Assertion(engine="both", text="[Orwell n.d.]"),
            Assertion(engine="both", text="Nan Nesbit. –May 6, 2025. A range with an open "
                      "start. (–May 6, 2025)."),
            Assertion(engine="both", text="Ott Orwell. N.d. A range open at both ends. ()."),
            Assertion(engine="both", text="[Pruitt 1999–2026]"),
            Assertion(engine="both", text="Pia Pruitt. Jan. 1999–June 14, 2026. An open start "
                      "the legacy fields answer. (Jan. 1999–June 14, 2026)."),
            Assertion(engine="both", text="[Quayle –2026]"),
            Assertion(engine="both", text="Rex Quayle. Jan. –June 14, 2026. An open start a "
                      "legacy month reaches. (Jan. –June 14, 2026)."),
            Assertion(engine="both", text="[Rhodes 1998]"),
            Assertion(engine="both", text="Sal Rhodes. Mar. 1998. A date field that is not one. "
                      "(Mar. 1998)."),
            Assertion(engine="both", text="A techreport with no type of its own. Tech. rep. "
                      "Type Institute, Kiel."),
            Assertion(engine="both", text="A report with no type of its own. Type Institute, Kiel."),
            Assertion(engine="both", text='"A doctoral thesis with no type." Ph.D. Dissertation.'),
            Assertion(engine="both", text='"A masters thesis with no type." Master\'s thesis.'),
            Assertion(engine="both", text='"A thesis typed as a candidate thesis." Cand. thesis.'),
            Assertion(engine="both", text="A report typed as a research report. Research rep. 7."),
            Assertion(engine="both", text="A misc typed as software. [SW]. (2001)."),
            Assertion(engine="both", text="A dataset typed as an audio CD. Audio CD."),
            Assertion(engine="both", text='"A patent typed as a US patent." (2001). U.S. pat. '
                      "Patent No. US-2."),
            Assertion(engine="both", text="A report with a free-text type. Working Note."),
            Assertion(engine="both", text="Uma Upton, (Ed.) . 2001. A book led by one editor."),
            Assertion(engine="both", text="Van Vance and Wes Walton, (Eds.) . 2001."),
            Assertion(engine="both", text="Lead Org . Mar. 2001. A manual led by an organization."),
            Assertion(engine="both", text='"An article whose editor cannot lead." Journal of '
                      "Leads. Ed. by Ana Abbott."),
            Assertion(engine="both", text="Xia Xu. 2001. A book with an author and an editor. "
                      "Ed. by Yin Young."),
            Assertion(engine="both", text="Ann Ash, Bo Birch, Cy Cedar, Di Dogwood, Ed Elm, "
                      "Fay Fir, Gus Gum, Hal Holly, and Ivy Ivy. 2001."),
            Assertion(engine="both", text='Jo Juniper et al.. 2001. "Ten authors cut to one."'),
            Assertion(engine="both", text="Cam Cherry et al., (Eds.) . 2001. Ten editors cut to one."),
            Assertion(engine="both", text="Zed Zelkova, Abe Alder, Bea Beech, et al.. 2001."),
            Assertion(engine="both", text="Ann Alpha et al.. 2001. A truncated dataset name list."),
            Assertion(engine="both", text="Trans. by Pat Pi et al. Journal of Names."),
            Assertion(engine="both", text="Patent No. US-9. Rex Rho et al."),
            Assertion(engine="both", text="Tia Tau et al. A Host Book."),
            Assertion(engine="both", text="[Adept anchors the ae expansion 2001; æsop expands to "
                      "ae 2001; Alpha closes the a run 2001; Lima anchors the l expansion 2001; "
                      "łodz expands to l 2001; Luna closes the l run 2001; Smith anchors the ss "
                      "expansion"),
            Assertion(engine="both", text="ßmith expands to ss 2001; Szabo closes the s run 2001]"),
            Assertion(engine="both", text="[æspace delimits the command 2001]"),
            Assertion(engine="both", text="[Æon files by macro case 2001; æon files by "
                      "macro case 2001]"),
            Assertion(engine="both", text='Abe Ashby. 2001. "ßtrasse DATA behind a space."'),
            Assertion(engine="both", text='"A thesis typed as a bachelor thesis." BA thesis.'),
            Assertion(engine="both", text='"A patent typed as a plain request." (2001). Pat. req.'),
            Assertion(engine="both", text='"A patent typed as a US request." (2001). U.S. pat. req.'),
            Assertion(engine="both", text="Vic Vance. 2001. A field the .bst would call "
                      "unknown. Real value. ??unknown."),
            Assertion(engine="both", text="a missing-value marker [Vic Vance 2001]"),
            Assertion(engine="both",
                      text="still labels its own citation [??unknown 2013]"),
            Assertion(engine="both", text="References ??unknown. (2013)."),
            Assertion(engine="both", text="a surname apart John Smith Jane Smith, widens a name "
                      "list past the truncation point Bell, Cole, and Dunn Bell, Cole, and Ewing, "
                      "and drops a name prefix that the numeric style keeps Beethoven."),
        ),
        note="BibLaTeX date, type, name-lead and title-case field formats under "
             "acmauthoryear.",
    ),
    "biblatex-fields-numeric-test": Test(
        kind="twin", pages=3, text_equal=True,
        text_assertions=(
            Assertion(engine="both", text="Dan Doyle. 2001. 3 ways of counting things."),
            Assertion(engine="both", text="Eli Emery. 2001. 3d rendering explained again."),
            Assertion(engine="both", text="Fern Floyd. 2001. 3D rendering explained once more."),
            Assertion(engine="both", text="Gil Gordon. 2001. 'tis the season for counting."),
            Assertion(engine="both", text="Hana Hardy. 2001. (almost) never again is enough."),
            Assertion(engine="both", text="Ivo Ingram. 2001. Ebay and the rest of them."),
            Assertion(engine="both", text="Joy Jenkins. 2001. One two three four five."),
            Assertion(engine="both", text="Kit Kramer. 2001. A study. another sentence entirely."),
            Assertion(engine="both", text="Lou Lawson. 2001. The ACM way of doing things."),
            Assertion(engine="both", text="Ann Amper. 2001. & data at the front."),
            Assertion(engine="both", text="Bud Percy. 2001. % data at the front."),
            Assertion(engine="both", text="Ivy Ingle. 2026. A date beside the legacy fields it "
                      "overwrites. (June 14, 2026)."),
            Assertion(engine="both", text="Jan Joyner. 2024. A range inside one year. "
                      "(Jan. 2–Mar. 4, 2024)."),
            Assertion(engine="both", text="Kay Kirby. 2024. A range across two years. "
                      "(Jan. 2, 2024–Mar. 4, 2025)."),
            Assertion(engine="both", text="Lou Lyman. 2025. A range with an open end. "
                      "(May 6, 2025–)."),
            Assertion(engine="both", text="Mel Mabry. 2020. A range of bare years. (2020–2022)."),
            Assertion(engine="both", text="Nan Nesbit. A range with an open start. "
                      "(–May 6, 2025)."),
            Assertion(engine="both", text="Ott Orwell. [n. d.] A range open at both ends. ()."),
            Assertion(engine="both", text="Pia Pruitt. 1999. An open start the legacy fields "
                      "answer. (Jan. 1999–June 14, 2026)."),
            Assertion(engine="both", text="Rex Quayle. An open start a legacy month reaches. "
                      "(Jan. –June 14, 2026)."),
            Assertion(engine="both", text="Sal Rhodes. 1998. A date field that is not one. "
                      "(Mar. 1998)."),
            Assertion(engine="both", text="Cleo Ryder. 2001. Data at the front."),
            Assertion(engine="both", text="Dot Sawyer. 2001. Data at the front."),
            Assertion(engine="both", text="Eli Tanner. 2001. Data at the front."),
            Assertion(engine="both", text="Fitz Usher. 2001. Data at the front."),
            Assertion(engine="both", text="Mae Mendez. 2001. Étude on accented starts."),
            Assertion(engine="both", text="Uma Upton, (Ed.) 2001. A book led by one editor."),
            Assertion(engine="both", text="[37] Jo Juniper et al. 2001. Ten authors cut to one."),
            Assertion(engine="both", text="Tao Tucker. 2001. Čase data every minute."),
            Assertion(engine="both", text="Uma Ulrich. 2001. Çedilla data every second."),
            Assertion(engine="both", text="Quin Quill. 2001. Æsop fable every year."),
            Assertion(engine="both", text="Rex Rankin. 2001. Sstrasse data every week."),
            Assertion(engine="both", text="Sal Sutton. 2001. Italic data every month."),
            Assertion(engine="both", text="Val Vernon. 2001. Data čase and æsop every so often."),
            Assertion(engine="both", text="Wyn Waller. 2001. æsop fable every decade."),
            Assertion(engine="both", text="Ann Alpha et al. A truncated dataset name list."),
            Assertion(engine="both", text="Trans. by Pat Pi et al. Journal of Names."),
            Assertion(engine="both", text="Patent No. US-9. Rex Rho et al."),
            Assertion(engine="both", text="Tia Tau et al. A Host Book."),
            Assertion(engine="both", text="[4] 2001. Adept anchors the ae expansion. (2001). "
                      "[5] 2001. Æon files by macro case. the uppercase macro. (2001). "
                      "[6] 2001. Æon files by macro case. the lowercase macro. (2001)."),
            Assertion(engine="both", text="Æsop expands to ae. (2001). [8] 2001. "
                      "Æspace delimits the command. (2001)."),
            Assertion(engine="both", text="Xia Xiong. 2001. Čase data behind a space."),
            Assertion(engine="both", text="Yan Yeager. 2001. Æsop fable behind a space."),
            Assertion(engine="both", text="Zoe Zamora. 2001. Öpen data behind a space."),
            Assertion(engine="both", text="Abe Ashby. 2001. Sstrasse data behind a space."),
            Assertion(engine="both", text="Nia Newton. 2001. Öpen data every day."),
            Assertion(engine="both", text="Oli Osgood. 2001. Öpen data every night."),
            Assertion(engine="both", text="Pia Prewitt. 2001. ßpen data every hour."),
            Assertion(engine="both", text="Vic Vance. 2001. A field the .bst would call "
                      "unknown. Real value. ??unknown."),
            Assertion(engine="both", text="a missing-value marker [87]"),
            Assertion(engine="both", text="a surname apart Smith Smith, widens a name list past "
                      "the truncation point Bell et al. Bell et al., and drops a name prefix "
                      "that the numeric style keeps van Beethoven."),
        ),
        note="the same fixtures under acmnumeric, which alone sentence-cases the "
             "titles and prints ACM's own year stand-in.",
    ),
    "biblatex-sort-test": Test(
        kind="twin", pages=2, text_equal=True,
        text_assertions=(
            Assertion(engine="both", text="Bo Bachman. 2001. “Bachman on prefixes.” J. "
                      "Ludwig van Beethoven. 2001. “Beethoven on prefixes.” J. "
                      "Al Berg. 2001. “Berg on prefixes.” J. "
                      "Jan Berg. 2001. “Another Berg on prefixes.” J. "
                      "Jan van Berg. 2001. “A third Berg on prefixes.” J."),
            Assertion(engine="both", text="Martin King. 2001a. “King without a suffix.” J. "
                      "Martin King Jr.. 2001b. “King the younger.” J. "
                      "Martin King Sr.. 2001c. “King the elder.” J."),
            Assertion(engine="both", text="[King 2001a; King 2001b; King 2001c]"),
            Assertion(engine="both", text="Al Ash and Cy Bo. 2001. “Padding with two names.” J. "
                      "Alan Ash. 2001. “Padding with one name.” J. "
                      "Zed Ash and Dee Cy. 2001. “Padding a shorter family name.” J. "
                      "Zed Ashby. 2001. “Padding a longer family name.” J."),
            Assertion(engine="both", text="Mid Mid. 2001. “Filed first by its presort.” J. "
                      "Zebra opening on a tie. (2001). "
                      "Shelved by the key Aaa, not by this. (2001). "
                      "Ranged by a sorttitle of Aab. (2001). "
                      "Zed Zeta. 2001. “Filed under its sortname.” J."),
            Assertion(engine="both", text="“Filed first by its presort.” J. Zebra opening on a tie."),
            Assertion(engine="both", text="Ivo Int. 2101. “An integer tie-breaker.” J. "
                      "Ivo Int. 2102. “An integer tie-breaker.” J. "
                      "Ivo Int. 2103. “An integer tie-breaker.” J. "
                      "Ivo Int. 2104. “An integer tie-breaker.” J."),
            Assertion(engine="both", text="Middle of the pack, another nameless entry. (2001). "
                      "Nia Noe. 2001. “Noe among the nameless.” J."),
            Assertion(engine="both", text="Sy Sort. 2009. “Filed under its sortyear.” J. "
                      "The one with a sortyear of its own. "
                      "Sy Sort. 2001. “Filed under its sortyear.” J. "
                      "The one falling back on its year. "
                      "Sorted under its title, not its translator."),
            Assertion(engine="both", text="[O’BrienStudy with an apostrophe 2001; "
                      "ObrienStudy without punctuation 2001]"),
            Assertion(engine="both", text="Vi Vol. 2001a. “A volume tie-breaker.” J. "
                      "Vi Vol. 2001b. “A volume tie-breaker.” J, 2. "
                      "Vi Vol. 2001c. “A volume tie-breaker.” J, IV. "
                      "Vi Vol. 2001d. “A volume tie-breaker.” J, 10. "
                      "Vi Vol. 2001e. “A volume tie-breaker.” J, Suppl."),
            Assertion(engine="both", text="Yo Year. 2001. “A year tie-breaker.” J. "
                      "Yo Year. 2003. “A year tie-breaker.” J. "
                      "Yo Year. N.d. “A year tie-breaker.” J."),
            Assertion(engine="both", text="Zebracrossing. (2001). zebracrossing. (2001)."),
        ),
        note="biber's nty sorting template under acmauthoryear, where a name "
             "prefix only breaks a tie behind the family name.",
    ),
    "biblatex-sort-numeric-test": Test(
        kind="twin", pages=2, text_equal=True,
        text_assertions=(
            Assertion(engine="both", text="[11] Bo Bachman. 2001. Bachman on prefixes. J. "
                      "[12] Al Berg. 2001. Berg on prefixes. J. "
                      "[13] Jan Berg. 2001. Another berg on prefixes. J. "
                      "[14] Charles de la Vallee Poussin. 2001. A multi-word prefix. J."),
            Assertion(engine="both", text="[36] Cara Valois. 2001. Valois on prefixes. J. "
                      "[37] Ludwig van Beethoven. 2001. Beethoven on prefixes. J."),
            Assertion(engine="both", text="[38] Jan van Berg. 2001. A third berg on prefixes. J."),
            Assertion(engine="both", text="[39] Ann van Zorn. 2001. Zorn on prefixes. J."),
            Assertion(engine="both", text="[48] Yo Year. [n. d.] A year tie-breaker. J."),
            Assertion(engine="both", text="[2] 2001. zebra opening on a tie."),
        ),
        note="the same fixtures under acmnumeric, which inherits useprefix=true "
             "from trad-standard.bbx and files a prefixed name under its prefix.",
    ),
    "biblatex-stages-test": Test(
        kind="twin", pages=1, text_equal=True,
        text_assertions=(
            Assertion(engine="both", text="Fay Addon. 2001. “A titled article.” "
                      "Extended abstract. J."),
            Assertion(engine="both", text="In: A host bookExtended proceedings, 1–9."),
            Assertion(engine="both", text="A main title. Vol. 3.B: A subtitle-bearing "
                      "proceedings. Ti Press, Bern."),
            Assertion(engine="both", text="A translated proceedings. French. "
                      "Trans. by Xena Xavier."),
            Assertion(engine="both", text="An addon-only event. Special Session."),
            Assertion(engine="both", text="Comput. Society. Pn Press."),
            Assertion(engine="both", text="A series that ends in a dot. Ser Series."),
            Assertion(engine="both", text="A pagetotal with a leading zero. 01 p."),
            Assertion(engine="both", text="A pagetotal that is no integer. 1-1."),
            Assertion(engine="both", text="A venue and nothing else (Paris)."),
            Assertion(engine="both", text="Bob Add. 2004. An addon with no title."),
            Assertion(engine="both", text="Ann Sub. 2003. A subtitle with no title."),
            Assertion(engine="both", text="Mia Marsh, (Ed.) . 2006. Main. Component."),
            Assertion(engine="both", text="Nia Nolan, (Ed.) . 2007. Main. Vol. 2: Component."),
            Assertion(engine="both", text="Pia Pike, (Ed.) . 2009. Main. Main addon. Component."),
            Assertion(engine="both", text="Ola Owens, (Ed.) . 2008. Same. Vol. 2."),
            Assertion(engine="both", text="Three languages. English, French, and German."),
            Assertion(engine="both", text="Kim Colon. 2014. Title: Addon."),
            Assertion(engine="both", text="Ann Kolon. 2017. “A title ending in a colon:” J."),
            Assertion(engine="both", text="Bob Sable. 2018. “A title ending in a colon: "
                      "The continuation.” J."),
            Assertion(engine="both", text="Cy Vega. 2019. “A paper.” In: A book ending in a "
                      "colon: The book continuation, 1–9."),
            Assertion(engine="both", text="Dot Wren, (Ed.) . 2020. A main ending in a colon: Part."),
            Assertion(engine="both", text="A main ending in a colon: Part. Two Society and "
                      "Three Society."),
            Assertion(engine="both", text="Gus Zorn, (Ed.) . 2022. Three organizers. One Society, "
                      "Two Society, and Three Society."),
        ),
        note="driver stages the ACM styles print: titles, language, translator, punctuation.",
    ),
    "biblatex-stages-numeric-test": Test(
        kind="twin", pages=1, text_equal=True,
        text_assertions=(
            Assertion(engine="both", text="Ad Elder, (Ed.) An addon-only event, (2005)."),
            Assertion(engine="both", kind="absent", text="An addon-only event. Special Session"),
            Assertion(engine="both", text="An organization that ends in a dot, (2006). "
                      "Comput. Society., Pn Press."),
            Assertion(engine="both", text="A series that ends in a dot, Ser Series. (2007)."),
            Assertion(engine="both", text="A translated proceedings. French. "
                      "Trans. by Xena Xavier, (2004)."),
            Assertion(engine="both", text="A main title. Vol. 3.B: A subtitle-bearing "
                      "proceedings. Bern, (2003). Ti Press."),
            Assertion(engine="both", text="Gil Gray, (Ed.) A guarded event, (2013)."),
            Assertion(engine="both", kind="absent", text="A guarded event. Special Session"),
            Assertion(engine="both", text="Ola Owens, (Ed.) Same, vol. 2, (2008)."),
            Assertion(engine="both", text="A series and a number, number 4 in Series. (2016)."),
            Assertion(engine="both", text="Ann Kolon. 2017. A title ending in a colon: J."),
            Assertion(engine="both", text="Cy Vega. 2019. A paper. In A book ending in a colon: "
                      "The book continuation, 1–9."),
            Assertion(engine="both", text="Dot Wren, (Ed.) A main ending in a colon: Part, (2020). "
                      "Two Society and Three Society."),
            Assertion(engine="both", text="Gus Zorn, (Ed.) Three organizers, (2022). One Society, "
                      "Two Society, and Three Society."),
        ),
        note="the same fixtures under acmnumeric, whose event guard skips an addon-only event.",
    ),
    "bst-periodical-test": Test(
        kind="twin", pages=1, text_equal=True,
        text_assertions=(
            Assertion(engine="both", text="Bare Society 2001. A bare periodical. (2001)."),
            Assertion(engine="both", text="Vn Society 2002. A periodical with two numbers. "
                      "7, 2 (2002)."),
            Assertion(engine="both", text="Bang Society 2003. A periodical that ends in a bang! "
                      "(2003)."),
            Assertion(engine="both", text="J Society 2004. A periodical with a journal. "
                      "J. Periodicals 9 (2004)."),
            Assertion(engine="both", text="Cy Author. 2005. An unpublished draft. (March 2005). "
                      "In preparation."),
            Assertion(engine="both", text="Dot Author. 2006. An article with no journal. "
                      "5, 1 (2006)."),
        ),
        note="the .bst blocks that open with a parenthesized date; the periodical driver's "
             "shape family. Text gates normalize whitespace, so the single space itself is "
             "pinned by the raster golden.",
    ),
    "biblatex-label-test": Test(
        kind="twin", pages=1, text_equal=True,
        text_assertions=(
            Assertion(engine="both", text="Project Atlas. 2038. A report carrying an explicit "
                      "label. Tech. rep. Atlas Institute."),
            Assertion(engine="both", text="[Project Atlas 2038]"),
            Assertion(engine="both", text="Project Beta. 2039. A report with a label and a short "
                      "title. Tech. rep. Beta Institute."),
            Assertion(engine="both", kind="absent", text="Short beta"),
            Assertion(engine="both", text="Ada Marker. 2040. A named report with a label."),
            Assertion(engine="both", text="[Marker 2040]"),
            Assertion(engine="both", kind="absent", text="Project Gamma"),
            Assertion(engine="both", text="Project Delta. 2041. “A thesis carrying a label.” "
                      "Ph.D. Dissertation."),
            Assertion(engine="both", text="[Project Echo 2042; Project Echo 2042]"),
            Assertion(engine="both", text="Project Echo. 2042. The first echo report."),
            Assertion(engine="both", text="Project Echo. 2042. The second echo report."),
            Assertion(engine="both", text="[Project Golf 2044]"),
            Assertion(engine="both", text="A misc carrying a label. (2044)."),
            Assertion(engine="both", text="Project Atlas [2038], Project Beta [2039], "
                      "Marker [2040], Project Delta [2041], and Project Golf"),
        ),
        note="the explicit `label` field: its precedence, its plain format, and what it leaves standing.",
    ),
    "biblatex-label-numeric-test": Test(
        kind="twin", pages=1, text_equal=True,
        text_assertions=(
            Assertion(engine="both", text="2038. A report carrying an explicit label. "
                      "Tech. rep. Atlas Institute."),
            Assertion(engine="both", text="2039. A report with a label and a short title."),
            Assertion(engine="both", text="2041. A thesis carrying a label. Ph.D. Dissertation."),
            Assertion(engine="both", text="Ada Marker. 2040. A named report with a label."),
            Assertion(engine="both", kind="absent", text="Project"),
            Assertion(engine="both", text="A report carrying an explicit label [2], Short beta [3], "
                      "Marker [5], “A thesis carrying a label” [4], and"),
            Assertion(engine="both", text="A misc carrying a label [1]."),
        ),
        note="the same entries under acmnumeric, where the label never prints.",
    ),
    "biblatex-dates-test": Test(
        kind="twin", pages=1, text_equal=True,
        text_assertions=(
            Assertion(engine="both", text="Ann Query. 2005. An uncertain year. (2005)."),
            Assertion(engine="both", text="Bob Tilde. 2005. An approximate year. (2005)."),
            Assertion(engine="both", text="Cy Ex. 2000–2009. An unspecified digit. (2000–2009)."),
            Assertion(engine="both", text="Dot Season. Spr. 2005. A season month. (Spr. 2005)."),
            Assertion(engine="both", text="Hal Feb. June 7, 1975. “A day that is not in that "
                      "month.”"),
            Assertion(engine="both", text="Jon Leap. Feb. 29, 2004. “A day that is.”"),
            Assertion(engine="both", text="Kim End. 2005. “A malformed endpoint.”"),
            Assertion(engine="both", text="Eli Pct. 2005. A percent marker. (2005)."),
            Assertion(engine="both", text="Dot Double. 1999. A doubled marker. (1999)."),
            Assertion(engine="both", text="Fay MonthX. Jan.–Dec. 2005. An unspecified month. "
                      "(Jan.–Dec. 2005)."),
            Assertion(engine="both", text="Gus DayX. May 1–31, 2005. An unspecified day. "
                      "(May 1–31, 2005)."),
            Assertion(engine="both", text="Hal Start. Mar. 1999. A malformed start."),
            Assertion(engine="both", text="Ivy Span. 1990–1999. A span on each side. (1990–1999)."),
            Assertion(engine="both", text="Jon XEnd. 2005. A span at the end. (2005)."),
            Assertion(engine="both", text="Ann Neg. −100. A negative year. (−100)."),
            Assertion(engine="both", text="Fay Early. 100. An early year, zero-padded. (100)."),
            Assertion(engine="both", text="Bob Range. −100– −50. A negative range. (−100– −50)."),
            Assertion(engine="both", text="Cy Cross. −50–50. A range across the era. (−50–50)."),
            Assertion(engine="both", text="[Neg −0100]"),
            Assertion(engine="both", text="[Early 0100]"),
            Assertion(engine="both", text="[Cross −0050–0050; Range −0100– −0050]"),
        ),
        note="the date forms biber reads beyond YYYY-MM-DD, and the ones it rejects.",
    ),
    "biblatex-dates-numeric-test": Test(
        kind="twin", pages=1, text_equal=True,
        text_assertions=(
            Assertion(engine="both", text="Cy Ex. 2000. An unspecified digit. (2000–2009)."),
            Assertion(engine="both", text="Dot Season. 2005. A season month. (Spr. 2005)."),
            Assertion(engine="both", text="Jon Leap. 2004. A day that is."),
            Assertion(engine="both", text="Fay MonthX. 2005. An unspecified month. "
                      "(Jan.–Dec. 2005)."),
            Assertion(engine="both", text="Ivy Span. 1990. A span on each side. (1990–1999)."),
            Assertion(engine="both", text="Hal Start. 1999. A malformed start. (Mar. 1999)."),
            Assertion(engine="both", text="Ann Neg. 100. A negative year. (−100)."),
            Assertion(engine="both", text="Cy Cross. 50. A range across the era. (−50–50)."),
        ),
        note="the same fixtures under acmnumeric, whose lead prints the start year alone.",
    ),
    "biblatex-misc-test": Test(
        kind="twin", pages=2, text_equal=True,
        text_assertions=(
            Assertion(engine="both", text="“An article carrying a version.” "
                      "Version v3. Journal of Versions"),
            Assertion(engine="both", text="Handbook. Version 2.1."),
            Assertion(engine="both", text="Pat Parent, A parent carrying a date version 2.0, "
                      "–June 2025."),
            Assertion(engine="both", text="Pat Parent, A parent carrying a date version 3.0, "
                      "Jan. 1999."),
            Assertion(engine="both", text="[Parent 1999a, –2025]"),
            Assertion(engine="both", text="version 3.0, Jan. 1999. [SW] Pat Parent, A parent "
                      "carrying a date Jan. 1999."),
            Assertion(engine="both", text="[Ward 2024]"),
            Assertion(engine="both", kind="absent", text="[SW] Wren Ward"),
            Assertion(engine="both", text="[Ashby 2001; Boyle 2001]"),
            Assertion(engine="both", text="Ada Ashby. 2001. “A first shared paper.” In: A shared "
                      "proceedings parent. Ed. by Eve Editor. Inherit Press, Oslo, 1–9."),
            Assertion(engine="both", text="Ben Boyle. 2001. “A second shared paper.” In: A shared "
                      "proceedings parent. Ed. by Eve Editor. Inherit Press, Oslo, 10–19."),
            Assertion(engine="both", text="Eve Editor, (Ed.) . 2001. A shared proceedings parent. "
                      "Inherit Press, Oslo."),
            Assertion(engine="both", text="Cy Colby. 1995b. “An article in it.” A periodical "
                      "parent, 3–7. Ed. by Pia Press."),
            Assertion(engine="both", text="Cy Colby. 1995a. “A child article.” Child Journal, 3–7. "
                      "Ed. by Pia Press."),
            Assertion(engine="both", text="Dot Doyle. 2001. “A conference child.” In: A parent "
                      "proceedings. Ed. by Eve Editor. Al Press, Child City, 1–9."),
            Assertion(engine="both", text="Fay Foster. Aug. 17, 2003. “A day-dated child.”"),
            Assertion(engine="both", text="Gus Grant. 1990–1992. “A range-dated child.”"),
            Assertion(engine="both", text="Ida Irwin. 2010. “A standalone paper.” In: 1–5."),
            Assertion(engine="both", text="“A chapter of its own.” Lee Larson. A whole book. "
                      "Pg Press, Bern, 5–9."),
            Assertion(engine="both", text="Ann Able. 2001. “Both spellings of a field.” "
                      "Canonical Journal. CanonArch: 1234.5678 (canon.cls)."),
            Assertion(engine="both", text="A full proceedings. The Big Event (Reykjavik, "
                      "Mar. 4, 2000). Vol. 7.2. 3 vols. Proc Series 9. A closing note. Proc Org. "
                      "Full Press, Oslo. 321 pp."),
            Assertion(engine="both", text="Bo Bogus. 1990–1992. “A bogus-dated child.”"),
            Assertion(engine="both", text="Dot Doyle. 2005. “An undated grandchild.”"),
            Assertion(engine="both", text="“A chapter with no publisher.” A host book, 5–9."),
            Assertion(engine="both", text="Hal Hooper. 2005. “A custom archive.” J. "
                      "Custom Archive: 9876.5432 (custom.class)."),
            Assertion(engine="both", text="Jon Jarvis. 2007. “A containerless paper.” In: ed. by "
                      "Eve Elder, 1–5."),
            Assertion(engine="both", text="Event full. Annual Event. Special Session "
                      "(Paris, Apr. 2–3, 2000)."),
            Assertion(engine="both", text="Part only. .B. Pt Press, Bern."),
            Assertion(engine="both", text="Cy Thirteen. Aug. 17, 2003. “A month biber rejects.”"),
            Assertion(engine="both", text="Dot Doyle. 2005. “An undated grandchild.”"),
            Assertion(engine="both", text="Ivy Empty. 2007. “An empty canonical spelling.”"),
            Assertion(engine="both", text="One page. Pg Press, Oslo. 1 p."),
            Assertion(engine="both", text="On a blog. Working note. Version v2."),
            Assertion(engine="both", text="An online carrying a version. Version v5."),
            Assertion(engine="both", text="Technical Report TR-3. Version v6."),
            Assertion(engine="both", text="Corpus. (2nd ed.). Version v12."),
            Assertion(engine="both", text="“A thesis carrying a version.” "
                      "Ph.D. Dissertation. Thesis University"),
            Assertion(engine="both", text="Software with a version and no date version v9."),
            Assertion(engine="both", text="A misc with a year and a month. (June 2011)."),
            Assertion(engine="both", text="Berlin: Misc Org, (May 2002)."),
            Assertion(engine="both", text="Vienna: Authorless Org, (Feb. 2023)."),
            Assertion(engine="both", text="A misc with a doi and a url. (Sept. 2003). "
                      "doi:10.1000/miscdoiurl."),
            Assertion(engine="both", text="(July 2007). http://ex.org/me arXiv: 2402.00002."),
            Assertion(engine="both", text="An online with a doi and a url. Retrieved "
                      "December 8, 2026 from http://ex.org/od."),
            Assertion(engine="both", text="An online with a doi and no url."),
            Assertion(engine="both", text="An online with howpublished type and "
                      "organization. Online Org. (Oct. 2035)."),
            Assertion(engine="both", text="A www entry. http://ex.org/ww."),
            Assertion(engine="both", text="A presentation with a date. (Mar. 2027)."),
            Assertion(engine="both", text="A paper under review. (2025)."),
        ),
        note="BibLaTeX misc/online/manual driver split, the `version` field format, "
             "and undated entries; acmauthoryear half of the pair.",
    ),
    "biblatex-misc-numeric-test": Test(
        kind="twin", pages=2, text_equal=True,
        text_assertions=(
            Assertion(engine="both", text="Tom Tate. [n. d.] An article with no date."),
            Assertion(engine="both", text="Val Vale. [n. d.] A misc with no date. ()."),
            Assertion(engine="both", text="Pat Parent, A parent carrying a date version 2.0, "
                      "–June 2025."),
            Assertion(engine="both", text="Wren Ward, Another parent carrying a date version 4.0, "
                      "May 2024."),
            Assertion(engine="both", text="[SW] Pat Parent, A parent carrying a date Jan. 1999."),
            Assertion(engine="both", kind="absent", text="[SW] Wren Ward"),
            Assertion(engine="both", text="Cy Colby. 1995. An article in it. A periodical "
                      "parent, 3–7. Pia Press, (Ed.)"),
            Assertion(engine="both", text="Eve Editor, (Ed.) A shared proceedings parent. "
                      "Oslo, (2001). Inherit Press."),
            Assertion(engine="both", text="Ida Irwin. 2010. A standalone paper. In 1–5."),
            Assertion(engine="both", text="A chapter of its own. Lee Larson. A whole book. "
                      "Pg Press, Bern, 5–9."),
            Assertion(engine="both", text="A full proceedings. The Big Event (Reykjavik, "
                      "Mar. 4, 2000), vol. 7.2 of number 9 in Proc Series, 3 vols. Oslo, "
                      "(2nd ed.), (2001). Proc Org, Full Press. 321 pp."),
            Assertion(engine="both", text="Jon Jarvis. 2007. A containerless paper. In "
                      "Eve Elder, (Ed.), 1–5."),
            Assertion(engine="both", text="A chapter with no publisher. A host book, 5–9."),
            Assertion(engine="both", text="Min Elder, (Ed.) Proceedings with pages, (2004), 1–9."),
            Assertion(engine="both", text="Ser Elder, (Ed.) Proceedings with a series, number 7 "
                      "in Ser Series, (2002)."),
            Assertion(engine="both", text="Eve Elder, (Ed.) Event full. Annual Event. "
                      "Special Session (Paris, Apr. 2–3, 2000), (2001)."),
            Assertion(engine="both", text="Pat Part, (Ed.) Part only, .B. Bern, (2006). Pt Press."),
            Assertion(engine="both", text="One Elder, (Ed.) One page. Oslo, (2008). Pg Press. 1 p."),
            Assertion(engine="both", text="Wes Webb. [n. d.] An online with no date."),
            Assertion(engine="both", text="Sam Stone. A dataset with no date whatsoever."),
            Assertion(engine="both", text="Zoe Zane. A dataset with a month but no year. ()."),
        ),
        note="the same fixtures under acmnumeric, where the undated stand-in is "
             "ACM's \"[n. d.]\" rather than biblatex's `nodate` string.",
    ),
    "bib-all": Test(
        kind="twin", pages=1,
        note="BST backend sweep over ACM-Reference-Format entry types; text and links are gated.",
    ),
    "bib-edge": Test(
        kind="twin", pages=1,
        note="BST backend edge cases: DOI/pages/key fallback, macros, strings, names, accents.",
        text_assertions=(
            Assertion(engine="both", text="Tech Press, Ltd."),
            Assertion(engine="both", text="Comput. Surveys"),
            Assertion(engine="both", text="Submitted to Mind"),
            Assertion(engine="both", text="Maria de la Cruz"),
            Assertion(engine="both", kind="absent", text="doi.acm.org"),
            Assertion(engine="both", text="Article 17"),
            Assertion(engine="both", text="9:1"),
            Assertion(engine="both", text="250 book pages"),
            Assertion(engine="both", text="Issue 7"),
            Assertion(engine="both", text="Preprint"),
            Assertion(engine="both", text="Jan von der Berg"),
            Assertion(engine="both", text="Ludwig van Beethoven"),
            Assertion(engine="both", text="23 Oct."),
            Assertion(engine="both", text="Article 7"),
            Assertion(engine="both", text="Article 5"),
            Assertion(engine="both", kind="absent", text="Article Article"),
            Assertion(engine="both", text="Fifth ed."),
        ),
    ),
    "crossref": Test(
        kind="twin", pages=1,
        note="BibTeX crossref inheritance, listing threshold, key fallback, and distinct URL fields.",
        text_assertions=(
            Assertion(engine="both", text="See ["),
            Assertion(engine="both", text="Workshop on Small Things"),
            Assertion(engine="both", text="GangOfFour"),
        ),
    ),
    "authoryear": Test(
        kind="twin", pages=1,
        note="BST backend author-year labels, year disambiguation, citations, and unnumbered references.",
        text_assertions=(
            Assertion(engine="both", text="2020a"),
            Assertion(engine="both", text="Jones et al."),
            Assertion(engine="both", text="2020b"),
            Assertion(engine="both", text="IEEE Task Force"),
            Assertion(engine="both", text="[Onl 2001; Col 2002; Dat 2005]"),
            Assertion(engine="both", text="[Manual Society 2003]"),
            Assertion(engine="both", text="[Webkey 2004]"),
            Assertion(engine="both", text="Online Society 2001. An online with an organization. "
                      "Online Society."),
            Assertion(engine="both", text="Eve Editor (Ed.). 2002. A collection with an editor."),
            Assertion(engine="both", text="[Vance 2015a,b]"),
            Assertion(engine="both", text="Ivo Wren. [n. d.]a. Undated alpha."),
        ),
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="[Wren 0000a,b]",
                typst="[Wren [n. d.]a,b]",
                cause=AcceptedTypstBehavior(
                    "ACM-Reference-Format 2.2 stopped writing \"[n.\\,d.]\" into the "
                    "\\bibitem label year, writing \"0000\" and a \\NAT@parse@date patch that "
                    "turns it back into \"[n.\\,d.]\". begin.bib emits that patch AFTER "
                    "\\begin{thebibliography}, so it is local to that environment and never "
                    "reaches an in-text citation: LaTeX now prints the bare 0000 there, while "
                    "the reference list (which uses format.year) still prints [n. d.]. We keep "
                    "[n. d.] in both places; drop this entry if ACM moves the patch."),
            ),
        ),
        expected_font_diffs=(
            ExpectedFontDiff(
                latex="[Wren 0000a,b]",
                typst="[Wren [n. d.]a,b]",
                cause=AcceptedTypstBehavior(
                    "the same kept [n. d.] as the text diff above: its \"n\" and \"d\" have "
                    "no counterpart in LaTeX's bare 0000."),
            ),
        ),
    ),
    "mathfields": Test(
        kind="twin", pages=1,
        expected_font_diffs=(
            ExpectedFontDiff(
                latex="Bounds of 𝑂(𝑛log𝑛) with 𝛼+ 𝛽≤𝛾and 𝜇→∞.",
                typst="Bounds of 𝑂(𝑛log 𝑛) with 𝛼+ 𝛽≤𝛾 and 𝜇→∞.",
                cause=AcceptedTypstBehavior("Typst math operators render with the math font instead of LaTeX's text-roman operator font"),
            ),
            ExpectedFontDiff(
                latex="Products 𝑎𝑏and tensor indices 𝑥𝑖𝑗with 2𝑛terms.",
                typst="Products 𝑎𝑏 and tensor indices 𝑥𝑖𝑗 with 2𝑛 terms.",
                cause=AcceptedTypstBehavior("inline math script glyphs render 0.5pt larger than LaTeX"),
            ),
            ExpectedFontDiff(
                latex="On 𝑛 2 bounds for 𝑎⊕𝑏with 𝑥2𝑛≤𝑦.",
                typst="On 𝑛 2 bounds for 𝑎⊕𝑏 with 𝑥2𝑛≤𝑦.",
                cause=AcceptedTypstBehavior("inline math fraction/script glyphs render 0.5pt larger than LaTeX"),
            ),
        ),
        note="BST reference-field math rendering, including operators, scripts, blackboard, and overrides.",
        text_assertions=(
            Assertion(engine="both", text="-calculus"),
        ),
    ),
    "keycite": Test(
        kind="twin", pages=1,
        note="Native `@key` citations routed through the BST backend.",
    ),
    "notes-test": Test(
        kind="twin", pages=1,
        note="title/subtitle/author notes, corresponding mark, received line, and acks. "
             "The title block and footnote stack mix leadings, so pitch is reported, not gated. "
             "Its two \\thanks notes end on a lowercase and an uppercase letter, pinning both "
             "sides of \\@addpunct's space-factor rule against LaTeX.",
    ),
    "notes-conf-test": Test(
        kind="twin", pages=1,
        note="the same top-matter notes on an acmsmall CONFERENCE paper: \\acmConference "
             "empties the authors-addresses stream (no \\thanks, no contact block), so the "
             "notes sit directly above the copyright stream — the two-stream footnote "
             "layout that no journal twin reaches.",
    ),
    "options-test": Test(
        kind="twin", pages=2, metrics_page1_only=_PAGE1_METRICS_SCOPE,
        note="option toggles for nonacm, printccs, printfolios, balance, and natbib.",
    ),
    "authorversion-test": Test(
        kind="twin", pages=1,
        note="author-version copyright block (suppressed permission text + \"author's "
             "version ... Version of Record\" notice). Mixed leadings, so pitch is reported.",
    ),
    "authorversion-conf-test": Test(
        kind="twin", pages=1, text_equal="bag",
        text_assertions=(
            Assertion(engine="both", text="Conference'17, Washington, DC, USA"),
            Assertion(engine="both",
                      text="Version of Record was published in Proceedings of ACM "
                           "Conference (Conference'17)"),
            Assertion(engine="typst", kind="absent", text="ACM ISBN"),
        ),
        note="author-version on a CONFERENCE format: the italic conference-info line "
             "still prints and the Version-of-Record notice names the booktitle "
             "(acmart.dtx:6615/6638). Two-column extraction order, so word-bag.",
    ),
    "anonymous-test": Test(
        kind="twin", pages=1,
        text_assertions=(
            Assertion(engine="both", text="ANONYMOUS AUTHOR(S)"),
            Assertion(engine="both", text="SUBMISSION ID: 123-A56-BU3"),
            Assertion(engine="typst", kind="absent", text="Trovato"),
            Assertion(engine="typst", kind="absent", text="Contact Information"),
            Assertion(engine="both", kind="absent", text="Corresponding author"),
        ),
        note="double-anonymous journal submission: anonymized author strip with the "
             "uppercased \"SUBMISSION ID:\" second line (acmart.dtx:5190-5193), "
             "suppressed contact footnote, suppressed \\correspondingauthor, "
             "anonymized ACM reference block.",
    ),
    "language-test": Test(
        kind="twin", pages=1,
        note="French main language plus English translated title, abstract, and keywords.",
    ),
    "language-de-test": Test(
        kind="twin", pages=1, rule_gate=_RULE_BOOKTABS,
        note="German `language=german`: keywordsname/acksname/proofname + tablename "
             "(\"Tabelle\") localized, figure label still \"Fig.\"",
    ),
    "language-es-test": Test(
        kind="twin", pages=1, rule_gate=_RULE_BOOKTABS,
        note="Spanish `language=spanish`: keywordsname/acksname/proofname + tablename "
             "(\"Cuadro\") localized, figure label still \"Fig.\"",
    ),
    "language-de-sigplan-test": Test(
        kind="twin", pages=1,
        note="German on a proceedings format: the abstract heading (\"Zusammenfassung\", "
             "journals print none) and the bibliography heading (\"Literatur\") come from "
             "babel; plus keywordsname/proofname/acksname",
    ),
    "acmengage-de-test": Test(
        kind="twin", pages=1,
        note="acmengage under a German main language: babel's \"Zusammenfassung\" "
             "heads the abstract, not acmengage's \"Synopsis\"",
    ),
    "sample-acmsmall": Test(
        kind="twin", pages=11, expected_metrics_diff=_FULL_SAMPLE_METRICS_DIFF,
        text_equal=False,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="centered horizontally— is produced by the equation environment",
                typst="centered horizontally —is produced by the equation environment",
                cause=ExtractionArtifact(
                    "the em dash sits at a line break, and each engine breaks on the "
                    "other side of it: LaTeX keeps it with the preceding word, Typst "
                    "with the following one"),
            ),
        ),
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="unnumbered equation: ∞ ∑ i=0 x+ 1 and follow",
                typst="∑ ∞ i=0 x+ 1 and follow",
                cause=ExtractionArtifact(
                    "display-math limits before the operator: TeX draws the sum's "
                    "limits as their own boxes ahead of the ∑ glyph, so the flat "
                    "stream reads ∞ ∑, while the Formula chunk reads ∑ ∞"),
            ),
            ExpectedOrderDiff(
                latex="enter an unnumbered equation: ∞ ∑",
                typst="enter an unnumbered equation: J. ACM, Vol. 37, No. 4, "
                      "Article 111. Publication date: August 2018. 111:6 "
                      "Trovato et al. ∑",
                cause=ExtractionArtifact(
                    "the equation paragraph is split by a page break, so the running "
                    "head lands inside its token span at a different word in each "
                    "engine; the chunk window then loses the paragraph's tail"),
            ),
        ),
        note="full twin of the upstream acmsmall sample.",
    ),
    "sample-manuscript": Test(
        kind="twin", pages=11, review_line_numbers=True,
        text_equal=False,
        expected_text_diffs=_CCS_ARROW_TEXT_EVIDENCE,
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="unnumbered equation: ∞ ∑ i=0 x+ 1 and follow",
                typst="∑ ∞ i=0 x+ 1 and follow",
                cause=ExtractionArtifact(
                    "display-math limits before the operator: TeX draws the sum's "
                    "limits as their own boxes ahead of the ∑ glyph, so the flat "
                    "stream reads ∞ ∑, while the Formula chunk reads ∑ ∞"),
            ),
            ExpectedOrderDiff(
                latex="from αto ω, available in LATEX [25]",
                typst="from α to ω, available in LATEX [25]",
                cause=ExtractionArtifact(
                    "an inline formula is its own chunk, so the paragraph chunk keeps "
                    "the surrounding words only; LaTeX's stream glues α onto the "
                    "following word (\"αto\"), leaving the paragraph's \"to\" with no "
                    "match in place"),
            ),
        ),
        note="upstream manuscript sample (manuscript,screen,review + proceedings "
             "metadata). Single-column review style with margin line numbers.",
    ),
    "sample-acmlarge": Test(
        kind="twin", pages=11,
        text_equal=False,
        expected_text_diffs=_CCS_ARROW_TEXT_EVIDENCE,
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="unnumbered equation: ∞ ∑ i=0 x+ 1 and follow",
                typst="∑ ∞ i=0 x+ 1 and follow",
                cause=ExtractionArtifact(
                    "display-math limits before the operator: TeX draws the sum's "
                    "limits as their own boxes ahead of the ∑ glyph, so the flat "
                    "stream reads ∞ ∑, while the Formula chunk reads ∑ ∞"),
            ),
            ExpectedOrderDiff(
                latex="(see 2a in spec. document) [18], a Proc. ACM Meas. Anal. Comput. "
                      "Syst., Vol. 37, No. 4, Article 111. Publication date: August 2018. "
                      "111:8 • Trovato et al. divisible-book such as an anthology or "
                      "compilation [13]",
                typst="(see 2a in spec. document) [18], a divisible-book such as an "
                      "anthology or compilation [13]",
                cause=ExtractionArtifact(
                    "the citation-guide paragraph is split by a page break, so the "
                    "running head lands inside its token span at a different word in "
                    "each engine; the chunk window then loses the paragraph's tail"),
            ),
        ),
        note="upstream acmlarge sample (wide single-column journal, POMACS).",
    ),
    "sample-sigconf": Test(
        kind="twin", pages=6,
        text_equal=False,
        expected_text_diffs=_STACKED_SCRIPT_TEXT_EVIDENCE,
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="unnumbered equation: ∞ ∑ i=0 x+ 1 and follow",
                typst="∑ ∞ i=0 x+ 1 and follow",
                cause=ExtractionArtifact(
                    "display-math limits before the operator: TeX draws the sum's "
                    "limits as their own boxes ahead of the ∑ glyph, so the flat "
                    "stream reads ∞ ∑, while the Formula chunk reads ∑ ∞"),
            ),
        ),
        note="upstream sigconf sample: two-column proceedings with author grid and teaser figure.",
    ),
    "sample-sigplan": Test(
        kind="twin", pages=7,
        text_equal=False,
        expected_text_diffs=_STACKED_SCRIPT_TEXT_EVIDENCE,
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="unnumbered equation: ∞ ∑ i=0 x+ 1 and follow",
                typst="∑ ∞ i=0 x+ 1 and follow",
                cause=ExtractionArtifact(
                    "display-math limits before the operator: TeX draws the sum's "
                    "limits as their own boxes ahead of the ∑ glyph, so the flat "
                    "stream reads ∞ ∑, while the Formula chunk reads ∑ ∞"),
            ),
        ),
        note="upstream sigplan sample (two-column SIGPLAN proceedings, 10pt).",
    ),
    "sample-acmsmall-submission": Test(
        kind="twin", pages=10, review_line_numbers=True,
        text_equal=False, rule_gate=_RULE_REVIEW_SAMPLE,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="centered horizontally— is produced by the equation environment",
                typst="centered horizontally —is produced by the equation environment",
                cause=ExtractionArtifact(
                    "the em dash sits at a line break, and each engine breaks on the "
                    "other side of it: LaTeX keeps it with the preceding word, Typst "
                    "with the following one"),
            ),
        ),
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="unnumbered equation: ∞ ∑ i=0 x+ 1 and follow",
                typst="∑ ∞ i=0 x+ 1 and follow",
                cause=ExtractionArtifact(
                    "display-math limits before the operator: TeX draws the sum's "
                    "limits as their own boxes ahead of the ∑ glyph, so the flat "
                    "stream reads ∞ ∑, while the Formula chunk reads ∑ ∞"),
            ),
        ),
        note="upstream acmsmall double-anonymous review sample "
             "(screen,anonymous,review): anonymized author strip + line numbers.",
    ),
    "sample-acmsmall-conf": Test(
        kind="twin", pages=11, expected_metrics_diff=_FULL_SAMPLE_METRICS_DIFF,
        text_equal=False,
        expected_text_diffs=_CCS_ARROW_TEXT_EVIDENCE,
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="unnumbered equation: ∞ ∑ i=0 x+ 1 and follow",
                typst="∑ ∞ i=0 x+ 1 and follow",
                cause=ExtractionArtifact(
                    "display-math limits before the operator: TeX draws the sum's "
                    "limits as their own boxes ahead of the ∑ glyph, so the flat "
                    "stream reads ∞ ∑, while the Formula chunk reads ∑ ∞"),
            ),
        ),
        note="upstream acmsmall-for-a-conference sample (acmsmall journal format "
             "with conference metadata replacing the journal metadata).",
    ),
    "sample-acmtog": Test(
        kind="twin", pages=6, expected_metrics_diff=_FULL_SAMPLE_METRICS_DIFF,
        text_equal=False,
        expected_text_diffs=_CCS_ARROW_TEXT_EVIDENCE,
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="unnumbered equation: ∞ ∑ i=0 x+ 1 and follow",
                typst="∑ ∞ i=0 x+ 1 and follow",
                cause=ExtractionArtifact(
                    "display-math limits before the operator: TeX draws the sum's "
                    "limits as their own boxes ahead of the ∑ glyph, so the flat "
                    "stream reads ∞ ∑, while the Formula chunk reads ∑ ∞"),
            ),
        ),
        note="upstream acmtog sample (two-column TOG journal). Uses the author-year "
             "citation style (\\citestyle{acmauthoryear}) via the bst backend.",
    ),
    "sample-acmtog-conf": Test(
        kind="twin", pages=6,
        text_equal=False,
        expected_text_diffs=_CCS_ARROW_TEXT_EVIDENCE,
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="unnumbered equation: ∞ ∑ i=0 x+ 1",
                typst="unnumbered equation: ∑ ∞ i=0 x+ 1",
                cause=ExtractionArtifact(
                    "display-math limits before the operator: TeX draws the sum's "
                    "limits as their own boxes ahead of the ∑ glyph, so the flat "
                    "stream reads ∞ ∑, while the Formula chunk reads ∑ ∞"),
            ),
        ),
        note="upstream acmtog-for-a-conference sample (acmtog two-column with "
             "conference metadata + teaser; author-year citations via the bst backend).",
    ),
    "sample-sigconf-i13n": Test(
        kind="twin", pages=7, expected_metrics_diff=_FULL_SAMPLE_METRICS_DIFF,
        text_equal=False,
        expected_text_diffs=_STACKED_SCRIPT_TEXT_EVIDENCE,
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="unnumbered equation: ∞ ∑ i=0 x+ 1 and follow",
                typst="∑ ∞ i=0 x+ 1 and follow",
                cause=ExtractionArtifact(
                    "display-math limits before the operator: TeX draws the sum's "
                    "limits as their own boxes ahead of the ∑ glyph, so the flat "
                    "stream reads ∞ ∑, while the Formula chunk reads ∑ ∞"),
            ),
            ExpectedOrderDiff(
                latex="language=french, language=german, language=spanish, "
                      "language=english]{acmart}",
                typst="language=english, language=german, language=french]{acmart}",
                cause=ExtractionArtifact(
                    "the sample prints two \\documentclass listings whose tokens are "
                    "identical bar the order of the language options, so the chunk "
                    "window vote maps the second listing onto the first"),
            ),
        ),
        note="upstream sigconf internationalization sample: \\translatedtitle + "
             "translatedabstract in French/German/Spanish (English main), each "
             "abstract headed by its babel \\abstractname.",
    ),
    "sample-sigconf-authordraft": Test(
        kind="twin", pages=6,
        review_line_numbers=True,
        text_equal=False,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="2026-07-01 12:00. Page 2 of 1-6.",
                typst="2026-07-01. Page 2 of 1-6.",
                cause=AcceptedTypstBehavior(
                    "Typst has no wall-clock access, so the timestamp footer prints the "
                    "compile date without the HH:MM time (DESIGN.md)."),
            ),
        ),
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="unnumbered equation: ∞ ∑ i=0 x+ 1 and follow",
                typst="∑ ∞ i=0 x+ 1 and follow",
                cause=ExtractionArtifact(
                    "display-math limits before the operator: TeX draws the sum's "
                    "limits as their own boxes ahead of the ∑ glyph, so the flat "
                    "stream reads ∞ ∑, while the Formula chunk reads ∑ ∞"),
            ),
        ),
        note="upstream sigconf authordraft sample: draft watermark, line numbers, timestamp. "
             "Also the only fixture with lists under `authordraft`, whose list geometry is "
             "acmart's own — authordraft raises review mode without the `review` key "
             "handler's begin-document hook (list-test / list-plain-test cover the other two).",
    ),
    "sample-acmsmall-biblatex": Test(
        kind="twin", pages=11, expected_metrics_diff=_FULL_SAMPLE_METRICS_DIFF,
        text_equal=False,
        expected_text_diffs=_CCS_ARROW_TEXT_EVIDENCE,
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="unnumbered equation: ∞ ∑ i=0 x+ 1 and follow",
                typst="∑ ∞ i=0 x+ 1 and follow",
                cause=ExtractionArtifact(
                    "display-math limits before the operator: TeX draws the sum's "
                    "limits as their own boxes ahead of the ∑ glyph, so the flat "
                    "stream reads ∞ ∑, while the Formula chunk reads ∑ ∞"),
            ),
            ExpectedOrderDiff(
                latex="enter an unnumbered equation: ∞ ∑",
                typst="enter an unnumbered equation: J. ACM, Vol. 37, No. 4, "
                      "Article 111. Publication date: August 2018. 111:6 "
                      "Trovato et al. ∑",
                cause=ExtractionArtifact(
                    "the equation paragraph is split by a page break, so the running "
                    "head lands inside its token span at a different word in each "
                    "engine; the chunk window then loses the paragraph's tail"),
            ),
            ExpectedOrderDiff(
                latex="4. doi:10.1145/105 7270.1057278.",
                typst="4. doi:10.1145/1057270.1057278.",
                cause=ExtractionArtifact(
                    "reference URLs and DOIs wrap at a different character in each "
                    "engine, so the flat stream chops the identifier where the tagged "
                    "chunk does not and the split piece cannot be re-joined"),
            ),
        ),
        text_assertions=(
            Assertion(engine="both", text="Software project: [Delebecque et al. 1994; "
                   "The CGAL Project 1996]. Software Version: [Greenman and Felleisen "
                   "2020]. Software Module: [Karavelas 2020]. Code fragment: "
                   "[Di Cosmo and Danelutto 2020]."),
            Assertion(engine="both", text="[SW exc.] Roberto Di Cosmo and Marco Danelutto"),
            Assertion(engine="both", text="R. Baggett, M. Simecek, C. Chambellan, "
                      "K. Tsui, and M. Fraune. 2025. Fluidity in the Phased Framework "
                      "of Technology Acceptance"),
            Assertion(engine="both", text="Mobile Telepresence Robots. (2025)."),
            Assertion(engine="both", text="Jacques Cohen, (Ed.). Nov. 1996. "
                      "Special issue: Digital Libraries. Commun. ACM 39, 11 "
                      "(Nov. 1996)."),
            Assertion(engine="both", text="David Harel. 1979. First-Order Dynamic "
                      "Logic. Lecture Notes in Computer Science. Vol. 68."),
            Assertion(engine="both", text="David Harel. 1978. LOGICS of Programs: "
                      "AXIOMATICS and DESCRIPTIVE POWER. MIT Research Lab Technical "
                      "Report TR-200."),
            Assertion(engine="both", text="Newton Lee. Jan. 2005. \"Interview with "
                      "Bill Kinder: January 13, 2005.\" Comput. Entertain., 3, 1, "
                      "(Jan. 2005), 4."),
        ),
        note="upstream acmsmall-biblatex sample with author-year software artifact cites.",
    ),
    "sample-sigconf-biblatex": Test(
        kind="twin", pages=7,
        text_equal=False,
        expected_text_diffs=_CCS_ARROW_TEXT_EVIDENCE,
        expected_font_diffs=_FULL_SAMPLE_FONT_EVIDENCE,
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="unnumbered equation: ∞ ∑ i=0 x+ 1 and follow",
                typst="∑ ∞ i=0 x+ 1 and follow",
                cause=ExtractionArtifact(
                    "display-math limits before the operator: TeX draws the sum's "
                    "limits as their own boxes ahead of the ∑ glyph, so the flat "
                    "stream reads ∞ ∑, while the Formula chunk reads ∑ ∞"),
            ),
            ExpectedOrderDiff(
                latex="visit=swh:1:snp:2a 6c348c53eb77d458f24c9cbcecaf92e3c45615",
                typst="visit=swh:1:snp:2a6c348c53eb77d 458f24c9cbcecaf92e3c45615",
                cause=ExtractionArtifact(
                    "the software-artifact SWHIDs wrap at a different character in "
                    "each engine, so the flat stream chops the identifier where the "
                    "tagged chunk does not and the split piece cannot be re-joined"),
            ),
        ),
        text_assertions=(
            Assertion(engine="both", text="Software project: [41, 12]. Software Version: "
                   "[17]. Software Module: [25]. Code fragment: [13]."),
            Assertion(engine="both", text="[SW Rel.] Ben Greenman and Matthias Felleisen"),
            Assertion(engine="both", text="2004. Ieee tcsc executive committee. In "
                      "Proceedings of the IEEE International Conference on Web Services"),
            Assertion(engine="both", text="3, 1, (Jan. 2005), 4. doi:"
                      "10.1145/1057270.1057278."),
            Assertion(engine="both", text="2017. Institutional members of the TEX users "
                      "group. Retrieved May 27, 2017"),
        ),
        note="upstream sigconf-biblatex sample with numeric software artifact cites; page parity is open.",
    ),
    "sample-acmcp": Test(
        kind="twin", pages=1,
        text_equal="bag", rule_gate=_RULE_ACMCP_FOOT,
        expected_text_diffs=(
            ExpectedTextDiff(
                latex="Ben Trovato, trovato@corporation.com G.K.M. Tobin,",
                typst="Ben Trovato, trovato@corporation.com; G.K.M. Tobin,",
                cause=ExtractionArtifact(
                    "the contact line overfills the narrow acmcp measure, so LaTeX "
                    "draws its trailing \";\" past the MediaBox and extraction drops "
                    "it (widening the MediaBox brings it back)"),
            ),
            ExpectedTextDiff(
                latex="Hekla, Iceland, jsmith@affiliation.org Julius P. Kumquat,",
                typst="Hekla, Iceland, jsmith@affiliation.org; Julius P. Kumquat,",
                cause=ExtractionArtifact(
                    "the same overfull contact line: this \";\" also lands past the "
                    "MediaBox in LaTeX and is dropped by extraction"),
            ),
        ),
        note="upstream acmcp sample: JDS banner, cover infobox, and author contributions.",
    ),
    "sample-acmengage": Test(
        kind="twin", pages=3,
        text_equal="bag",
        expected_order_diffs=(
            ExpectedOrderDiff(
                latex="https://doi.org/XXXXXXX.XXXXXXX known to broaden participation",
                typst="https://doi.org/XXXXXXX.XXXXXXX be based on at least one "
                      "evidenced-based teaching practice",
                cause=ExtractionArtifact(
                    "the copyright block interleaves with the body sentence at a "
                    "different word in each engine, and its ISBN is one unbroken run "
                    "in the tag tree (Typst writes soft hyphens there) against "
                    "hyphen-separated components in the flat stream, so the "
                    "per-character split of that run cannot align"),
            ),
        ),
        note="upstream acmengage sample: EngageCSEdu layout, synopsis, metadata, and CC license.",
    ),
    "siggraph-test": Test(
        kind="smoke", pages=1, golden_exempt=_ALIAS_GOLDEN_EXEMPT,
        note="obsolete `siggraph` option aliases to sigconf; compile-only smoke.",
    ),
    "sigchi-test": Test(
        kind="smoke", pages=1, golden_exempt=_ALIAS_GOLDEN_EXEMPT,
        note="obsolete public option `sigchi` aliases to sigconf (matching the bundled "
             "LaTeX class). Typst-only alias compile check (see siggraph-test).",
    ),
    "draft-test": Test(
        kind="smoke", pages=1,
        text_assertions=(
            Assertion(engine="typst", text="Submission ID: 123-A56-BU3"),
            Assertion(engine="typst", text="Page 1 of"),
        ),
        note="author-draft timestamp mode smoke.",
    ),
    "urlbreak-test": Test(
        kind="smoke", pages=1,
        note="`urlbreakonhyphens: false` smoke with golden-pinned Typst URL breaking.",
    ),
    "feature-test": Test(
        kind="smoke", pages=1,
        note="Typst-only smoke for badges, teaser, title notes, and subtitle notes.",
    ),
    "defaults-test": Test(
        kind="smoke", pages=1,
        golden_exempt="Behavior smoke only; focused format twins own the rendered layout.",
        text_assertions=(
            Assertion(engine="typst", text="Manuscript submitted to ACM"),
            Assertion(engine="typst", text="https://doi.org/10.1145/nnnnnnn.nnnnnnn"),
        ),
        note="Default acmart options: format=manuscript and placeholder DOI.",
    ),
    "proceedings-defaults-test": Test(
        kind="smoke", pages=2,
        golden_exempt="Behavior smoke only; sigconf twins own the rendered layout.",
        text_assertions=(
            Assertion(engine="typst", text="Conference'17, July 2017, Washington, DC, USA"),
            Assertion(engine="typst", text="Proceedings of ACM Conference (Conference'17)"),
            Assertion(engine="typst", text="https://doi.org/10.1145/nnnnnnn.nnnnnnn"),
        ),
        note="Proceedings defaults: placeholder \\acmConference/\\acmBooktitle and DOI.",
    ),
    "bib-relative-test": Test(
        kind="smoke", pages=1,
        note="Regression: a single relative #bibliography path resolves against the "
             "caller on the bibtex engine backend (arguments-origin threaded to read()).",
    ),
    "acmcp-acmref-test": Test(
        kind="smoke", pages=1,
        golden_exempt="Behavior smoke only; acmcp-test owns the rendered cover layout.",
        text_assertions=(
            Assertion(engine="typst", text="ACM Reference Format"),
            Assertion(engine="typst", text="An acmcp Reference-Format Override"),
        ),
        note="A4.1: explicit print-acm-reference: true overrides acmcp's default "
             "suppression (LaTeX honours a post-\\begin \\settopmatter{printacmref=true}).",
    ),
    "fix-quirks-doc-test": Test(
        kind="smoke", pages=1,
        text_assertions=(
            Assertion(engine="typst", text="https://doi.org/10.1145/1234567.1234568"),
            Assertion(engine="typst", kind="absent", text="https://doi.org/https://"),
            Assertion(engine="typst", text="Measured in the U.S. A run-in heading"),
            Assertion(engine="typst", text="Deployed across the EU. A deeper run-in heading"),
            Assertion(engine="typst", text="Ordinary subsubsection. A control heading"),
            Assertion(engine="typst", text="Proof of Thm. A. The proof body"),
            Assertion(engine="typst", text="council in the UK. Authors"),
            Assertion(engine="typst", text="London, UK. Permission"),
        ),
        link_assertions=(
            LinkAssertion(uri="https://doi.org/10.1145/1234567.1234568"),
            LinkAssertion(kind="absent",
                          uri="https://doi.org/https://DOI.org/10.1145/1234567.1234568"),
        ),
        note="fix-quirks outside the bibliography: a resolver URL in the `doi` option is "
             "stripped once, and terminal punctuation is recognized after an abbreviation.",
    ),
    "fix-quirks-doc-off-test": Test(
        kind="smoke", pages=1,
        text_assertions=(
            Assertion(engine="typst", text="https://doi.org/https://DOI.org/10.1145/1234567.1234568"),
            Assertion(engine="typst", text="Measured in the U.S.. A run-in heading"),
            Assertion(engine="typst", text="Deployed across the EU.. A deeper run-in heading"),
            Assertion(engine="typst", text="Ordinary subsubsection. A control heading"),
            Assertion(engine="typst", text="Proof of Thm. A.. The proof body"),
            Assertion(engine="typst", text="council in the UK.."),
            Assertion(engine="typst", text="London, UK.."),
        ),
        link_assertions=(
            LinkAssertion(uri="https://doi.org/https://DOI.org/10.1145/1234567.1234568"),
        ),
        note="The same document with fix-quirks: false keeps the LaTeX-compatible doubled "
             "resolver and the doubled period after an uppercase abbreviation.",
    ),
    "fix-quirks-doc-default-test": Test(
        kind="smoke", pages=1,
        note="The same document with the option omitted; GOLDEN_EQUIVALENT_PAIRS pins it to "
             "render exactly like the explicit fix-quirks: false variant.",
    ),
    "fix-quirks-bst-test": Test(
        kind="smoke", pages=1,
        text_assertions=(
            Assertion(engine="typst", text="A first article in the volume. See [3]"),
            Assertion(engine="typst", kind="absent", text="See[3]"),
            Assertion(engine="typst", text="year-only citation 2019, Sec. 2"),
            Assertion(engine="typst", text="Ellis, n. 4"),
            Assertion(engine="typst", text="2020, passim"),
            Assertion(engine="typst", text="locator once: Doyle; Ellis, p. 7"),
            Assertion(engine="typst", text="stay bare: Doyle and 2020"),
        ),
        note="fix-quirks on the BibTeX backend: a space after the article cross-reference "
             "`See`, and locators retained on author-only and year-only numeric citations.",
    ),
    "fix-quirks-bst-off-test": Test(
        kind="smoke", pages=1,
        text_assertions=(
            Assertion(engine="typst", text="A first article in the volume. See[3]"),
            Assertion(engine="typst", text="year-only citation 2019. The helpers"),
            Assertion(engine="typst", text="take one too: Ellis and 2020."),
            Assertion(engine="typst", text="locator once: Doyle; Ellis."),
            Assertion(engine="typst", kind="absent", text="Sec. 2"),
            Assertion(engine="typst", kind="absent", text="passim"),
        ),
        note="The same document with fix-quirks: false keeps natbib's dropped numeric "
             "locators and ACM's spaceless cross-reference.",
    ),
    "fix-quirks-blx-test": Test(
        kind="smoke", pages=1,
        text_assertions=(
            Assertion(engine="typst", text="Iris Inbook. 2021."),
            Assertion(engine="typst", text="Big Book of Drivers. Ed. by Evan Editor."),
            Assertion(engine="typst", text="Ed. by Evan Editor and Edna Editrix."),
            Assertion(engine="typst", text="Geneva: Standards Group."),
            Assertion(engine="typst", kind="absent", text="Standards Group, ()"),
            Assertion(engine="typst", kind="absent", text="publisher. ()"),
            Assertion(engine="typst", text="Standards Group Inc. 2016."),
            Assertion(engine="typst", text="Petra Pike, (Ed.) 2017."),
            Assertion(engine="typst", text="Widgets Inc. 2018."),
            Assertion(engine="typst", text="doi:10.1145/3597503"),
            Assertion(engine="typst", kind="absent", text="doi:https://"),
            Assertion(engine="typst", text="Nina Number. 2020. Series book."),
            Assertion(engine="typst", text="Iris Inbook. 2019."),
            Assertion(engine="typst", text="Translated Book. Ed. by Evan Editor. "
                      "Trans. by Trudy Translator."),
        ),
        link_assertions=(
            LinkAssertion(uri="https://doi.org/10.1145/3597503"),
            LinkAssertion(uri="https://doi.org/10.1145/3597504"),
            LinkAssertion(uri="https://doi.org/10.1145/3597505"),
            LinkAssertion(kind="absent", uri="https://doi.org/https://DOI.org/10.1145/3597503"),
        ),
        note="fix-quirks on the BibLaTeX author-year style: inbook leads with its author, an "
             "empty date drops its parentheses, a punctuated opening takes no second period, "
             "and a resolver URL in `doi` is stripped once.",
    ),
    "fix-quirks-blx-off-test": Test(
        kind="smoke", pages=1,
        text_assertions=(
            Assertion(engine="typst", kind="absent", text="Iris Inbook."),
            Assertion(engine="typst", text="Ed. by Evan Editor and Edna Editrix."),
            Assertion(engine="typst", text="Geneva: Standards Group, ()."),
            Assertion(engine="typst", text="publisher. ()."),
            Assertion(engine="typst", text="Standards Group Inc. . 2016."),
            Assertion(engine="typst", text="Petra Pike, (Ed.) . 2017."),
            Assertion(engine="typst", text="Widgets Inc.. 2018."),
            Assertion(engine="typst", text="doi:https://DOI.org/10.1145/3597503"),
            Assertion(engine="typst", text="Ed. by Evan Editor. Trans. by Trudy Translator."),
        ),
        link_assertions=(
            LinkAssertion(uri="https://doi.org/https://DOI.org/10.1145/3597503"),
            LinkAssertion(kind="absent", uri="https://doi.org/10.1145/3597503"),
        ),
        note="The same document with fix-quirks: false reproduces the upstream inbook "
             "attribution, empty parentheses, doubled periods, and doubled resolver.",
    ),
    "fix-quirks-blx-numeric-test": Test(
        kind="smoke", pages=1,
        text_assertions=(
            Assertion(engine="typst", text="Iris Inbook. 2021. A chapter without an editor."),
            Assertion(engine="typst", text="Iris Inbook. 2022. A contributed chapter."),
            Assertion(engine="typst", text="Big Book of Drivers. Evan Editor, (Ed.) (2nd ed.)"),
            Assertion(engine="typst",
                      text="Evan Editor and Edna Editrix, (Eds.) 2020. A chapter without an author."),
            Assertion(engine="typst", text="Geneva: Standards Group."),
            Assertion(engine="typst", kind="absent", text="Standards Group, ()"),
            Assertion(engine="typst", text="doi:10.1145/3597503"),
            Assertion(engine="typst", kind="absent", text="doi:https://"),
            Assertion(engine="typst", text="Iris Inbook. 2019. A translated chapter. "
                      "Translated Book. Evan Editor, (Ed.) Trans. by Trudy Translator."),
        ),
        link_assertions=(
            LinkAssertion(uri="https://doi.org/10.1145/3597503"),
            LinkAssertion(kind="absent", uri="https://doi.org/https://DOI.org/10.1145/3597503"),
        ),
        note="fix-quirks on the BibLaTeX numeric style: the same inbook attribution and "
             "empty-date corrections, with the numeric opening separator unchanged.",
    ),
    "fix-quirks-blx-numeric-off-test": Test(
        kind="smoke", pages=1,
        text_assertions=(
            Assertion(engine="typst", kind="absent", text="Iris Inbook."),
            Assertion(engine="typst", text="2021. A chapter without an editor. Beatrice"),
            Assertion(engine="typst", text="Evan Editor, (Ed.) 2022. A contributed chapter."),
            Assertion(engine="typst",
                      text="Evan Editor and Edna Editrix, (Eds.) 2020. A chapter without an author."),
            Assertion(engine="typst", text="Geneva: Standards Group, ()."),
            Assertion(engine="typst", text="doi:https://DOI.org/10.1145/3597503"),
            Assertion(engine="typst", text="Evan Editor, (Ed.) Trans. by Trudy Translator. 2019. "
                      "A translated chapter. Translated Book."),
        ),
        note="The same document with fix-quirks: false keeps the upstream numeric inbook "
             "attribution, empty parentheses, and doubled resolver.",
    ),
}


# name -> (extra acmart arguments, expected diagnostic[, custom body]).
ERROR_CASES: dict[str, tuple] = {
    "bad-copyright": ('copyright: "definitely-not-a-mode",', "unsupported copyright mode"),
    "bad-cc-type": ('copyright: "cc", cc-type: "by-mystery",', "unsupported Creative Commons type"),
    "bad-cc-version": ('copyright: "cc", cc-version: "2.5",', "unsupported Creative Commons version"),
    "bad-font-size": ("font-size: 13pt,", "must be a length, one of"),
    "bad-font-size-type": ('font-size: "10pt",', "must be a length"),
    "bad-language": ('language: "klingon",', "unsupported language"),
    "draft-option": ("draft: true,", "option `draft` has no effect"),
    "bad-journal": ('journal: "NOT-A-JOURNAL",', "unknown ACM journal code"),
    "bad-authors-per-row": ("authors-per-row: 2.5,", "`authors-per-row` must be a non-negative integer"),
    "bad-format": ('format: "not-a-format",', "unknown format"),
    "bad-bib-backend": ('bib-backend: "sqlite",', "`bib-backend` must be"),
    "bad-cite-style": ('cite-style: "footnote",', "`cite-style` must be"),
    "bad-acm-month": ("acm-month: 13,", "`acm-month` must be an integer 1..12"),
    "ccs-malformed-ccsdesc": (
        'ccs: "\\\\ccsdesc[500]{Ok~Fine} \\\\ccsdesc[x]{Bad~Thing}",',
        "1 of 2 \\ccsdesc uses in `ccs` are malformed",
    ),
    "ccs-neither-form": (
        'ccs: "no concepts here",',
        "must contain \\ccsdesc lines or exactly one <ccs2012> element",
    ),
    "ccs-bad-type": ("ccs: 5,", "`ccs` must be an array"),
    "bad-acmcp-article-type": (
        'format: "acmcp", article-type: "Bogus", acmcp-logo: none,',
        "Article Type must be Research",
    ),
    "missing-acmcp-logo": ('format: "acmcp",', "acmcp` cover format needs a journal logo"),
    "two-corresponding-authors": (
        'authors: ((name: "Ada Lovelace", corresponding: true, '
        'affiliation: (institution: "Analytical Engine Institute", country: "UK")), '
        '(name: "Grace Hopper", corresponding: true, '
        'affiliation: (institution: "Harvard", country: "USA")),),',
        "at most one author may set `corresponding: true`",
    ),
    "missing-affiliation-country": (
        'authors: ((name: "Ada Lovelace", affiliation: (institution: "Analytical Engine Institute")),),',
        "every author affiliation must include a nonempty `country`",
    ),
    "missing-affiliation-country-nonacm": (
        'nonacm: true, authors: ((name: "Ada Lovelace", affiliation: (institution: "Analytical Engine Institute")),),',
        "every author affiliation must include a nonempty `country`",
    ),
    "bst-unknown-cmd": (
        "",
        "unsupported TeX command",
        '#import "/src/lib.typ": default-tex-render\n'
        '#default-tex-render("a \\\\frobnicate{x} title")',
    ),
    "bibtex-relative-multi": (
        'bib-backend: "bibtex",',
        "must use project-absolute",
        '#bibliography(("a.bib", "b.bib"))',
    ),
    "cite-unknown-form": (
        'bib-backend: "bibtex",',
        'does not support `form: "footnote"`',
        '= Body\n#cite(<Cohen07>, form: "footnote")\n#bibliography("/tests/twins/sample-base.bib")',
    ),
    "cite-full-supplement": (
        'bib-backend: "bibtex",',
        "prints the whole reference, so it takes no `supplement`",
        '= Body\n#cite(<Cohen07>, form: "full", supplement: [p. 5])'
        '\n#bibliography("/tests/twins/sample-base.bib")',
    ),
    "cite-unknown-argument": (
        'bib-backend: "bibtex",',
        "`cite` has no `style` argument",
        '= Body\n#cite(<Cohen07>, style: "apa")\n#bibliography("/tests/twins/sample-base.bib")',
    ),
    "cite-without-bibliography": (
        'bib-backend: "bibtex",',
        "faithful-acmart: cited a key but no bibliography is registered",
        "= Body\nA citation @Cohen07 with no bibliography.",
    ),
}


# name -> (LaTeX class options, LaTeX preamble, Typst acmart arguments).
VARIANTS: dict[str, tuple[str, str, str]] = {
    "acmlicensed":    ("", r"\setcopyright{acmlicensed}",    '  copyright: "acmlicensed",\n'),
    "acmcopyright":   ("", r"\setcopyright{acmcopyright}",   '  copyright: "acmcopyright",\n'),
    "rightsretained": ("", r"\setcopyright{rightsretained}", '  copyright: "rightsretained",\n'),
    "usgov":          ("", r"\setcopyright{usgov}",          '  copyright: "usgov",\n'),
    "usgovmixed":     ("", r"\setcopyright{usgovmixed}",     '  copyright: "usgovmixed",\n'),
    "cc-by-nc-sa":    ("", "\\setcopyright{cc}\n\\setcctype{by-nc-sa}",
                       '  copyright: "cc", cc-type: "by-nc-sa",\n'),
    "iw3c2w3":        ("", r"\setcopyright{iw3c2w3}",           '  copyright: "iw3c2w3",\n'),
    "cc-zero":        ("", "\\setcopyright{cc}\n\\setcctype{zero}",
                       '  copyright: "cc", cc-type: "zero",\n'),
    "screen":    (",screen", r"\setcopyright{acmlicensed}", '  screen: true,\n'),
    "review":    (",review", r"\setcopyright{acmlicensed}", '  review: true,\n'),
    "anonymous": (",anonymous", r"\setcopyright{acmlicensed}", '  anonymous: true,\n'),
    "nonacm":    (",nonacm", r"\setcopyright{acmlicensed}", '  nonacm: true,\n'),
    "authorversion": (",authorversion", r"\setcopyright{acmlicensed}",
                      '  author-version: true,\n'),
}

VARIANT_MISMATCH_MAX: dict[str, float] = {
    "acmlicensed": 4.75,
    "acmcopyright": 4.50,
    "rightsretained": 4.25,
    "usgov": 4.00,
    "usgovmixed": 4.50,
    "cc-by-nc-sa": 3.75,
    "iw3c2w3": 4.50,
    "cc-zero": 3.75,
    "screen": 4.75,
    "review": 5.00,
    "anonymous": 4.50,
    "nonacm": 2.50,
    "authorversion": 4.00,
}
