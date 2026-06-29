// typst-acmart — a Typst port of the LaTeX acmart class.
//
// Public entry point: apply with a show rule, e.g.
//   #import "@preview/acmart:0.0.1": acmart
//   #show: acmart.with(format: "acmsmall", title: [...], ...)
//
// Status: early. Only the `acmsmall` format is implemented, and only page
// geometry + body typography so far (Phase 1/2). Title block, theorems, floats,
// and bibliography styling come later.

#import "formats/acmsmall.typ": acmsmall
#import "formats/manuscript.typ": manuscript
#import "formats/acmlarge.typ": acmlarge
#import "formats/acmtog.typ": acmtog
#import "formats/sigconf.typ": sigconf
#import "formats/siggraph.typ": siggraph
#import "formats/sigchi.typ": sigchi
#import "formats/sigplan.typ": sigplan
#import "formats/acmengage.typ": acmengage
#import "formats/sigchi-a.typ": sigchia
#import "formats/acmcp.typ": acmcp
#import "parts/spacing.typ": comp, tex-skip
#import "parts/headings.typ": render-heading
#import "parts/frontmatter.typ": make-title, make-title-head, make-title-body, make-footnotes, make-received, make-badges, lookup-journal, pub-date, andify, normalize-author
#import "parts/body.typ": apply-body
#import "parts/strings.typ": resolve-language, lang-record
#import "parts/theorems.typ": cfg-state, anon-state, thm-counter
#import "parts/theorems.typ": theorem, lemma, corollary, proposition, conjecture, definition, example, remark, proof, acks

#let _formats = (
  manuscript: manuscript,
  acmsmall: acmsmall,
  acmlarge: acmlarge,
  acmtog: acmtog,
  sigconf: sigconf,
  siggraph: siggraph,
  sigchi: sigchi,
  sigplan: sigplan,
  acmengage: acmengage,
  "sigchi-a": sigchia,
  acmcp: acmcp,
)

#let acmart(
  format: "acmsmall",
  title: none,
  subtitle: none,
  title-note: none,
  subtitle-note: none,
  authors: (),
  abstract: none,
  ccs: none,
  keywords: none,
  teaser: none,
  received: none,
  badges: none,
  // Multilingual papers (acmart `language` option, acmart.dtx:2847). A babel
  // language name or an ordered list whose LAST entry is the main language;
  // sets hyphenation + the language-dependent fixed strings (keywords/acks/...).
  // Supported: english, french, german, spanish. The translated-* arguments give
  // secondary-language top matter (\translatedtitle etc., acmart.dtx:3362-3440):
  // each is a dict keyed by language name -> content.
  language: none,
  translated-title: (:),
  translated-subtitle: (:),
  translated-keywords: (:),
  translated-abstract: (:),
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
  isbn: none,
  copyright: "acmlicensed",
  copyright-year: none,
  cc-type: "by",
  cc-version: "4.0",
  // \settopmatter keys (acmart.dtx:1076). show-ref is acmart's `printacmref`;
  // `auto` resolves to `not nonacm` below (nonacm flips the bibstrip off by
  // default, re-enableable with show-ref: true).
  show-ref: auto,
  print-ccs: true,
  print-folios: true,
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
  // No effect in the single-column acmsmall layout — accepted for API parity (so
  // the names aren't forgotten) but inert here, exactly as in real acmart:
  //   balance/pbalance — column balancing, a two-column-only feature
  //   natbib           — selects the LaTeX citation package (bibliography is CSL here)
  //   authors-per-row  — only the conference author grid honours it (\@mkauthors@iii,
  //                      acmart.dtx:7448); acmsmall lists authors via \@mkauthors@i
  //   article-type     — the coloured banner is an acmcp/acmengage feature
  //   acmthm           — suppresses the \newtheorem definitions; moot in Typst, where
  //                      the environments are opt-in functions with no namespace to clash
  balance: true,
  pbalance: false,
  natbib: true,
  authors-per-row: 0,
  article-type: none,
  acmthm: true,
  // Implemented: whether long URLs may break after a literal hyphen (acmart
  // \do@url@hyp, acmart.dtx:3631). Typst's line-breaker already breaks URLs at
  // hyphens, so `true` is native; `false` re-renders hyphens in link text as
  // U+2011 to forbid those breaks (see the `show link` rule below).
  urlbreakonhyphens: true,
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
    message: "unknown/unimplemented acmart format: " + format,
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
    message: "acmart: option `draft` has no effect in this Typst port, so it is "
      + "rejected rather than silently ignored. In acmart `draft` only marks "
      + "overfull lines with a rule (acmart.dtx:2865); Typst has no equivalent "
      + "and instead reports overflow as compiler warnings. Remove `draft` to "
      + "compile.",
  )

  // \settopmatter{printacmref} defaults true; nonacm flips it off unless the
  // author forces it back on with show-ref: true (acmart.dtx:2717). acmcp also
  // forces it off (\@ACM@printacmreffalse, acmart.dtx:3006).
  let show-ref = if show-ref == auto { not nonacm and cfg.name != "acmcp" } else { show-ref }
  // authordraft turns on timestamp + review (acmart.dtx:2819-2820); resolve those
  // first so the downstream folio/line-number/footer logic sees the effective values.
  let timestamp = timestamp or author-draft
  let review = review or author-draft
  // review mode forces folios on (acmart.dtx:2683, \@ACM@printfoliostrue).
  let print-folios = print-folios or review

  // Resolve the language: main lang code (hyphenation) + translated fixed
  // strings. Carried on cfg so every part (frontmatter, body captions, theorems
  // via cfg-state) reads one resolved string set.
  let lang = resolve-language(language)
  let cfg = cfg + (strings: (keywords: lang.keywords, acks: lang.acks,
    proof: lang.proof, table: lang.table), lang: lang.code)

  // The translated-* top matter requires `language` (acmart \ACM@lang@check,
  // acmart.dtx:3346) — a secondary-language block is meaningless monolingual.
  // Normalize each to an ordered (lang, content) list and check the language is
  // declared, mirroring babel's \selectlanguage.
  let norm-translated(name, val) = {
    if val == none or val == (:) { return () }
    assert(language != none, message: "acmart: `" + name + "` needs the "
      + "`language` option set (it typesets secondary-language top matter).")
    for (l, content) in val {
      let _ = lang-record(l) // validate the language name
      assert(l in lang.all, message: "acmart: `" + name + "` uses language "
        + repr(l) + ", which is not in `language` " + repr(lang.all) + ".")
    }
    val.pairs()
  }
  let translated-title = norm-translated("translated-title", translated-title)
  let translated-subtitle = norm-translated("translated-subtitle", translated-subtitle)
  let translated-keywords = norm-translated("translated-keywords", translated-keywords)
  let translated-abstract = norm-translated("translated-abstract", translated-abstract)

  // \copyrightyear defaults to \@acmYear; it can't be a signature default because
  // it references another parameter.
  let copyright-year = if copyright-year != none { copyright-year } else { acm-year }
  // Fill in optional author fields up front (see normalize-author).
  let authors = authors.map(normalize-author)

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
    conf-footer: cfg.conf-footer,
    bibstrip: cfg.bibstrip,
    authors-per-row: authors-per-row,
    copyright: copyright,
    copyright-year: copyright-year,
    cc-type: cc-type,
    cc-version: cc-version,
    show-ref: show-ref,
    print-ccs: print-ccs,
    nonacm: nonacm,
    author-version: author-version,
    author-draft: author-draft,
    anonymous: anonymous,
  )

  // Running footer. The ACM journal bibstrip sits on the OUTER edge (acmart
  // fancyfoot[RO,LE]): right on odd pages, left on even; nonacm suppresses it
  // (acmart.dtx:8198/8036). In timestamp/authordraft mode a draft timestamp sits
  // on the INNER edge (fancyfoot[LO,RE], acmart.dtx:8119/8245), opposite the
  // bibstrip. acmart's stamp is "<date> <HH>:<MM>. Page p of start--total."; Typst
  // can't read the wall clock, so we print the compile date and omit the time.
  let footer-content = context {
    set text(font: cfg.fonts.serif, size: cfg.size.footnotesize)
    let odd = calc.odd(here().page())
    let j = lookup-journal(journal)
    // \@acmArticle defaults to empty (acmart.dtx:5477), so the article number may
    // be absent (#acm-article renders nothing for none).
    let bib = if not nonacm and j.short != none {
      [#j.short, Vol. #acm-volume, No. #acm-number, Article #acm-article. Publication date: #pub-date(meta).]
    }
    if timestamp {
      let total = counter(page).final().first()
      let date = datetime.today().display("[year]-[month]-[day]")
      // \@startPage defaults to 1 (acmart.dtx:6823).
      let ts = [#if submission-id != none { [Submission ID: #submission-id. ] }#date. Page #here().page() of 1--#total.]
      // inner edge [LO,RE]: odd -> left, even -> right (bibstrip takes the other side)
      if odd { grid(columns: (1fr, 1fr), align(left, ts), align(right, bib)) }
      else { grid(columns: (1fr, 1fr), align(left, bib), align(right, ts)) }
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
    let p = here().page()
    // Page 1 has no running head, but may carry artifact-evaluation badges
    // (acmart firstpagestyle: \@acmBadgeL left, \@acmBadgeR right).
    if p <= 1 {
      if badges != none { return make-badges(cfg, badges) }
      return
    }
    set text(font: cfg.fonts.sans, size: cfg.size.footnotesize)
    // \@acmArticlePage (acmart.dtx:8014): "<article>:<page>", dropping ":<page>"
    // when folios are off, and the article number itself when it is empty.
    let article-page = if acm-article != none {
      if print-folios [#acm-article:#p] else [#acm-article]
    } else if print-folios [#p]
    if calc.odd(p) {
      grid(columns: (1fr, auto), align(left, st), align(right, article-page))
    } else {
      grid(columns: (auto, 1fr), align(left, article-page), align(right, sa))
    }
  }

  // authordraft stamps every page with a light-grey diagonal watermark
  // (draftwatermark: 0.5in, gray 0.9; acmart.dtx:3720-3726).
  let watermark = if author-draft {
    rotate(-45deg, reflow: false, text(size: 0.5in, fill: luma(90%))[
      #set par(leading: 0.2em, justify: false)
      #align(center)[Unpublished working draft.\ Not for distribution.]
    ])
  }

  set page(
    width: cfg.paper.width,
    height: cfg.paper.height,
    margin: cfg.margin,
    columns: cfg.columns, // proceedings/acmtog set 2 (acmart.dtx:6849 \twocolumn)
    header-ascent: cfg.head.sep + comp(cfg, sz: "footnotesize"),
    footer-descent: cfg.foot.skip - cfg.size.footnotesize,
    header: header-content,
    footer: footer-content,
    background: if watermark != none { align(center + horizon, watermark) },
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
    font: if cfg.sans-default { cfg.fonts.sans } else { cfg.fonts.serif },
    size: cfg.font-size,
    top-edge: 1em,
    bottom-edge: 0pt,
    lang: cfg.lang, // main language (acmart `language`); drives hyphenation
  )

  set par(
    leading: comp(cfg), // intra-paragraph: baseline pitch = baselineskip
    first-line-indent: (amount: cfg.parindent, all: false),
    spacing: tex-skip(cfg, cfg.parskip), // inter-paragraph = parskip (0) above one baselineskip step
    justify: true,
  )

  set heading(numbering: cfg.heading-numbering)
  show heading: it => {
    if it.level == 1 { thm-counter.update(0) } // theorems numbered within section
    render-heading(it, cfg)
  }

  // `screen`: colour hyperlinks (acmart ACMPurple for refs/cites, ACMDarkBlue
  // for URLs). Without it, links stay black as in print acmart.
  let acm-purple = cmyk(55%, 100%, 0%, 15%)
  let acm-dark-blue = cmyk(100%, 58%, 0%, 21%)
  let colorize = (dest, body) => {
    // \urlstyle{sf} (sigplan/sigchi-a, acmart.dtx:3623): URL links set in sans.
    let body = if cfg.urlstyle-sans and type(dest) == str { text(font: cfg.fonts.sans, body) } else { body }
    if screen {
      text(fill: if type(dest) == str { acm-dark-blue } else { acm-purple }, body)
    } else { body }
  }
  // `urlbreakonhyphens` (default true): acmart adds `-` to hyperref's URL break
  // set (\do@url@hyp, acmart.dtx:3631), and Typst's line-breaker already breaks
  // URLs after hyphens — so the default needs nothing and stays the plain `it`.
  // When false, re-render literal hyphens in the link text as U+2011 (a
  // non-breaking hyphen, visually identical) to forbid those breaks, while `/`
  // and `.` stay breakable, exactly as acmart's `urlbreakonhyphens=false`.
  show link: it => if urlbreakonhyphens {
    colorize(it.dest, it)
  } else {
    // Transform `it` in place (a nested string show rule); reconstructing a
    // `link` element here would re-trigger this rule and recurse.
    colorize(it.dest, { show "-": "\u{2011}"; it })
  }

  // `review`: number every line in the left margin (acmart uses \color{red}
  // \scriptsize — 7pt at this base size; acmart.dtx:7862).
  set par.line(numbering: if review {
    n => text(fill: red, size: cfg.size.scriptsize)[#n]
  } else { none })

  cfg-state.update(cfg) // publish config for theorem environments
  anon-state.update(anonymous) // publish anonymity for the acks environment

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
      // \par\bigskip before the columns start.
      place(top, scope: "parent", float: true, clearance: tex-skip(cfg, cfg.bigskip),
        make-title-head(cfg, meta))
      make-title-body(cfg, meta) // flows in column 1, beneath the spanning box
    } else {
      make-title(cfg, meta)
    }
  }

  apply-body(cfg, body)

  // \received history line, printed last (acmart \AtEndDocument).
  if received != none { make-received(cfg, received) }
}
