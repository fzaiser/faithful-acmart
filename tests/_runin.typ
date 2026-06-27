#set page(width: 6.75in, height: 4in, margin: 46pt)
#set text(font: "Libertinus Serif", size: 10pt)
#set par(first-line-indent: (amount: 10pt, all: false), leading: 2pt, spacing: 2pt, justify: true)

#show heading.where(level: 3): it => {
  v(6pt, weak: true)
  h(-10pt)  // cancel first-line indent -> start at margin
  text(font: "Libertinus Sans", style: "italic", weight: "regular")[#it.body.]
  h(0.5em)
}
#show heading.where(level: 4): it => {
  v(6pt, weak: true)
  text(style: "italic", weight: "regular")[#it.body.]
  h(0.5em)
}

Intro paragraph to establish the baseline grid and give the run-in headings something to follow after a normal paragraph of text here.

=== A Finer Point
The body should continue on the same line, starting at the left margin with no indent, and wrap to a second line at the margin as well for confirmation.

==== An inline heading
This one should be indented by parindent on its first line, then continue, wrapping to a second line at the left margin like a normal paragraph.
