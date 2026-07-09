// typst-acmart — a Typst port of the LaTeX acmart class.
//
// Public entry point: apply with a show rule. Import with the wildcard so the
// shadowed `cite` / `bibliography` and the `cite-text` / `cite-year` / `cite-author`
// helpers (which route citations and the reference list through the active
// `bib-backend`) are in scope — a selective import gets Typst's built-in `cite` /
// `bibliography`, which only behave correctly on the default "typst" backend:
//   #import "@preview/faithful-acmart:0.1.0": *
//   #show: acmart.with(format: "acmsmall", title: [...], ...)
//
// All public acmart formats are accepted (see _formats below): the single-column
// journals (manuscript/acmsmall/acmlarge), the two-column journal (acmtog), the
// two-column proceedings (sigconf/sigplan/acmengage), obsolete siggraph/sigchi
// aliases to sigconf, and bespoke sigchi-a (landscape) / acmcp (cover page).

#import "formats/acmsmall.typ": acmsmall
#import "formats/manuscript.typ": manuscript
#import "formats/acmlarge.typ": acmlarge
#import "formats/acmtog.typ": acmtog
#import "formats/sigconf.typ": sigconf
#import "formats/sigplan.typ": sigplan
#import "formats/acmengage.typ": acmengage
#import "formats/sigchi-a.typ": sigchia
#import "formats/acmcp.typ": acmcp
#import "formats/_base.typ": tp
#import "parts/spacing.typ": comp, tex-skip
#import "parts/headings.typ": render-heading
#import "parts/frontmatter.typ": make-title, make-title-head, make-title-body, make-footnotes, make-acmcp-infobox, make-received, make-badges, lookup-journal, pub-date, andify, normalize-author
#import "parts/body.typ": apply-body, sidebar, marginfigure, margintable, fulltextwidth
#import "parts/strings.typ": resolve-language, lang-record
#import "parts/theorems.typ": cfg-state, anon-state, thm-counter
#import "parts/theorems.typ": theorem, lemma, corollary, proposition, conjecture, definition, example, remark, proof, acks
#import "parts/acmref.typ": bbl-cite, bbl-citet, bbl-citeyear, bbl-citeauthor, bbl-bibliography, cite-style-state, tex-render-state
// the built-in bibtex-backend field renderer, exported so a custom `tex-render` can wrap it
#import "parts/tex.typ": tex-to-content as default-tex-render, latex-logo as _latex-logo, tex-logo as _tex-logo, bibtex-logo as _bibtex-logo

// A citation key may be given as a label (`<smith20>`, idiomatic) or a string
// ("smith20", for keys built dynamically or with characters awkward in a label).
// `str` yields the key name and `_cite-label` the label form (Typst 0.14 has no
// `label.name`).
#let _cite-label(k) = if type(k) == label { k } else { label(k) }

// Public `cite` — SHADOWS Typst's built-in so `#cite(<a>, <b>)` accepts MULTIPLE
// keys and renders one grouped bracket ("[1, 2]", like LaTeX \cite{a,b}); single
// `@key` / `#cite(<a>)` work too. Our per-element `show` rules can't merge adjacent
// citations, so this variadic form is the only way to group through the bibtex/
// biblatex backends. For "typst" it emits adjacent native cites (which Typst groups
// itself); otherwise it renders the group through the ACM engine.
#let cite(..args) = context {
  let cfg = cfg-state.get()
  let keys = args.pos()
  if cfg == none or cfg.bib-backend == "typst" {
    keys.map(k => std.cite(_cite-label(k))).join()
  } else {
    bbl-cite(..keys.map(str))
  }
}

// Textual citation helpers (natbib's \citet / \citeyear / \citeauthor), each taking
// one key (label or string). On the bibtex/biblatex backends they render through the
// ACM engine (\citet -> "Author [Year]"); on the native "typst" backend they map to
// Typst's own cite forms, bounded by the active CSL style.
//   cite-text   — "Author [Year]"      (\citet      / form: "prose")
//   cite-year   — the bare year/number (\citeyear   / form: "year")
//   cite-author — the bare author name (\citeauthor / form: "author")
#let _cite-variant(bbl-fn, native-form) = key => context {
  let cfg = cfg-state.get()
  if cfg == none or cfg.bib-backend == "typst" {
    std.cite(_cite-label(key), form: native-form)
  } else {
    bbl-fn(str(key))
  }
}
#let cite-text = _cite-variant(bbl-citet, "prose")
#let cite-year = _cite-variant(bbl-citeyear, "year")
#let cite-author = _cite-variant(bbl-citeauthor, "author")
// Friendly alias for the acknowledgments environment (acmart names it `acks`).
#let acknowledgments = acks
#let latex-logo = _latex-logo
#let tex-logo = _tex-logo
#let bibtex-logo = _bibtex-logo

// \anon{...} (acmart.dtx:6433): under the `anonymous` option the body is
// replaced by the substitute in ACM Orange; otherwise the body prints as-is.
#let anon(body, substitute: "ANONYMIZED") = context {
  if anon-state.get() { text(fill: cmyk(0%, 42%, 100%, 1%), substitute) } else { body }
}

// True when `body` begins with a paragraph (its first substantive child is inline
// text) rather than a block element (heading/figure/list/…). Used to reproduce
// LaTeX's indent of a titleless document's OPENING paragraph: with Typst's
// `first-line-indent: (…, all: false)` the first paragraph in the flow follows
// nothing and so is never indented, but LaTeX (no \maketitle, no preceding
// heading to fire \@afterindentfalse) applies \parindent to it. Leading
// whitespace / invisible metadata (state/counter updates) are skipped so they
// don't mask a real opening paragraph. A titled document is excluded by the
// caller — \maketitle ends \@afterindentfalse, so ITS first paragraph is not
// indented (which the all:false default already reproduces).
#let _body-starts-with-paragraph(body) = {
  if body.func() == text { return true }
  if not body.has("children") { return false }
  for c in body.children {
    let n = repr(c.func())
    if n in ("space", "parbreak", "pagebreak", "metadata", "state", "counter", "update") { continue }
    return c.func() == text
  }
  false
}

// \grantsponsor{id}{name}{url} typesets just the sponsor NAME (acmart.dtx:8866);
// the id/url are metadata for ACM's production pipeline.
#let grantsponsor(id, name, url) = name

// \grantnum[url]{id}{num} typesets the grant number, plus " (url)" when the
// optional url is given (acmart.dtx:8875).
#let grantnum(id, num, url: none) = if url == none { num } else { [#num (#link(url)[#url])] }

// \part: amsart's level-9 DISPLAY heading — \@parfont (the run-in paragraph
// font, italic), 10pt before / 4pt after, unnumbered (level 9 > secnumdepth).
#let part(body) = context {
  let cfg = cfg-state.get()
  let f = cfg.sec-fonts.paragraph
  block(above: tex-skip(cfg, 10 * tp), below: tex-skip(cfg, 4 * tp), sticky: true,
    text(font: cfg.fonts.at(f.family), weight: f.weight, style: f.style,
      size: cfg.size.at(f.size), body))
}

// Direct ACM reference-list renderer for the bibtex/biblatex backends: reads the
// .bib with the pure-Typst parser, so it never constructs a native bibliography
// element and never invokes hayagriva. Used by the `bibliography` shadow below.
#let _acm-bibliography(path, title: [References]) = context {
  let cfg = cfg-state.get()
  if cfg == none {
    bbl-bibliography(path, title: title)
  } else {
    bbl-bibliography(
      path,
      title: title,
      size: cfg.size.footnotesize,
      leading: comp(cfg, sz: "footnotesize"),
      format: if cfg.bib-backend == "biblatex" { "biblatex" } else { "bst" },
    )
  }
}

// Public `bibliography` — SHADOWS Typst's built-in so `#bibliography("refs.bib")`
// is the single idiomatic path for every backend. For "typst" it forwards the
// caller's `arguments` verbatim to the native element (the ACM CSL `set bibliography
// (style: …)` rule in body.typ then styles it); for "bibtex"/"biblatex" it renders
// through `_acm-bibliography`, which never constructs a native element and so never
// runs hayagriva (whose stricter BibTeX parser rejects valid ACM .bib features such
// as journal-abbreviation string macros — Typst validates a native `#bibliography`
// source at element construction, before any show rule could intercept, so shadowing
// is the only way to bypass it). `@key` resolves via `show ref`; `#cite` via the
// shadow above.
// `title` is an explicit named parameter so it is peeled off automatically — `..args`
// then holds only the path(s), which is what the engine backends thread to `read`.
#let bibliography(title: auto, ..args) = {
  // Like Typst's built-in `bibliography`, the path is a SINGLE argument — a string
  // or an array of paths; several files go in one array, not as separate positional
  // args (Typst rejects those with "unexpected argument"). Checked eagerly, outside
  // the context below, so this clear error wins over a cite's lazy read of the
  // not-yet-registered path.
  assert(args.pos().len() == 1,
    message: "faithful-acmart: `bibliography` takes a single path or an array of paths, like "
      + "Typst's built-in — for several files pass an array: "
      + "bibliography((\"/a.bib\", \"/b.bib\")). Got " + repr(args.pos().len())
      + " positional argument(s).")
  context {
    let cfg = cfg-state.get()
    let backend = if cfg == none { "typst" } else { cfg.bib-backend }
    if backend == "typst" {
      // Forward the `arguments` value verbatim: it remembers where it was constructed,
      // so a RELATIVE path resolves against the user's file, not this package. `title`
      // is re-attached only when set, so `auto` still defers to body.typ's `set
      // bibliography(title: [References])`. Passes single/array paths + full/style too.
      if title == auto { std.bibliography(..args) } else { std.bibliography(..args, title: title) }
    } else {
      // The bibtex/biblatex engines read the .bib with our own parser, deep inside the
      // package and *lazily* (during cite resolution, from `state`). Typst carries a
      // path's origin only through a value that is never indexed into: an `arguments`
      // value threaded whole to `read(..args)` keeps the caller's location; the moment
      // we extract a string (`.pos().first()`, iterating an array) the origin is lost
      // and a relative path would resolve against the package.
      //   • one positional STRING -> thread `args` (title already peeled); RELATIVE OK.
      //   • one positional ARRAY of paths (Typst's native multi-file form) -> must
      //     index, so every entry must be project-absolute.
      let title = if title == auto { [References] } else { title }
      let path = args.pos().first()
      if type(path) == str {
        _acm-bibliography(args, title: title)
      } else {
        for p in path {
          assert(type(p) != str or p.starts-with("/"),
            message: "faithful-acmart: with bib-backend " + repr(backend) + ", a bibliography of "
              + "multiple files must use project-absolute paths (start with \"/\"); a "
              + "single file may be relative. Got " + repr(p) + ".")
        }
        _acm-bibliography(path, title: title)
      }
    }
  }
}

#let _formats = (
  manuscript: manuscript,
  acmsmall: acmsmall,
  acmlarge: acmlarge,
  acmtog: acmtog,
  sigconf: sigconf,
  siggraph: sigconf,
  sigchi: sigconf,
  sigplan: sigplan,
  acmengage: acmengage,
  "sigchi-a": sigchia,
  acmcp: acmcp,
)

#let _acmcp-article-types = (
  "Research": (nr: 0, color: cmyk(100%, 10%, 0%, 10%)),
  "Review": (nr: 1, color: cmyk(0%, 42%, 100%, 1%)),
  "Discussion": (nr: 2, color: cmyk(20%, 0%, 100%, 19%)),
  "Invited": (nr: 3, color: cmyk(55%, 100%, 0%, 15%)),
  "Position": (nr: 4, color: cmyk(0%, 90%, 86%, 0%)),
)

#let acmart(
  format: "acmsmall",
  title: none,
  subtitle: none,
  title-note: none,
  subtitle-note: none,
  // Authors: a list of dicts. Each honors:
  //   name          (required) — the author's name, uppercased in the title block.
  //   orcid         — ORCID identifier or profile URL; links the visible author name.
  //   affiliation   — a dict (institution / city / state / country), or an array of
  //                   such dicts for multiple affiliations. All fields optional.
  //   email         — contact email.
  //   note          — a title footnote (e.g. "Both authors contributed equally").
  //   corresponding — true marks the corresponding author.
  // The email/affiliation declaration order is preserved in the contact line, as
  // acmart replays \email/\affiliation in source order (see normalize-author).
  authors: (),
  abstract: none,
  ccs: none,
  keywords: none,
  teaser: none,
  received: none,
  badges: none,
  // Multilingual papers (acmart `language` option, acmart.dtx:2847). `language` is
  // the document's MAIN language — a single babel language name (english, french,
  // german, spanish) — setting hyphenation + the language-dependent fixed strings
  // (keywords/acks/...). `translations` carries secondary-language top matter
  // (\translatedtitle etc., acmart.dtx:3362-3440): a dict keyed by language name,
  // each entry a dict of the translated fields (any of title/subtitle/keywords/
  // abstract), e.g. `translations: (french: (title: [...], abstract: [...]))`.
  // Secondary languages are exactly the keys used here; english is always available.
  language: none,
  translations: (:),
  // publication metadata. LaTeX-faithful defaults (acmart.dtx): \acmVolume{1},
  // \acmNumber{1}, \acmYear{\the\year}, \acmMonth{\the\month}. The system clock
  // (datetime.today) is only read when the date arg is omitted, so documents that
  // set the year/month stay reproducible.
  journal: none,
  acm-volume: 1,
  acm-number: 1,
  acm-article: none,
  acm-year: datetime.today().year(),
  acm-month: datetime.today().month(),
  doi: none,
  // Conference metadata (proceedings formats; acmart \acmConference / \acmBooktitle
  // / \acmISBN). `conference` is a dict (name / short / venue / date); the
  // conference copyright block prints "<short>, <venue>" (acmart.dtx:6620) and the
  // ISBN line (acmart.dtx:6654). Ignored by the journal formats.
  conference: none,
  booktitle: none,
  isbn: "978-x-xxxx-xxxx-x/YYYY/MM",
  // acmcp cover-page infobox content (acmart \acmCodeLink / \acmContributions,
  // acmart.dtx:5914/5929). Both optional; shown in the top-right logo box.
  code-data-link: none,
  contributions: none,
  // Logo at the top of the acmcp cover infobox, as content (e.g.
  // `acmcp-logo: image("jds-logo.png")`). REQUIRED by the acmcp format and by that
  // format only — the ACM journal logo is ACM's trademark, so it is not bundled;
  // supply your own. Taken as content, not a path string, because template file
  // paths resolve relative to the caller, not this package (see Typst's package docs).
  acmcp-logo: none,
  // acmengage front-matter metadata rows: an ordered list of (label, value) pairs,
  // each rendered as a bold label followed by its value (\@engagemetadata).
  engage-metadata: (),
  copyright: "acmlicensed",
  copyright-year: none,
  cc-type: "by",
  cc-version: "4.0",
  // \settopmatter keys (acmart.dtx:1076). print-acm-reference is acmart's
  // `printacmref` (the "ACM Reference Format" block); `auto` resolves to `not
  // nonacm` below (nonacm flips it off by default, re-enableable with
  // print-acm-reference: true).
  print-acm-reference: auto,
  print-ccs: true,
  print-folios: auto,
  // Bibliography engine, selecting which renderer the `bibliography` shadow and the
  // `@key`/`#cite` show rules route through:
  //   "bibtex"   (default) — pure-Typst port of ACM-Reference-Format.bst, matching
  //              LaTeX acmart's OWN default (natbib + \bibliographystyle{ACM-Reference-
  //              Format}); reads .bib with our own parser, bypassing hayagriva.
  //   "typst"    — native Typst bibliography() with Typst's built-in ACM CSL. Idiomatic
  //              (keeps native @key cross-reference links), but an APPROXIMATION bounded
  //              by hayagriva's BibTeX->CSL data mapping (see DESIGN.md for the gaps).
  //   "biblatex" — pure-Typst port of the ACM BibLaTeX acmnumeric/acmauthoryear styles.
  // On "bibtex"/"biblatex", in-text citations are not yet hyperlinked to the reference
  // list (planned); DOI/arXiv/URL links within reference entries still work.
  bib-backend: "bibtex",
  // Citation style for ACM bibliography backends, mirroring acmart's \citestyle:
  // "numeric" (default, "[N]") or "author-year" ("[Author Year]" + a/b/c years).
  cite-style: "numeric",
  // Override how the "bibtex" backend renders the RAW TeX of a reference field to
  // content: a function `(raw-tex: str) => content`. `auto` uses the built-in
  // renderer (accents/special letters/inline math -> Unicode, \url/\href ->
  // links, \emph -> italics). Compose with the default to extend it, e.g.
  //   tex-render: s => default-tex-render(s.replace("\\myunit", "kg"))
  // (import `default-tex-render` alongside `acmart`). Only the *presentation* is
  // overridable; sort/cite labels always use the built-in text normalization.
  tex-render: auto,
  short-title: auto,
  short-authors: auto,
  // --- acmart class & \settopmatter options ---
  // Implemented for the acmsmall (single-column journal) layout:
  review: false,          // line numbers in the margin + folios forced on
  screen: false,          // colour hyperlinks
  anonymous: false,       // blind-review author strip
  nonacm: false,          // drop the ACM journal footer + reference format
  author-version: false,  // authorversion: author's-version copyright block
  // timestamp: draft timestamp footer on the inner edge (acmart.dtx:7945). acmart
  // prints "<date> <HH>:<MM>. Page p of start--total."; Typst has no wall-clock
  // access, so we print the compile date (datetime.today) and omit the time.
  timestamp: false,
  author-draft: false,    // authordraft = timestamp + review + draft watermark/overlay
  submission-id: none,    // \acmSubmissionID — shown in the timestamp + anon. header
  start-page: none,       // \startPage — seeds the page counter (folios, timestamp range)
  // \thanks — content or array of contents; printed as unlabeled paragraphs at
  // the head of the authors-addresses footnote stream (each period-terminated;
  // anonymous replaces each with "A note", acmart.dtx:6417/7790).
  thanks: none,
  // \authorsaddresses override: `auto` derives "Authors' Contact Information:"
  // from the author dicts (the default); `none` suppresses the footnote
  // (LaTeX's \authorsaddresses{}); content replaces the whole block verbatim.
  authors-addresses: auto,
  // \acmConference editors (the conference ACM Reference Format block appends
  // ", E. One and E. Two (Eds.)." after the booktitle, acmart.dtx:7756).
  editors: (),
  // No effect outside their relevant formats — accepted for API parity (so
  // the names aren't forgotten) but inert here, exactly as in real acmart:
  //   balance/pbalance — column balancing, a two-column-only feature
  //   natbib           — selects the LaTeX citation package (bibliography is handled
  //                      by `bib-backend` here)
  //   authors-per-row  — only the conference author grid honours it (\@mkauthors@iii,
  //                      acmart.dtx:7448); acmsmall lists authors via \@mkauthors@i
  //   article-type     — the coloured banner is an acmcp feature
  //   acmthm           — suppresses the \newtheorem definitions; moot in Typst, where
  //                      the environments are opt-in functions with no namespace to clash
  balance: true,
  pbalance: false,
  natbib: true,
  authors-per-row: 0,
  article-type: "Research",
  acmthm: true,
  // Implemented: whether long URLs may break after a literal hyphen (acmart
  // \do@url@hyp, acmart.dtx:3631). Typst's line-breaker already breaks URLs at
  // hyphens, so `true` is native; `false` re-renders hyphens in link text as
  // U+2011 to forbid those breaks (see the `show link` rule below).
  url-break-on-hyphens: true,
  // Recognized but intentionally inert — and rejected (not silently ignored) so
  // the user isn't misled. `draft` only sets \overfullrule in acmart (a rule
  // marking overfull lines, acmart.dtx:2865); Typst has no equivalent, and no
  // custom-warning API to flag the gap, so a non-default value errors with that
  // rationale (see the assert below).
  draft: false,
  // Implemented: base font size, one of 8pt/9pt/10pt/11pt/12pt. `auto` uses the
  // format's own default (acmart.dtx:3063 — acmsmall/acmlarge/sigplan 10pt,
  // manuscript/acmtog/sigconf/… 9pt). Scales the typography via the amsart
  // \@typesizes ladder; geometry is font-size-independent (acmart.dtx:3750).
  font-size: auto,
  body,
) = {
  assert(
    format in _formats,
    message: "faithful-acmart: unknown format: " + format,
  )
  // The format entry is a builder; the base font size (8pt..12pt) parameterizes
  // the typography (it validates font-size and computes the size/baselineskip
  // ladder — geometry is font-size-independent, acmart.dtx:3750). `auto` defers
  // to the builder's own per-format default size.
  let cfg = if font-size == auto {
    (_formats.at(format))()
  } else {
    (_formats.at(format))(font-size: font-size)
  }

  // `draft` is recognized but has no faithful realization here: its sole effect
  // in acmart is to pass `draft` to amsart/article, which only sets
  // \overfullrule=5pt — a rule drawn beside overfull lines (acmart.dtx:2865).
  // Typst has no overfull-hbox concept or API to draw such markers (it reports
  // overflow as compiler warnings), and no custom-warning API to flag the gap at
  // compile time. Rather than accept it silently (which would let the user think
  // it did something), we reject it loudly with that rationale. Other options
  // that are simply inert in acmsmall (balance/pbalance/natbib/authors-per-row/
  // article-type/acmthm) genuinely produce identical output, so they stay
  // documented no-ops in the signature above; `draft` is different only in that
  // its non-default value is meant to be visible, and here it can't be.
  assert(
    draft == false,
    message: "faithful-acmart: option `draft` has no effect in this Typst port, so it is "
      + "rejected rather than silently ignored. In acmart `draft` only marks "
      + "overfull lines with a rule (acmart.dtx:2865); Typst has no equivalent "
      + "and instead reports overflow as compiler warnings. Remove `draft` to "
      + "compile.",
  )

  // \settopmatter{printacmref} defaults true; nonacm flips it off unless the
  // author forces it back on with print-acm-reference: true (acmart.dtx:2717). acmcp
  // also forces it off (\@ACM@printacmreffalse, acmart.dtx:3006).
  let print-acm-reference = if print-acm-reference == auto { not nonacm and cfg.name != "acmcp" } else { print-acm-reference }
  // authordraft turns on timestamp + review (acmart.dtx:2819-2820); resolve those
  // first so the downstream folio/line-number/footer logic sees the effective values.
  let timestamp = timestamp or author-draft
  let review = review or author-draft
  // \settopmatter{printfolios} defaults true for manuscript/journal/acmcp and
  // false for proceedings; review mode forces it on (acmart.dtx:5822-5828/2683).
  let print-folios = if print-folios == auto {
    cfg.kind != "proceedings"
  } else { print-folios }
  let print-folios = print-folios or review

  if cfg.name == "acmcp" {
    assert(article-type in _acmcp-article-types,
      message: "faithful-acmart: Article Type must be Research, Review, Discussion, Invited, or Position")
  }

  // Resolve the language: main lang code (hyphenation) + translated fixed
  // strings. Carried on cfg so every part (frontmatter, body captions, theorems
  // via cfg-state) reads one resolved string set.
  let lang = resolve-language(language)
  let cfg = cfg + (strings: (
    keywords: lang.keywords,
    keywords_proceedings: lang.keywords_proceedings,
    acks: lang.acks,
    proof: lang.proof,
    table: lang.table,
  ), lang: lang.code, bib-backend: bib-backend)
  assert(bib-backend in ("typst", "bibtex", "biblatex"),
    message: "faithful-acmart: `bib-backend` must be \"typst\", \"bibtex\", or \"biblatex\".")
  assert(cite-style in ("numeric", "author-year"),
    message: "faithful-acmart: `cite-style` must be \"numeric\" or \"author-year\".")
  assert(type(acm-month) == int and acm-month >= 1 and acm-month <= 12,
    message: "faithful-acmart: `acm-month` must be an integer 1..12; got " + repr(acm-month) + ".")
  cite-style-state.update(cite-style)
  // Always (re)publish the field renderer so a custom `tex-render` from an earlier
  // acmart scope can't leak into a later one that leaves it at `auto`.
  tex-render-state.update(_ => if tex-render == auto { default-tex-render } else { tex-render })

  // `translations` carries the secondary-language top matter, grouped by language:
  //   translations: (french: (title: [...], abstract: [...], keywords: (...)))
  // Validate each key is a supported language other than the main one, and each
  // entry uses only known fields; then pivot into the per-field ordered lists the
  // frontmatter renders (translated title/subtitle/keywords/abstract each live in a
  // different block). Field order across all blocks follows `translations` insertion
  // order (acmart's \selectlanguage sequence). english is always available as a key.
  let main-lang = if lang.main != none { lang.main } else { "english" }
  let _fields = ("title", "subtitle", "keywords", "abstract")
  for (l, entry) in translations {
    let _ = lang-record(l) // validate the language name
    assert(l != main-lang, message: "faithful-acmart: `translations` includes the main "
      + "language " + repr(l) + "; it is for OTHER languages (main is `language`).")
    for k in entry.keys() {
      assert(k in _fields, message: "faithful-acmart: `translations." + l + "` has unknown "
        + "field " + repr(k) + "; expected any of " + repr(_fields) + ".")
    }
  }
  let pick-translated(field) = translations.pairs()
    .filter(p => field in p.at(1))
    .map(p => (p.at(0), p.at(1).at(field)))
  let translated-title = pick-translated("title")
  let translated-subtitle = pick-translated("subtitle")
  let translated-keywords = pick-translated("keywords")
  let translated-abstract = pick-translated("abstract")

  // \copyrightyear defaults to \@acmYear; it can't be a signature default because
  // it references another parameter.
  let copyright-year = if copyright-year != none { copyright-year } else { acm-year }
  // Fill in optional author fields up front (see normalize-author).
  let authors = authors.map(normalize-author)

  // \@acmBooktitle defaults to "Proceedings of <conference name> (<short>)" when
  // not set explicitly, dropping the "(<short>)" when the name already is the
  // short name (acmart.dtx:5059). Resolve it once here so every consumer (the ACM
  // reference, the engage copyright line) sees the effective value.
  let booktitle = if booktitle != none {
    booktitle
  } else if conference != none and conference.at("name", default: none) != none {
    let nm = conference.name
    let sh = conference.at("short", default: none)
    if sh != none and sh != nm { [Proceedings of #nm (#sh)] } else { [Proceedings of #nm] }
  }

  let meta = (
    title: title,
    subtitle: subtitle,
    title-note: title-note,
    subtitle-note: subtitle-note,
    authors: authors,
    abstract: abstract,
    ccs: ccs,
    keywords: keywords,
    strings: cfg.strings,
    translated-title: translated-title,
    translated-subtitle: translated-subtitle,
    translated-keywords: translated-keywords,
    translated-abstract: translated-abstract,
    teaser: teaser,
    journal: journal,
    acm-volume: acm-volume,
    acm-number: acm-number,
    acm-article: acm-article,
    acm-year: acm-year,
    acm-month: acm-month,
    doi: doi,
    conference: conference,
    booktitle: booktitle,
    isbn: isbn,
    code-data-link: code-data-link,
    contributions: contributions,
    acmcp-logo: acmcp-logo,
    engage-metadata: engage-metadata,
    article-type: article-type,
    bibstrip: cfg.bibstrip,
    authors-per-row: authors-per-row,
    copyright: copyright,
    copyright-year: copyright-year,
    cc-type: cc-type,
    cc-version: cc-version,
    print-acm-reference: print-acm-reference,
    print-ccs: print-ccs,
    nonacm: nonacm,
    author-version: author-version,
    author-draft: author-draft,
    anonymous: anonymous,
    submission-id: submission-id,
    start-page: start-page,
    thanks: thanks,
    authors-addresses: authors-addresses,
    editors: editors,
  )

  let article-page(p) = {
    if acm-article != none {
      if print-folios [#acm-article:#p] else [#acm-article]
    } else if print-folios [#p]
  }
  let journal-footer = {
    let j = lookup-journal(journal)
    if not nonacm and (j.short != none or (cfg.name == "acmsmall" and conference != none)) {
      let prefix = if j.short != none { j.short } else { [] }
      let article = if acm-article != none or (cfg.name == "acmsmall" and conference != none) {
        [, Article #if acm-article != none { acm-article }]
      } else { [] }
      [#prefix, Vol. #acm-volume, No. #acm-number#article. Publication date: #pub-date(meta).]
    }
  }
  let manuscript-footer = if not nonacm [Manuscript submitted to ACM]
  let conference-line = {
    if cfg.name == "acmengage" {
      // \@formatdoi is \url{...} (acmart.dtx:6204), so the head DOI is a live
      // link, styled upright roman by acmengage's \urlstyle{rm}.
      [EngageCSEdu.#if doi != none { text(font: cfg.fonts.body)[ #link("https://doi.org/" + doi)[https:\/\/doi.org\/#doi]] }]
    } else if conference != none {
      let short = conference.at("short", default: conference.at("name", default: none))
      let date = conference.at("date", default: none)
      let venue = conference.at("venue", default: none)
      let parts = (short, date, venue).filter(x => x != none)
      if parts.len() > 0 { parts.join(", ") }
    }
  }
  let footer-row(l: none, c: none, r: none) = grid(
    columns: (1fr, auto, 1fr),
    align(left, l), align(center, c), align(right, r),
  )
  // Running footer. The ACM journal bibstrip sits on the OUTER edge (acmart
  // fancyfoot[RO,LE]): right on odd pages, left on even; nonacm suppresses it
  // (acmart.dtx:8198/8036). In timestamp/authordraft mode a draft timestamp sits
  // on the INNER edge (fancyfoot[LO,RE], acmart.dtx:8119/8245), opposite the
  // bibstrip. acmart's stamp is "<date> <HH>:<MM>. Page p of start--total."; Typst
  // can't read the wall clock, so we print the compile date and omit the time.
  let footer-content = context {
    set text(font: cfg.fonts.body, size: cfg.size.footnotesize)
    set par(leading: comp(cfg, sz: "footnotesize")) // multi-line footers on the footnotesize grid
    // Folio values and odd/even parity follow the page COUNTER (seeded by
    // \startPage), not the physical sheet index; the first-page dispatch is
    // physical (the title page carries firstpagestyle wherever it starts).
    let pageno = counter(page).get().first()
    let odd = calc.odd(pageno)
    let first-page = here().page() == 1
    let bib = if cfg.name == "acmcp" {
      let j = lookup-journal(journal)
      if j.short != none {
        [#j.name, Volume #acm-volume, Issue #acm-number#if acm-article != none [, Article #acm-article] (#pub-date(meta))#if doi != none { linebreak(); link("https://doi.org/" + doi)[https:\/\/doi.org\/#doi] }]
      }
    } else if cfg.name == "acmtog" and conference != none {
      // acmtog's conference footer ends with a period (acmart.dtx:8064:
      // "...\acmConference@venue.}"), unlike the running-head conference line.
      [#conference-line.]
    } else if cfg.name in ("acmsmall", "acmlarge", "acmtog") {
      journal-footer
    } else if cfg.name == "manuscript" {
      manuscript-footer
    }
    let folio = if print-folios { [#pageno] }
    if timestamp {
      let total = counter(page).final().first()
      let date = datetime.today().display("[year]-[month]-[day]")
      // \@startPage defaults to 1 (acmart.dtx:6823).
      let start = if start-page == none { 1 } else { start-page }
      let ts = [#if submission-id != none { [Submission ID: #submission-id. ] }#date. Page #pageno of #{start}--#{total}.]
      // manuscript page 1 appends the ACM slug to the stamp and keeps its outer
      // \small folio (acmart.dtx:8240-8244); on later pages the plain stamp
      // replaces the inner slug (acmart.dtx:8118). Proceedings keep their
      // centered folio next to the inner stamp (acmart.dtx:8233/8238).
      if cfg.name == "manuscript" {
        let ts = if first-page and not nonacm [#ts#h(1em)Manuscript submitted to ACM] else { ts }
        let folio = if first-page and folio != none { text(size: cfg.size.small, folio) }
        if odd { footer-row(l: ts, r: folio) } else { footer-row(l: folio, r: ts) }
      } else if cfg.kind == "proceedings" {
        if odd { footer-row(l: ts, c: folio) } else { footer-row(c: folio, r: ts) }
      } else if odd {
        // journal [LO] stamp, [RO] bibstrip
        grid(columns: (1fr, 1fr), align(left, ts), align(right, bib))
      } else {
        grid(columns: (1fr, 1fr), align(left, bib), align(right, ts))
      }
    } else if cfg.name == "acmcp" {
      // the only format with a foot rule: \footrulewidth = 0.1pt (acmart.dtx:
      // 8121/8249), \footruleskip (.3\normalbaselineskip) above the footer
      // text INK — measured 8.35tp above the first baseline in LaTeX. place()
      // keeps the rule out of the footer box so the descent math (single-line
      // baseline + multi-line centering) is unaffected.
      place(top + left, dy: -(8.35 * tp - cfg.size.footnotesize) - 0.1 * tp,
        line(length: 100%, stroke: 0.1 * tp))
      footer-row(r: bib)
    } else if cfg.name == "manuscript" and first-page {
      // manuscript's first-page folio is \small (acmart.dtx:8200), one step up
      // from the footnotesize slug next to it.
      let folio = if folio != none { text(size: cfg.size.small, folio) }
      if odd { footer-row(l: bib, r: folio) } else { footer-row(l: folio, r: bib) }
    } else if cfg.kind == "proceedings" {
      footer-row(c: folio)
    } else if bib != none {
      if odd { align(right, bib) } else { align(left, bib) }
    }
  }

  // Running head on continuation pages (page 1 uses no running head). acmsmall:
  //   even: [LE] article:page        [RE] short authors
  //   odd:  [LO] short title         [RO] article:page
  // in sans footnotesize (\@headfootfont).
  let st = if short-title == auto { title } else { short-title }
  // \shortauthors default = the full author names, andified (acmart.dtx:5215);
  // anonymous mode sets \shortauthors to "Anon." (acmart.dtx:5210/7966). Pass
  // `short-authors:` to override (the acmart `\author[short]{full}` mechanism).
  let sa = if anonymous {
    // anonymous header is "Anon." plus the submission id when given (acmart.dtx:7967).
    if submission-id != none [Anon. Submission Id: #submission-id] else [Anon.]
  } else if short-authors == auto {
    if authors.len() == 0 { none } else { andify(authors.map(a => a.name)) }
  } else { short-authors }
  let header-content = context {
    // Page 1 (the physical title page) has no running head, but may carry
    // artifact-evaluation badges (firstpagestyle: \@acmBadgeL/R).
    if here().page() <= 1 {
      if badges != none { return make-badges(cfg, badges) }
      return
    }
    // Folio values and parity follow the page counter (\startPage-aware).
    let p = counter(page).get().first()
    // Running head font: \@headfootfont = \sffamily\footnotesize for every format
    // EXCEPT manuscript, whose head carries no \@headfootfont and so prints in the
    // document default (serif) at normalsize (acmart.dtx:8024 vs 7979).
    let hf = if cfg.name == "manuscript" { (cfg.fonts.body, cfg.size.normalsize) } else { (cfg.fonts.sans, cfg.size.footnotesize) }
    set text(font: hf.first(), size: hf.last())
    let ap = article-page(p)
    let odd = calc.odd(p)
    let head = if cfg.name == "manuscript" {
      if odd { grid(columns: (1fr, auto), align(left, st), align(right, if print-folios { [#p] })) }
      else { grid(columns: (auto, 1fr), align(left, if print-folios { [#p] }), align(right, sa)) }
    } else if cfg.name == "acmsmall" {
      if odd { grid(columns: (1fr, auto), align(left, st), align(right, ap)) }
      else { grid(columns: (auto, 1fr), align(left, ap), align(right, sa)) }
    } else if cfg.name in ("acmlarge", "acmtog") {
      // \shorttitle\quad\textbullet\quad\@acmArticlePage (acmart.dtx:8042-8056):
      // a full 1em quad on each side of the bullet, not a word space.
      if odd { align(right, [#st#h(1em)•#h(1em)#ap]) }
      else { align(left, [#ap#h(1em)•#h(1em)#sa]) }
    } else if cfg.kind == "proceedings" {
      let conf = conference-line
      // sigchi-a is one-sided (landscape, fixed wide left margin): every page uses
      // the ODD proceedings head — shorttitle (left) + conference (right); the
      // \@shortauthors (RE) line never appears (acmart.dtx:8093/8109). The other
      // proceedings formats are two-sided and alternate authors/title by parity.
      if odd or cfg.name == "sigchi-a" {
        grid(columns: (1fr, 1fr), align(left, st), align(right, if not nonacm { conf }))
      } else {
        grid(columns: (1fr, 1fr), align(left, if not nonacm { conf }), align(right, sa))
      }
    } else {
      none
    }
    // \fancyheadoffset[L]: extend the head leftward into the margin column
    // (sigchi-a, acmart.dtx:8115) — the shorttitle starts over the margin notes.
    if cfg.head.offset != 0pt { pad(left: -cfg.head.offset, head) } else { head }
  }

  // Light-grey diagonal watermark (draftwatermark: 0.5in, gray 0.9). authordraft
  // stamps every page "Unpublished working draft." (acmart.dtx:3720-3726); sigchi-a
  // (unless nonacm) stamps the legacy notice instead (acmart.dtx:3728-3736).
  let watermark-text = if author-draft {
    [Unpublished working draft.\ Not for distribution.]
  } else if cfg.name == "sigchi-a" and not nonacm {
    // \parbox{12em}{\centering Legacy document. \\ Not for publication in an ACM
    // venue} (acmart.dtx:3733): "Legacy document." then the second line wraps in
    // the 12em box, breaking before "ACM venue".
    [Legacy document.\ Not for publication in an\ ACM venue]
  }
  let watermark = if watermark-text != none {
    rotate(-45deg, reflow: false, text(size: 0.5in, fill: luma(90%))[
      #set par(leading: 0.2em, justify: false)
      #align(center, watermark-text)
    ])
  }

  // acmcp rotated article-type label (\fancyhead[L], acmart.dtx:8253): a saturated
  // article-colour box reading bottom-to-top, offset 46pt into the left margin
  // (\fancyheadoffset[L]) so it sits at the page's left edge, level with the title.
  // The vertical position carries a -0.2\textheight*(nr-2) shift per article type
  // (Research nr=0 sits at the top margin; later types step down); only Research is
  // exercised by the twin, and it lands at the top margin as measured in LaTeX.
  let acmcp-label = if cfg.name == "acmcp" {
    let article = _acmcp-article-types.at(article-type)
    let textheight = cfg.paper.height - cfg.margin.top - cfg.margin.bottom
    // Read bottom-to-top (\rotatebox{90}); reflow:true so the placed footprint is
    // the rotated box and top+left anchors deterministically to the page corner.
    // \colorbox{...}{\color{white}\strut <Type> Article} at the head's normalsize
    // (9pt) in the document default family (serif for acmcp — no \sffamily), \fboxsep
    // (3pt) all round; \strut gives the box a full line's height (so extra space
    // perpendicular to the rotated text). top-edge/bottom-edge span the strut.
    let lbl = rotate(-90deg, reflow: true, box(fill: article.color, inset: 3 * tp,
      text(font: cfg.fonts.body, size: cfg.size.normalsize, fill: white,
        top-edge: "ascender", bottom-edge: "descender")[#article-type Article]))
    context place(top + left, dx: 0pt,
      // Centre on the title (\fancyhead[L] level with the head); step later article
      // types down by 0.2\textheight per nr (Research nr=0 sits at the top margin).
      dy: cfg.margin.top - measure(lbl).height / 2 + 0.2 * textheight * article.nr,
      lbl)
  }

  // `review`: acmart stamps a fixed red \scriptsize RULER in the margins — one
  // number per UNSTRETCHED normalsize \baselineskip covering \textheight
  // (\ACM@mk@linecount, acmart.dtx:7853-7928: ceil(th/bls)+1 numbers per box,
  // measured 52/58 per page on manuscript/sigconf), numbered continuously
  // across pages. Two-column formats and sigchi-a build a SECOND, continuing
  // box on the right (\ACM@linecountR). The numbers are slots, not text lines:
  // they advance across headings, floats, and whitespace. Measured anchors:
  // first baseline at margin.top + 8.43tp; x = left margin − 26pt / right
  // margin edge + 20pt (\put(-26,-22)/(20,-22) from the head corners).
  let review-ruler = if review { context {
    let th = cfg.paper.height - cfg.margin.top - cfg.margin.bottom
    let bls = cfg.at("baselineskip-unstretched")
    let n = calc.ceil(th / bls) + 1
    let two-sided-ruler = cfg.columns == 2 or cfg.name == "sigchi-a"
    let pg = here().page() - 1
    let start = pg * (if two-sided-ruler { 2 * n } else { n }) + 1
    // this page's physical left/right margins (inside/outside alternate)
    let odd = calc.odd(here().page())
    let ml = cfg.margin.at("left", default: if odd { cfg.margin.at("inside", default: 0pt) } else { cfg.margin.at("outside", default: 0pt) })
    let mr = cfg.margin.at("right", default: if odd { cfg.margin.at("outside", default: 0pt) } else { cfg.margin.at("inside", default: 0pt) })
    let ruler(first) = text(fill: rgb(255, 0, 0), size: cfg.size.scriptsize,
      top-edge: 1em, bottom-edge: 0pt,
      {
        set par(leading: bls - cfg.size.scriptsize, justify: false)
        range(first, first + n).map(str).join(linebreak())
      })
    let dy = cfg.margin.top + 8.43 * tp - cfg.size.scriptsize
    place(top + left, dx: ml - 26 * tp, dy: dy, ruler(start))
    if two-sided-ruler {
      place(top + left, dx: cfg.paper.width - mr + 20 * tp, dy: dy, ruler(start + n))
    }
  } }

  set page(
    width: cfg.paper.width,
    height: cfg.paper.height,
    margin: cfg.margin,
    columns: cfg.columns, // proceedings/acmtog set 2 (acmart.dtx:6849 \twocolumn)
    // fancyhdr sets the head on a \strut whose depth (.3\baselineskip of the
    // head font) hangs below the head baseline, so the baseline sits
    // headsep + .3bls above the body top (measured: the old leading-based
    // model left heads 1-1.4pt low). manuscript's head is normalsize serif.
    header-ascent: cfg.head.sep + 0.3 * (if cfg.name == "manuscript" { cfg.bls.normalsize } else { cfg.bls.at("footnotesize") }),
    // The footer's FIRST baseline sits \footskip below the body — verified
    // exact for every format, including acmcp's two-line footer (journal line
    // + DOI, acmart.dtx:8264), whose second line simply hangs one footnotesize
    // baselineskip lower in both engines (measured 677.5/685.7 = body +
    // \footskip + n·bls on acmcp-test).
    footer-descent: cfg.foot.skip - cfg.size.footnotesize,
    header: header-content,
    footer: footer-content,
    background: {
      acmcp-label
      if review-ruler != none { review-ruler }
      if watermark != none { align(center + horizon, watermark) }
    },
  )
  // Exact inter-column gutter (\columnsep; acmart sets 24pt/2pc). Typst's page
  // `columns` otherwise defaults to a 4%-of-width gutter. A no-op for the
  // single-column formats (no columns element is split), so set unconditionally
  // — a `set` inside an `if` would only scope to that block, not the body.
  set columns(gutter: cfg.columnsep)

  // Pin the line box to the font size (top-edge - bottom-edge = 1em) so that the
  // baseline-to-baseline distance is font-metric-independent and equals
  //   leading + 1em = (baselineskip - font-size) + font-size = baselineskip,
  // matching TeX's rigid \baselineskip. top-edge = 1em also puts the first
  // baseline at `top margin + \topskip`, as LaTeX does.
  set text(
    // sigchi-a sets the sans family as the document default (acmart.dtx:4073).
    font: cfg.fonts.body, // sans under sans-default (sigchi-a), else serif
    size: cfg.font-size,
    top-edge: 1em,
    bottom-edge: 0pt,
    lang: cfg.lang, // main language (acmart `language`); drives hyphenation
  )
  show math.equation: set text(font: cfg.fonts.math)

  set par(
    leading: comp(cfg), // intra-paragraph: baseline pitch = baselineskip
    first-line-indent: (amount: cfg.parindent, all: false),
    spacing: tex-skip(cfg, cfg.parskip), // inter-paragraph = parskip (0) above one baselineskip step
    justify: true,
  )

  set heading(numbering: cfg.heading-numbering)
  show heading: it => {
    // theorems are numbered within \thesection: the reset fires when the
    // SECTION COUNTER steps, so unnumbered sections (\section*, acks,
    // References) leave the theorem counter alone.
    if it.level == 1 and it.numbering != none { thm-counter.update(0) }
    render-heading(it, cfg)
  }

  // `screen`: colour hyperlinks (acmart ACMPurple for refs/cites, ACMDarkBlue
  // for URLs). Without it, links stay black as in print acmart.
  let acm-purple = cmyk(55%, 100%, 0%, 15%)
  let acm-dark-blue = cmyk(100%, 58%, 0%, 21%)
  let colorize = (dest, body) => {
    // \urlstyle{sf} (sigplan/sigchi-a, acmart.dtx:3623): URL links set in sans.
    // \urlstyle only restyles \url; \href display text (the mailto author emails)
    // keeps the ambient font, so exclude mailto: targets from the sans switch.
    let is-url = type(dest) == str and not dest.starts-with("mailto:")
    let body = if cfg.urlstyle-sans and is-url { text(font: cfg.fonts.sans, body) } else { body }
    if screen {
      text(fill: if type(dest) == str { acm-dark-blue } else { acm-purple }, body)
    } else { body }
  }
  // `url-break-on-hyphens` (default true): acmart adds `-` to hyperref's URL break
  // set (\do@url@hyp, acmart.dtx:3631), and Typst's line-breaker already breaks
  // URLs after hyphens — so the default needs nothing and stays the plain `it`.
  // When false, re-render literal hyphens in the link text as U+2011 (a
  // non-breaking hyphen, visually identical) to forbid those breaks, while `/`
  // and `.` stay breakable, exactly as acmart's `urlbreakonhyphens=false`.
  show link: it => if url-break-on-hyphens {
    colorize(it.dest, it)
  } else {
    // Transform `it` in place (a nested string show rule); reconstructing a
    // `link` element here would re-trigger this rule and recurse.
    colorize(it.dest, { show "-": "\u{2011}"; it })
  }

  // Route bare `@key` (Typst syntax, a `ref` element — not shadowable) through the
  // ACM engine, the way alexandria/pergamon hook native citations. A `ref` whose
  // target resolves to no document label (`it.element == none`) is a citation;
  // figures/headings/equations (a real element) pass through unchanged. For the
  // "typst" backend the rule is the identity, leaving native `@key` untouched.
  // Explicit `#cite(...)` is handled by the `cite` shadow (above), and the reference
  // LIST by the `bibliography` shadow: Typst validates a native `#bibliography`
  // source through hayagriva at element construction — before any show rule could
  // fire — so shadowing the name is the only way to bypass hayagriva for the
  // bibtex/biblatex backends.
  show ref: it => if bib-backend != "typst" and it.element == none {
    bbl-cite(str(it.target))
  } else { it }


  cfg-state.update(cfg) // publish config for theorem environments
  anon-state.update(anonymous) // publish anonymity for the acks environment
  if start-page != none {
    // \startPage seeds the page counter (acmart.dtx:6822-6825): folios, parity,
    // and the timestamp range all follow it.
    assert(type(start-page) == int and start-page >= 1,
      message: "faithful-acmart: option `start-page` must be a positive integer, got " + repr(start-page))
    counter(page).update(start-page)
  }

  // review/nonacm flip the class's list geometry to amsart's values (an
  // upstream hook-ordering bug the port replicates; see parts/body.typ).
  apply-body(cfg, amsart-lists: review or nonacm, {
    if meta.title != none {
      // Page-1 footnote stack (author notes / contact info / copyright). A
      // place(bottom, float) — full-width in one column, first-column-scoped in two
      // (the conference \footnotetextcopyrightpermission block, acmart.dtx:6605).
      make-footnotes(cfg, meta)
      if cfg.columns > 1 {
        // \twocolumn[\box\mktitle@bx] (acmart.dtx:6849): only the title/author box
        // spans both columns; the abstract/CCS/keywords (\@mkabstract et seq.,
        // acmart.dtx:6665) follow it in the FIRST column. scope: "parent" escapes the
        // column to span the full text width; clearance is the box's trailing
        // skip before the columns start — the author grid's \par\bigskip
        // (acmart.dtx:7503), or \@mkteasers' closing \medskip when a teaser is
        // the box's last element (acmart.dtx:7670).
        // The head must be pinned to the FULL text width: \@mktitle@iii sets the
        // title box \hsize=\textwidth and centres over it (acmart.dtx:7018/7499).
        // Without the explicit width, Typst shrink-wraps the placed float to its
        // widest child — an author-grid row is (textwidth − 2·author@bx@sep) wide
        // — and left-anchors it, shifting the centred title/authors 1pc left.
        place(top, scope: "parent", float: true,
          clearance: tex-skip(cfg, if teaser != none { cfg.medskip } else { cfg.bigskip }),
          block(width: 100%, spacing: 0pt, make-title-head(cfg, meta)))
        make-title-body(cfg, meta) // flows in column 1, beneath the spanning box
      } else {
        // acmcp narrows the TITLE box and the author lines by 6pc
        // (\@mktitle@i / \@mkauthors@i, acmart.dtx:6988/7364); the abstract
        // stays full width. Other formats: nothing to narrow.
        make-title(cfg, meta)
      }
    } else if _body-starts-with-paragraph(body) {
      // Titleless document opening with a paragraph: LaTeX indents it (nothing
      // fired \@afterindentfalse). A GLUED h() (no paragraph break) becomes that
      // paragraph's first-line indent with zero vertical cost — a leading empty
      // paragraph would instead add one line's leading. Guarded by the paragraph-
      // first test so a heading/figure/list-first body is untouched.
      h(cfg.parindent)
    }

    if cfg.name == "acmcp" {
      // The body sits on a light tint of the article colour (\@ACM@color@frame,
      // acmart.dtx:5899: \colorbox{@ACM@Article@color!10!white}), the hsize reduced
      // 6.5pc on the right (acmart.dtx:5902) to clear the top-right cover infobox.
      // ONLY the body is tinted — title/authors/abstract above stay on white. The
      // infobox (JDS logo + code/data, keywords, contributions, contact info;
      // \set@ACM@acmcpbox, acmart.dtx:6724) is bottom-aligned in the right column,
      // matching LaTeX's zref feedback that butts the infobox bottom against the
      // frame bottom. acmcp is a single-page cover format, so keeping the framed
      // body in one grid cell is acceptable.
      let article = _acmcp-article-types.at(article-type)
      let tint = article.color.lighten(90%)
      let fbox = 3 * tp // \fboxsep
      let body-reduction = 6.5 * 12 * tp // \advance\hsize -6.5pc (acmart.dtx:5902)
      let framed-body = pad(left: -fbox, block(
        fill: tint,
        inset: fbox,
        width: 100% + 2 * fbox,
        body,
      ))
      block(width: 100%, breakable: false, spacing: 0pt, grid(
        columns: (1fr, body-reduction),
        column-gutter: 0pt,
        grid.cell(align: top + left)[#framed-body],
        grid.cell(align: bottom + right)[#make-acmcp-infobox(cfg, meta)],
      ))
    } else {
      body
    }

    // \received history line, printed last (acmart \AtEndDocument).
    if received != none { make-received(cfg, received) }
  })
}
