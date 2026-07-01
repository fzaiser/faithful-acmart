#import "/src/lib.typ": acmart
#show: acmart.with(format: "acmsmall")

= Figure Heading Indent
Text before the first figure establishes the normal body left edge.

#figure(
  placement: none,
  rect(width: 3cm, height: 1cm, fill: black),
  caption: [Display heading case.],
)

== Display Heading After Figure
The display heading after the figure should start at the normal heading left
edge, with no paragraph-indent shim leaking through.

#figure(
  placement: none,
  rect(width: 3cm, height: 1cm, fill: black),
  caption: [Run-in heading case.],
)

=== Run-In Heading After Figure
The run-in heading after the figure should start at the normal text left edge.

#figure(
  placement: none,
  rect(width: 3cm, height: 1cm, fill: black),
  caption: [Paragraph heading case.],
)

==== Paragraph Heading After Figure
This paragraph heading is intentionally indented by the ACM paragraph-heading
rule.
