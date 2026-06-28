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
#import "parts/frontmatter.typ": make-title, make-footnotes, lookup-journal, pub-date, andify, normalize-author
#import "parts/body.typ": apply-body
#import "parts/theorems.typ": cfg-state, thm-counter
#import "parts/theorems.typ": theorem, lemma, corollary, proposition, conjecture, definition, example, remark, proof

#let _formats = (
  acmsmall: acmsmall,
)

#let acmart(
  format: "acmsmall",
  title: none,
  subtitle: none,
  authors: (),
  abstract: none,
  ccs: none,
  keywords: none,
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
  show-ref: true,
  short-title: auto,
  short-authors: auto,
  // document options
  review: false,
  screen: false,
  anonymous: false,
  ..rest,
  body,
) = {
  assert(
    format in _formats,
    message: "unknown/unimplemented acmart format: " + format,
  )
  let cfg = _formats.at(format)

  // \copyrightyear defaults to \@acmYear; it can't be a signature default because
  // it references another parameter.
  let copyright-year = if copyright-year != none { copyright-year } else { acm-year }
  // Fill in optional author fields up front (see normalize-author).
  let authors = authors.map(normalize-author)

  let meta = (
    title: title,
    subtitle: subtitle,
    authors: authors,
    abstract: abstract,
    ccs: ccs,
    keywords: keywords,
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
    anonymous: anonymous,
  )

  // Running footer: "<short>, Vol. V, No. N, Article A. Publication date: M Y."
  // Right-aligned on odd pages, left on even (acmart fancyfoot[RO,LE]).
  let footer-content = {
    let j = lookup-journal(journal)
    if j.short != none {
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
    if p <= 1 { return }
    set text(font: cfg.fonts.sans, size: cfg.size.footnotesize)
    let article-page = if acm-article != none [#acm-article:#p] else [#p]
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

  if meta.title != none {
    make-footnotes(cfg, meta) // place(bottom) on page 1
    make-title(cfg, meta)
  }

  apply-body(cfg, body)
}
