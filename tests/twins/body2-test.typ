#import "/src/lib.typ": acmart, theorem, lemma, definition, proof, tabular, toprule, midrule, bottomrule
#show: acmart.with(format: "acmsmall", nonacm: true)

= Elements
Text before a figure to establish context for the caption comparison below.

#figure(
  placement: none,
  rect(width: 4cm, height: 2cm, fill: black),
  caption: [A sample figure caption that is long enough to wrap onto a second line so we can examine caption typography.],
)

#figure(
  placement: none,
  tabular(
    columns: 2,
    toprule(),
    [Header A], [Header B],
    midrule(),
    [Value 1], [Value 2],
    [Value 3], [Value 4],
    bottomrule(),
  ),
  caption: [A sample table caption set above the table body as ACM requires.],
)

#theorem[This is the statement of a theorem, which should be typeset with an italic body and a small-caps head.]

#lemma[A lemma shares the theorem counter and uses the same plain style.]

#definition[A definition uses an upright (roman) body and an italic head.]

#proof(name: [Proof.])[This is a proof, ending with a QED square.]

- First bullet item in an itemized list.
- Second bullet item, slightly longer so it may wrap around to a second line for spacing checks.

+ First enumerated item.
+ Second enumerated item.

A lead paragraph precedes the display equation to anchor its vertical spacing.
$ a = b + c $
Text after the display equation continues at the margin with no added indent.

A lead paragraph precedes the verbatim block to anchor its vertical spacing.
```
code line one
code line two
```
Text after the verbatim block continues at the margin with no added indent.

// \appendix: acmart letters the sections (A, A.1, ...); a theorem here must track
// \thesection and number "A.1", not "1.1" (regression for the appendix fix).
#counter(heading).update(0)
#set heading(numbering: "A.1")
= Supplementary material
#theorem[A theorem inside the appendix should be numbered A.1, tracking the lettered section rather than an arabic one.]
