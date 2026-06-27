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
#import "parts/headings.typ": render-heading
#import "parts/frontmatter.typ": make-title, make-footnotes, lookup-journal, pub-date
#import "parts/body.typ": apply-body
#import "parts/theorems.typ": cfg-state, thm-counter
#import "parts/theorems.typ": theorem, lemma, corollary, proposition, conjecture
#import "parts/theorems.typ": definition, example, remark, proof

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
  // publication metadata
  journal: none,
  acm-volume: none,
  acm-number: none,
  acm-article: none,
  acm-year: none,
  acm-month: none,
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
    if j.short != none and acm-volume != none {
      context {
        set text(font: cfg.fonts.serif, size: cfg.size.footnotesize)
        let txt = [#j.short, Vol. #str(acm-volume), No. #str(acm-number), Article #str(acm-article). Publication date: #pub-date(meta).]
        if calc.odd(here().page()) { align(right, txt) } else { align(left, txt) }
      }
    }
  }

  // Running head on continuation pages (page 1 uses no running head). acmsmall:
  //   even: [LE] article:page        [RE] short authors
  //   odd:  [LO] short title         [RO] article:page
  // in sans footnotesize (\@headfootfont).
  let st = if short-title == auto { title } else { short-title }
  let sa = if anonymous { "Anonymous Author(s)" } else if short-authors == auto {
    let lastname(n) = n.split(" ").last()
    if authors.len() == 0 { none }
    else if authors.len() == 1 { lastname(authors.at(0).name) }
    else if authors.len() == 2 { lastname(authors.at(0).name) + " and " + lastname(authors.at(1).name) }
    else { lastname(authors.at(0).name) + " et al." }
  } else { short-authors }
  let header-content = context {
    let p = here().page()
    if p <= 1 { return }
    set text(font: cfg.fonts.sans, size: cfg.size.footnotesize)
    let article-page = if acm-article != none [#str(acm-article):#p] else [#p]
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
    header-ascent: cfg.head.sep - cfg.size.footnotesize,
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
    leading: cfg.baselineskip - cfg.font-size,
    first-line-indent: (amount: cfg.parindent, all: false),
    spacing: cfg.baselineskip - cfg.font-size, // inter-paragraph = one blank baselineskip step (parskip=0)
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

  // `review`: number every line in the left margin (red, small), as acmart does.
  set par.line(numbering: if review {
    n => text(fill: red, size: cfg.size.footnotesize)[#n]
  } else { none })

  cfg-state.update(cfg) // publish config for theorem environments

  if meta.title != none {
    make-footnotes(cfg, meta) // place(bottom) on page 1
    make-title(cfg, meta)
  }

  apply-body(cfg, body)
}
