// Theorem-like environments for acmart, matching the amsthm-based acmplain /
// acmdefinition styles. For acmsmall:
//   acmplain (theorem/lemma/corollary/proposition/conjecture):
//     head = small caps, body = italic, indent = parindent, .5bl above/below,
//     head spec "Name Number (Note)." then 0.5em then body (run-in).
//   acmdefinition (definition/example/remark):
//     head = italic, body = roman.
//   proof: head "Proof." small caps, roman body, trailing QED square.
// sigplan overrides the head fonts/indents (cfg.thm, formats/sigplan.typ).
// All share one counter, numbered within the section: 1.1, 1.2, ...

#import "spacing.typ": tex-skip
#import "punct.typ": add-punct
#import "../formats/_base.typ": tp

// Active format config, published by acmart() so the environment functions
// (which users call directly) can read format-specific measurements.
#let cfg-state = state("acmart-cfg", none)

// Whether the document is anonymized (acmart `anonymous` option), published by
// acmart() so body-level environments can suppress identity-revealing content.
#let anon-state = state("acmart-anon", false)

#let thm-counter = counter("acm-thm")

// Mirror LaTeX's \thesection: the first-level section counter formatted with
// whatever heading numbering is currently active. Reading the pattern from the
// nearest preceding heading (rather than using the bare integer) makes theorems
// in an appendix print "A.5", not "1.5", tracking `set heading(numbering: "A.1")`.
// Must be called inside a `context`. Unnumbered headings do not change
// \thesection in LaTeX, so skip them and retain the most recent numbered
// level-one section. Returns `none` only when no numbered section exists yet.
#let _section-number() = {
  let h = counter(heading).get()
  if h.len() == 0 { return none }
  let prev = query(selector(heading.where(level: 1)).before(here()))
    .filter(it => it.numbering != none)
  if prev.len() == 0 { return none }
  numbering(prev.last().numbering, h.first())
}

// Apply an amsthm head-font name to content.
#let _head-font(style, c) = if style == "smallcaps" { smallcaps(c) } else if style == "bold" { text(weight: "bold", c) } else { emph(c) }

// Shared theorem/proof frame: a block with the run-in "<head> " followed by the
// body. The head indent is \parindent unless the style overrides it (sigplan:
// \z@ / \noindent). Paragraphs after the first keep the ambient \parindent, as
// in LaTeX (the global first-line-indent only skips the block's first one).
// head-sep: 0.5em for the theorem styles (amsthm's \thmheadsep); the proof's
// label-body gap is \labelsep instead (trivlist \item, acmart.dtx:8757).
//
// amsthm restores the following paragraph's indentation (\@endpefalse), so — like
// env-block in parts/body.typ — the block emits a trailing zero-height paragraph
// (the h(parindent) shim) that makes the NEXT paragraph take its first-line
// indent. The shim's `par(spacing: 0pt)` keeps it from adding vertical space; the
// block owns the whole below-gap.
#let thm-block(cfg, head, body, topsep: none, indent: auto, head-sep: 0.5em) = {
  let gap = tex-skip(cfg, if topsep == none { 0.5 * cfg.baselineskip } else { topsep })
  block(above: gap, below: 0pt, width: 100%)[
    #h(if indent == auto { cfg.parindent } else { indent })
    // Join the head and body directly (no markup newline, which would leak an
    // interword space beyond `head-sep`): the gap after the head is exactly
    // `head-sep`, matching amsthm's \thmheadsep / the trivlist \labelsep.
    #head#h(head-sep)#body
  ]
  {
    set par(spacing: gap)
    h(cfg.parindent)
  }
}

#let _theorem-env(default-name, kind) = (
  // `kind` picks the amsthm style ("plain" or "definition"); `title` overrides
  // the displayed environment name; it defaults to the env's own name
  // (default-name is captured from the enclosing scope).
  (body, name: none, title: default-name) => {
    thm-counter.step()
    context {
      let cfg = cfg-state.get()
      let sec = _section-number()
      let n = thm-counter.get().first()
      // \thetheorem = \thesection.\arabic: before any numbered section (or when
      // secnumdepth suppresses section numbering entirely, as in sigchi-a/acmcp)
      // \thesection is the untouched counter — LaTeX prints "Theorem 0.1".
      let number = if sec != none { [#sec.#n] } else { [0.#n] }

      let hf = if kind == "plain" { cfg.thm.plain-head } else { cfg.thm.def-head }
      // \thm@headfont{name number}\thm@notefont{ (note)}\thm@headpunct: the
      // note and the trailing "." keep the head font unless the format resets
      // \thm@notefont to \normalfont (sigplan) — the punct follows the note.
      let head = if name == none or cfg.thm.note-inherits-head {
        _head-font(hf, if name != none { [#title #number (#name).] } else { [#title #number.] })
      } else {
        [#_head-font(hf, [#title #number]) (#name).]
      }
      // amsthm sets the env in a trivlist whose \topsep is the style's "space
      // above/below" (.5bl); the baseline pitch is \baselineskip + \topsep, so
      // tex-skip() converts it to the block gap (cf. \@startsection headings).
      thm-block(cfg, head, if kind == "plain" { emph(body) } else { body }, indent: cfg.thm.indent)
    }
  }
)

// acmplain environments
#let theorem = _theorem-env([Theorem], "plain")
#let lemma = _theorem-env([Lemma], "plain")
#let corollary = _theorem-env([Corollary], "plain")
#let proposition = _theorem-env([Proposition], "plain")
#let conjecture = _theorem-env([Conjecture], "plain")

// acmdefinition environments (`remark` is a faithful-acmart extension; the
// bundled class defines no remark environment)
#let definition = _theorem-env([Definition], "definition")
#let example = _theorem-env([Example], "definition")
#let remark = _theorem-env([Remark], "definition")

// acks: the acknowledgments environment (acmart.dtx:8850). An unnumbered section
// titled "Acknowledgments" (\acksname, acmart.dtx:8839); the global heading show
// rule supplies the sans-bold section styling. Suppressed entirely in anonymous
// mode, where acmart `\excludecomment{acks}` drops the block (acmart.dtx:8896).
#let acks(body) = context {
  if anon-state.get() { return }
  // \acksname, localized to the main language (acmart.dtx:3310-3337).
  heading(level: 1, numbering: none)[#cfg-state.get().strings.acks]
  body
}

// proof: unnumbered, "Proof." head in \@proofnamefont (small caps; italic for
// sigplan), roman body, trailing QED. The head defaults to the localized
// \proofname (acmart.dtx:8753); pass `name` to override (the optional argument
// of the LaTeX `proof` environment).
#let proof(body, name: none) = {
  context {
    let cfg = cfg-state.get()
    let name = if name != none { name } else { cfg.strings.proof }
    // proof's \topsep is a FIXED 6pt (+6pt stretch), acmart.dtx:8752 — not the
    // .5\baselineskip of the theorem styles (they only coincide at 10pt) — and
    // its label-body gap is the trivlist \labelsep, not \thmheadsep. That labelsep
    // is 4pt in plain acmart (acmart's begin-document block) but 5pt when amsart's
    // block wins (review/nonacm) — the same hook-ordering bug the list geometry
    // models, so it tracks cfg.amsart-lists.
    thm-block(cfg, _head-font(cfg.thm.proof-head, add-punct(name)),
      [#body #h(1fr)#sym.square.stroked],
      topsep: 6 * tp, indent: cfg.thm.proof-indent,
      head-sep: (if cfg.amsart-lists { 5 } else { 4 }) * tp)
  }
}
