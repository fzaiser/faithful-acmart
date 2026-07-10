// Running heads, footers, page backgrounds, and review/draft overlays.

#import "../formats/_base.typ": tp
#import "spacing.typ": comp
#import "frontmatter.typ": make-badges, pub-date, doi-link, andify

#let make-page-chrome(cfg, meta, options) = {
  let print-folios = options.print-folios
  let timestamp = options.timestamp
  let review = options.review
  let short-title = options.short-title
  let short-authors = options.short-authors
  let badges = options.badges
  let article-type = options.article-type
  let acmcp-art = options.article

  let article-page(p) = {
    if meta.acm-article != none {
      if print-folios [#meta.acm-article:#p] else [#meta.acm-article]
    } else if print-folios [#p]
  }
  // LaTeX prints \@journalNameShort, Vol. V, No. N, Article A. Publication date: D.
  // UNCONDITIONALLY for the journal formats (acmart.dtx:8256): an empty \@acmArticle
  // yields "Article ." (the upstream blemish, replicated), a missing journal an empty
  // name prefix — the footer still prints. Gated only by `nonacm` (the caller already
  // restricts this to journal formats).
  let journal-footer = {
    let journal = meta.journal
    if not meta.nonacm {
      let prefix = if journal.short != none { journal.short }
      [#prefix, Vol. #meta.acm-volume, No. #meta.acm-number, Article #if meta.acm-article != none { meta.acm-article }. Publication date: #pub-date(meta).]
    }
  }
  let manuscript-footer = if not meta.nonacm [Manuscript submitted to ACM]
  let conference-line = {
    if cfg.name == "acmengage" {
      // \@formatdoi is \url{...} (acmart.dtx:6204), so the head DOI is a live
      // link, styled upright roman by acmengage's \urlstyle{rm}.
      [EngageCSEdu.#if meta.doi != none { text(font: cfg.fonts.body)[ #doi-link(meta.doi)] }]
    } else if meta.conference != none {
      let short = meta.conference.at("short", default: meta.conference.at("name", default: none))
      let date = meta.conference.at("date", default: none)
      let venue = meta.conference.at("venue", default: none)
      let parts = (short, date, venue).filter(x => x != none)
      if parts.len() > 0 { parts.join(", ") }
    }
  }
  let footer-row(l: none, c: none, r: none) = grid(
    columns: (1fr, auto, 1fr),
    align(left, l), align(center, c), align(right, r),
  )

  // The journal bibstrip sits on the outer edge; the optional timestamp sits on
  // the inner edge. Folio parity follows the page counter, including start-page.
  let footer = context {
    set text(font: cfg.fonts.body, size: cfg.size.footnotesize)
    set par(leading: comp(cfg, sz: "footnotesize"))
    let pageno = counter(page).get().first()
    let odd = calc.odd(pageno)
    let first-page = here().page() == 1
    let bib = if cfg.name == "acmcp" {
      if meta.journal.short != none {
        [#meta.journal.name, Volume #meta.acm-volume, Issue #meta.acm-number#if meta.acm-article != none [, Article #meta.acm-article] (#pub-date(meta))#if meta.doi != none { linebreak(); doi-link(meta.doi) }]
      }
    } else if cfg.name == "acmtog" and meta.conference != none {
      [#conference-line.]
    } else if cfg.name in ("acmsmall", "acmlarge", "acmtog") {
      journal-footer
    } else if cfg.name == "manuscript" {
      manuscript-footer
    }
    let folio = if print-folios { [#pageno] }
    if cfg.name == "acmcp" {
      // acmcp's foot (\fancyfoot[L,C]{}\fancyfoot[R]{bib}, acmart.dtx:8129) clears
      // any timestamp slot and keeps the foot rule + bib on every page — so acmcp
      // is handled BEFORE the timestamp branch (LaTeX wipes the stamp on acmcp).
      place(top + left, dy: -(8.35 * tp - cfg.size.footnotesize) - 0.1 * tp,
        line(length: 100%, stroke: 0.1 * tp))
      footer-row(r: bib)
    } else if timestamp {
      let total = counter(page).final().first()
      let date = datetime.today().display("[year]-[month]-[day]")
      let start = if meta.start-page == none { 1 } else { meta.start-page }
      let ts = [#if meta.submission-id != none { [Submission ID: #meta.submission-id. ] }#date. Page #pageno of #{start}--#{total}.]
      if cfg.name == "manuscript" {
        if first-page {
          // Page 1: timestamp and slug share one corner (verified exact), folio opposite.
          let ts = if not meta.nonacm [#ts#h(1em)Manuscript submitted to ACM] else { ts }
          let folio = if folio != none { text(size: cfg.size.small, folio) }
          if odd { footer-row(l: ts, r: folio) } else { footer-row(l: folio, r: ts) }
        } else {
          // Pages >=2: LaTeX keeps the "Manuscript submitted to ACM" slug at
          // \fancyfoot[RO,LE] and the timestamp at [LO,RE] — both print, opposite
          // corners, parity-swapped (acmart.dtx:7938/7945).
          if odd { footer-row(l: ts, r: manuscript-footer) } else { footer-row(l: manuscript-footer, r: ts) }
        }
      } else if cfg.kind == "proceedings" {
        if odd { footer-row(l: ts, c: folio) } else { footer-row(c: folio, r: ts) }
      } else if odd {
        grid(columns: (1fr, 1fr), align(left, ts), align(right, bib))
      } else {
        grid(columns: (1fr, 1fr), align(left, bib), align(right, ts))
      }
    } else if cfg.name == "manuscript" and first-page {
      let folio = if folio != none { text(size: cfg.size.small, folio) }
      if odd { footer-row(l: bib, r: folio) } else { footer-row(l: folio, r: bib) }
    } else if cfg.kind == "proceedings" {
      footer-row(c: folio)
    } else if bib != none {
      if odd { align(right, bib) } else { align(left, bib) }
    }
  }

  // Page one has no running head; continuation pages alternate title/authors and
  // folio/conference content according to each format's fancyhdr setup.
  let st = if short-title == auto { meta.title } else { short-title }
  let sa = if meta.anonymous {
    if meta.submission-id != none [Anon. Submission Id: #meta.submission-id] else [Anon.]
  } else if short-authors == auto {
    if meta.authors.len() == 0 { none } else { andify(meta.authors.map(a => a.name)) }
  } else { short-authors }
  let header = context {
    if here().page() <= 1 {
      if badges != none { return make-badges(badges) }
      return
    }
    let p = counter(page).get().first()
    let hf = if cfg.name == "manuscript" {
      (cfg.fonts.body, cfg.size.normalsize)
    } else {
      (cfg.fonts.sans, cfg.size.footnotesize)
    }
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
      if odd { align(right, [#st#h(1em)•#h(1em)#ap]) }
      else { align(left, [#ap#h(1em)•#h(1em)#sa]) }
    } else if cfg.kind == "proceedings" {
      let conf = conference-line
      if odd or cfg.name == "sigchi-a" {
        grid(columns: (1fr, 1fr), align(left, st), align(right, if not meta.nonacm { conf }))
      } else {
        grid(columns: (1fr, 1fr), align(left, if not meta.nonacm { conf }), align(right, sa))
      }
    } else {
      none
    }
    if cfg.head.offset != 0pt { pad(left: -cfg.head.offset, head) } else { head }
  }

  let watermark-text = if meta.author-draft {
    [Unpublished working draft.\ Not for distribution.]
  } else if cfg.name == "sigchi-a" and not meta.nonacm {
    [Legacy document.\ Not for publication in an\ ACM venue]
  }
  let watermark = if watermark-text != none {
    rotate(-45deg, reflow: false, text(size: 0.5in, fill: luma(90%))[
      #set par(leading: 0.2em, justify: false)
      #align(center, watermark-text)
    ])
  }

  let acmcp-label = if cfg.name == "acmcp" {
    let textheight = cfg.paper.height - cfg.margin.top - cfg.margin.bottom
    let lbl = rotate(-90deg, reflow: true, box(fill: acmcp-art.color, inset: 3 * tp,
      text(font: cfg.fonts.body, size: cfg.size.normalsize, fill: white,
        top-edge: "ascender", bottom-edge: "descender")[#article-type Article]))
    context place(top + left, dx: 0pt,
      dy: cfg.margin.top - measure(lbl).height / 2 + 0.2 * textheight * acmcp-art.nr,
      lbl)
  }

  let review-ruler = if review { context {
    let th = cfg.paper.height - cfg.margin.top - cfg.margin.bottom
    let bls = cfg.at("baselineskip-unstretched")
    let n = calc.ceil(th / bls) + 1
    let two-sided-ruler = cfg.columns == 2 or cfg.name == "sigchi-a"
    let pg = here().page() - 1
    let start = pg * (if two-sided-ruler { 2 * n } else { n }) + 1
    let odd = calc.odd(here().page())
    let ml = cfg.margin.at("left", default: if odd { cfg.margin.at("inside", default: 0pt) } else { cfg.margin.at("outside", default: 0pt) })
    let mr = cfg.margin.at("right", default: if odd { cfg.margin.at("outside", default: 0pt) } else { cfg.margin.at("inside", default: 0pt) })
    let ruler(first) = text(fill: rgb(255, 0, 0), size: cfg.size.scriptsize,
      top-edge: 1em, bottom-edge: 0pt, {
        set par(leading: bls - cfg.size.scriptsize, justify: false)
        range(first, first + n).map(str).join(linebreak())
      })
    let dy = cfg.margin.top + 8.43 * tp - cfg.size.scriptsize
    place(top + left, dx: ml - 26 * tp, dy: dy, ruler(start))
    if two-sided-ruler {
      place(top + left, dx: cfg.paper.width - mr + 20 * tp, dy: dy, ruler(start + n))
    }
  } }

  (
    header: header,
    footer: footer,
    background: {
      acmcp-label
      review-ruler
      if watermark != none { align(center + horizon, watermark) }
    },
  )
}
