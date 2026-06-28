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
#import "parts/spacing.typ": comp, tex-skip
#import "parts/headings.typ": render-heading
#import "parts/frontmatter.typ": make-title, make-footnotes, make-received, make-badges, lookup-journal, pub-date, andify, normalize-author
#import "parts/body.typ": apply-body
#import "parts/theorems.typ": cfg-state, anon-state, thm-counter
#import "parts/theorems.typ": theorem, lemma, corollary, proposition, conjecture, definition, example, remark, proof, acks

#let _formats = (
  acmsmall: acmsmall,
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
  // Genuine no-ops in the single-column acmsmall layout — accepted for API
  // parity (so the names aren't forgotten), but real acmart also produces no
  // acmsmall change for these, so we don't error on them either:
  balance: true,          // last-page column balancing — two-column formats only
  pbalance: false,        // per-page column balancing — two-column formats only
  natbib: true,           // LaTeX citation package — bibliography is CSL-driven here
  // Recognized but NOT yet modelled for acmsmall. Accepted so the option is
  // reserved, but a non-default value raises an explicit error rather than being
  // silently ignored (see the assert loop below). Implement + drop from there
  // when modelled.
  author-version: false,  // authorversion: author's-version copyright block
  timestamp: false,       // draft timestamp in the footer (wall-clock; non-reproducible)
  author-draft: false,    // authordraft = timestamp + review
  acmthm: true,           // acmthm=false suppresses the built-in theorem environments
  urlbreakonhyphens: true,// break URLs on hyphens
  language: none,         // additional languages (translated title/abstract)
  draft: false,           // amsart draft mode (overfull-box rules)
  font-size: "10pt",      // base size 8/9/10/11/12pt (acmsmall geometry assumes 10pt)
  authors-per-row: 0,     // \settopmatter{authorsperrow} (0 = auto)
  article-type: none,     // \acmArticleType: Research/Review/... (acmcp/acmengage)
  body,
) = {
  assert(
    format in _formats,
    message: "unknown/unimplemented acmart format: " + format,
  )
  let cfg = _formats.at(format)

  // Refuse to silently ignore recognized-but-unimplemented options: setting one
  // to a non-default value would otherwise quietly diverge from LaTeX, so we
  // assert instead. Membership rule: an option belongs here iff it would change
  // acmsmall output in real acmart but we don't model that change yet — e.g.
  // `language` (translated title/abstract) or `font-size` (a different base
  // size). This is unrelated to the one/two-column split. Each tuple is
  // (name, value, default).
  //
  // Deliberately NOT here, because they produce no acmsmall change in real
  // acmart either (so they're accepted as documented no-ops, not errors):
  // balance/pbalance (column balancing — a two-column-only feature) and natbib
  // (selects the LaTeX citation package — moot, bibliography is CSL-driven here).
  for (opt-name, val, default) in (
    ("author-version", author-version, false),
    ("timestamp", timestamp, false),
    ("author-draft", author-draft, false),
    ("acmthm", acmthm, true),
    ("urlbreakonhyphens", urlbreakonhyphens, true),
    ("language", language, none),
    ("draft", draft, false),
    ("font-size", font-size, "10pt"),
    ("authors-per-row", authors-per-row, 0),
    ("article-type", article-type, none),
  ) {
    assert(
      val == default,
      message: "acmart: option `" + opt-name + "` is recognized but not yet "
        + "implemented for the acmsmall format (got " + repr(val) + "). It is "
        + "reserved so the name isn't forgotten; leave it at its default "
        + repr(default) + " for now.",
    )
  }

  // \settopmatter{printacmref} defaults true; nonacm flips it off unless the
  // author forces it back on with show-ref: true (acmart.dtx:2717).
  let show-ref = if show-ref == auto { not nonacm } else { show-ref }
  // review mode forces folios on (acmart.dtx:2683, \@ACM@printfoliostrue).
  let print-folios = print-folios or review

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
    teaser: teaser,
    journal: journal,
    acm-volume: acm-volume,
    acm-number: acm-number,
    acm-article: acm-article,
    acm-year: acm-year,
    acm-month: acm-month,
    doi: doi,
    copyright: copyright,
    copyright-year: copyright-year,
    cc-type: cc-type,
    cc-version: cc-version,
    show-ref: show-ref,
    print-ccs: print-ccs,
    nonacm: nonacm,
    anonymous: anonymous,
  )

  // Running footer: "<short>, Vol. V, No. N, Article A. Publication date: M Y."
  // Right-aligned on odd pages, left on even (acmart fancyfoot[RO,LE]).
  // nonacm suppresses the ACM journal bibstrip footer (acmart.dtx:8198/8036).
  let footer-content = {
    let j = lookup-journal(journal)
    if not nonacm and j.short != none {
      context {
        set text(font: cfg.fonts.serif, size: cfg.size.footnotesize)
        // \@acmArticle defaults to empty (acmart.dtx:5477), so the article
        // number may be absent (#acm-article renders nothing for none):
        // "..., Article . Publication date: ..."
        let txt = [#j.short, Vol. #acm-volume, No. #acm-number, Article #acm-article. Publication date: #pub-date(meta).]
        if calc.odd(here().page()) { align(right, txt) } else { align(left, txt) }
      }
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
  let sa = if anonymous { "Anon." } else if short-authors == auto {
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

  set page(
    width: cfg.paper.width,
    height: cfg.paper.height,
    margin: cfg.margin,
    header-ascent: cfg.head.sep + comp(cfg, sz: "footnotesize"),
    footer-descent: cfg.foot.skip - cfg.size.footnotesize,
    header: header-content,
    footer: footer-content,
  )

  // Pin the line box to the font size (top-edge - bottom-edge = 1em) so that the
  // baseline-to-baseline distance is font-metric-independent and equals
  //   leading + 1em = (baselineskip - font-size) + font-size = baselineskip,
  // matching TeX's rigid \baselineskip. top-edge = 1em also puts the first
  // baseline at `top margin + \topskip`, as LaTeX does.
  set text(
    font: cfg.fonts.serif,
    size: cfg.font-size,
    top-edge: 1em,
    bottom-edge: 0pt,
    lang: "en",
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
  show link: it => if screen {
    text(fill: if type(it.dest) == str { acm-dark-blue } else { acm-purple }, it)
  } else { it }

  // `review`: number every line in the left margin (acmart uses \color{red}
  // \scriptsize — 7pt at this base size; acmart.dtx:7862).
  set par.line(numbering: if review {
    n => text(fill: red, size: cfg.size.scriptsize)[#n]
  } else { none })

  cfg-state.update(cfg) // publish config for theorem environments
  anon-state.update(anonymous) // publish anonymity for the acks environment

  if meta.title != none {
    make-footnotes(cfg, meta) // place(bottom) on page 1
    make-title(cfg, meta)
  }

  apply-body(cfg, body)

  // \received history line, printed last (acmart \AtEndDocument).
  if received != none { make-received(cfg, received) }
}
