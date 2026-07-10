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

= Indent After Environments
#theorem[A theorem statement whose following paragraph takes the ambient first line indent, as amsthm restores it.]
A paragraph after the theorem is indented by the ambient parindent value here.

#proof[A proof body ending in the customary QED square symbol drawn at the right.]
A paragraph after the proof is likewise indented by the ambient parindent value.
