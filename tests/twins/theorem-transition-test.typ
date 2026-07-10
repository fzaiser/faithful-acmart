#import "/src/lib.typ": *

#show: acmart.with(
  format: "acmsmall",
  nonacm: true,
  print-acm-reference: false,
  print-folios: false,
)

= Numbered Section
#theorem[The first numbered statement.]

#heading(level: 1, numbering: none)[Unnumbered Interlude]
#theorem[The statement after an unnumbered section.]

#acks[The reviewers improved this test.]
#theorem[The statement after acknowledgments.]

==== Results:
A colon-terminated run-in heading does not gain a period.

==== Consequences;
A semicolon-terminated run-in heading does not gain a period.

#proof(name: [Sketch,])[A comma-terminated proof name does not gain a period.]
