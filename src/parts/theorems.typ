// Theorem-like environments for acmart, matching the amsthm-based acmplain /
// acmdefinition styles. For acmsmall:
//   acmplain (theorem/lemma/corollary/proposition/conjecture):
//     head = small caps, body = italic, indent = parindent, .5bl above/below,
//     head spec "Name Number (Note)." then 0.5em then body (run-in).
//   acmdefinition (definition/example/remark):
//     head = italic, body = roman.
//   proof: head "Proof." small caps, roman body, trailing QED square.
// All share one counter, numbered within the section: 1.1, 1.2, ...

// Active format config, published by acmart() so the environment functions
// (which users call directly) can read format-specific measurements.
#let cfg-state = state("acmart-cfg", none)

#let thm-counter = counter("acm-thm")

#let _section-number() = {
  let h = counter(heading).get()
  if h.len() > 0 { h.first() } else { none }
}

#let _theorem-env(default-name, head-style, body-style) = (
  (body, name: none, title: none) => {
    let nm = if title != none { title } else { default-name }
    thm-counter.step()
    context {
      let cfg = cfg-state.get()
      let bls = cfg.baselineskip
      let sec = _section-number()
      let n = thm-counter.get().first()
      let number = if sec != none { [#sec.#n] } else { [#n] }

      let head = {
        let h = [#nm #number]
        if name != none { h = [#h (#name)] }
        if head-style == "smallcaps" { smallcaps(h) } else { emph(h) }
      }
      block(above: 0.5 * bls, below: 0.5 * bls, width: 100%)[
        #set par(first-line-indent: 0pt)
        #h(cfg.parindent)
        #head.#h(0.5em)
        #if body-style == "italic" { emph(body) } else { body }
      ]
    }
  }
)

// acmplain environments
#let theorem = _theorem-env([Theorem], "smallcaps", "italic")
#let lemma = _theorem-env([Lemma], "smallcaps", "italic")
#let corollary = _theorem-env([Corollary], "smallcaps", "italic")
#let proposition = _theorem-env([Proposition], "smallcaps", "italic")
#let conjecture = _theorem-env([Conjecture], "smallcaps", "italic")

// acmdefinition environments
#let definition = _theorem-env([Definition], "italic", "normal")
#let example = _theorem-env([Example], "italic", "normal")
#let remark = _theorem-env([Remark], "italic", "normal")

// proof: unnumbered, small-caps "Proof." head, roman body, trailing QED.
#let proof(body, name: [Proof]) = {
  context {
    let cfg = cfg-state.get()
    block(above: 0.5 * cfg.baselineskip, below: 0.5 * cfg.baselineskip, width: 100%)[
      #set par(first-line-indent: 0pt)
      #h(cfg.parindent)
      #smallcaps(name).#h(0.5em)
      #body
      #h(1fr)#sym.square.stroked
    ]
  }
}
