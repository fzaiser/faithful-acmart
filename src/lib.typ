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
// All public acmart formats are accepted (resolved in parts/options.typ): the single-column
// journals (manuscript/acmsmall/acmlarge), the two-column journal (acmtog), the
// two-column proceedings (sigconf/sigplan/acmengage), obsolete siggraph/sigchi
// aliases to sigconf, and bespoke sigchi-a (landscape) / acmcp (cover page).

#import "formats/_base.typ": tp
#import "parts/spacing.typ": comp, tex-skip
#import "parts/headings.typ": render-heading, _in-heading, _body-since-heading
#import "parts/frontmatter.typ": make-title, make-title-head, make-title-body, make-footnotes, make-acmcp-infobox, make-received
#import "parts/metadata.typ": resolve-metadata
#import "parts/options.typ": resolve-options
#import "parts/page-chrome.typ": make-page-chrome
#import "parts/body.typ": apply-body, sidebar, marginfigure, margintable, fulltextwidth
#import "parts/tables.typ": tabular, toprule, midrule, bottomrule
#import "parts/theorems.typ": cfg-state, anon-state, thm-counter
#import "parts/theorems.typ": theorem, lemma, corollary, proposition, conjecture, definition, example, remark, proof, acks
#import "parts/acmref.typ": bbl-cite, bbl-citet, bbl-citealt, bbl-citeyear, bbl-citeyearpar, bbl-citeauthor, bbl-shortcite, bbl-bibliography, cite-style-state, tex-render-state
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
  // `supplement: [p. 5]` (natbib's postnote) is forwarded to both backends —
  // rendered as "[1, p. 5]" through the ACM engine (notesep ", ", dtx:3272).
  let named = args.named()
  if cfg == none or cfg.bib-backend == "typst" {
    keys.map(k => std.cite(_cite-label(k), ..named)).join()
  } else {
    bbl-cite(..keys.map(str), ..named)
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
// Further natbib variants faithful to acmart's setup:
//   cite-alt     — "Author Year"/"Author [N]" with no brackets   (\citealt)
//   cite-yearpar — the year/number in brackets                   (\citeyearpar)
//   short-cite   — \cite in numeric mode, \citeyearpar in a-year (\shortcite, dtx:3670)
#let cite-alt = _cite-variant(bbl-citealt, "prose")
#let cite-yearpar = _cite-variant(bbl-citeyearpar, "year")
#let short-cite = _cite-variant(bbl-shortcite, "normal")
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

#let acmart(
  format: "manuscript",
  title: none,
  subtitle: none,
  title-note: none,
  subtitle-note: none,
  // Authors: a list of dicts. Each honors:
  //   name          (required) — the author's name, uppercased in the title block.
  //   orcid         — ORCID identifier or profile URL; links the visible author name.
  //   affiliation   — a dict (institution / city / state / country), or an array of
  //                   such dicts for multiple affiliations. As in acmart, country is
  //                   required whenever an affiliation is supplied.
  //   email         — contact email.
  //   note          — a title footnote, or an array of title footnotes; identical
  //                   note content is shared across authors.
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
  doi: "10.1145/nnnnnnn.nnnnnnn",
  // Conference metadata (proceedings formats; acmart \acmConference / \acmBooktitle
  // / \acmISBN). `conference` is a dict (name / short / venue / date); the
  // conference copyright block prints "<short>, <venue>" (acmart.dtx:6620) and the
  // ISBN line (acmart.dtx:6654). `auto` uses acmart's placeholder conference for
  // proceedings formats and none for journal/manuscript formats.
  conference: auto,
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
  // On "bibtex"/"biblatex", in-text citations link to the rendered reference entries;
  // DOI/arXiv/URL links within reference entries work as external links.
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
  let options = resolve-options((
    format: format,
    font-size: font-size,
    draft: draft,
    print-acm-reference: print-acm-reference,
    nonacm: nonacm,
    author-draft: author-draft,
    timestamp: timestamp,
    review: review,
    print-folios: print-folios,
    language: language,
    bib-backend: bib-backend,
    cite-style: cite-style,
    acm-month: acm-month,
    article-type: article-type,
  ))
  let cfg = options.cfg
  let print-acm-reference = options.print-acm-reference
  let timestamp = options.timestamp
  let review = options.review
  let print-folios = options.print-folios

  cite-style-state.update(cite-style)
  // Always (re)publish the field renderer so a custom `tex-render` from an earlier
  // acmart scope can't leak into a later one that leaves it at `auto`.
  tex-render-state.update(_ => if tex-render == auto { default-tex-render } else { tex-render })

  let metadata = resolve-metadata(cfg, options.lang, (
    title: title,
    subtitle: subtitle,
    title-note: title-note,
    subtitle-note: subtitle-note,
    authors: authors,
    abstract: abstract,
    ccs: ccs,
    keywords: keywords,
    translations: translations,
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
  ))
  let meta = metadata.meta
  let screen = screen or metadata.force-screen
  // Typst has no native document subject field for CCS concepts; publish the
  // string-valued title, author, and keyword subset that its PDF metadata supports.
  set document(title: title, author: metadata.document.authors,
    keywords: metadata.document.keywords)

  let chrome = make-page-chrome(cfg, meta, (
    print-folios: print-folios,
    timestamp: timestamp,
    review: review,
    short-title: short-title,
    short-authors: short-authors,
    badges: badges,
    article-type: article-type,
    article: options.article,
  ))

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
    header: chrome.header,
    footer: chrome.footer,
    background: chrome.background,
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
  // Track whether ordinary body text has appeared since the last heading, for the
  // kernel's `\if@nobreak` beforeskip suppression and the run-in's ambient indent
  // (parts/headings.typ). Guarded by `_in-heading` so a heading's own number/title
  // paragraph doesn't register as intervening body text.
  show par: it => { context { if not _in-heading.get() { _body-since-heading.update(true) } }; it }

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


  // review/nonacm flip the class's list geometry to amsart's values (an upstream
  // hook-ordering bug; see parts/body.typ). The proof environment's label
  // separation follows the same flag (trivlist \labelsep 4pt vs amsart 5pt), so
  // publish it on cfg for parts/theorems.typ.
  let amsart-lists = review or nonacm
  cfg-state.update(cfg + (amsart-lists: amsart-lists)) // publish config for theorem environments
  anon-state.update(anonymous) // publish anonymity for the acks environment
  if start-page != none {
    // \startPage seeds the page counter (acmart.dtx:6822-6825): folios, parity,
    // and the timestamp range all follow it.
    assert(type(start-page) == int and start-page >= 1,
      message: "faithful-acmart: option `start-page` must be a positive integer, got " + repr(start-page))
    counter(page).update(start-page)
  }

  apply-body(cfg, amsart-lists: amsart-lists, {
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
      let article = options.article
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
