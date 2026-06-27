#import "../src/lib.typ": acmart, theorem, lemma, definition, proof
#show: acmart.with(format: "acmsmall")

= Elements
Text before a figure to establish context for the caption comparison below.

#figure(
  rect(width: 4cm, height: 2cm, fill: black),
  caption: [A sample figure caption that is long enough to wrap onto a second line so we can examine caption typography.],
)

#figure(
  table(
    columns: 2,
    stroke: none,
    table.hline(),
    [Header A], [Header B],
    table.hline(),
    [Value 1], [Value 2],
    [Value 3], [Value 4],
    table.hline(),
  ),
  caption: [A sample table caption set above the table body as ACM requires.],
)

#theorem[This is the statement of a theorem, which should be typeset with an italic body and a small-caps head.]

#lemma[A lemma shares the theorem counter and uses the same plain style.]

#definition[A definition uses an upright (roman) body and an italic head.]

#proof[This is a proof, ending with a QED square.]

- First bullet item in an itemized list.
- Second bullet item, slightly longer so it may wrap around to a second line for spacing checks.

+ First enumerated item.
+ Second enumerated item.
