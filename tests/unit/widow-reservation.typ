// Typst's widow check tests two lines against the remaining height, so reserved height can move a line
// that the unused height measured afterwards seems to leave room for.
// The flush-bottom safeguard in src/parts/spacing.typ exists for this case.
#set page(width: 240pt, height: 120pt, margin: 10pt, columns: 2)
#set text(font: "Libertinus Serif", size: 10pt, top-edge: 8pt, bottom-edge: -2pt)
#set par(leading: 0pt, spacing: 0pt)
#set footnote.entry(separator: none, clearance: 0pt, gap: 0pt)

#let sample(name, reserved) = {
  if reserved > 0pt { place(bottom, float: true, clearance: 0pt, block(height: reserved)) }
  block(height: 1fr, spacing: 0pt, layout(size => [#metadata((name, size.height))<slack>]))
  for i in range(1, 9) [Line #i\ ]
  [Line 9#metadata(name)<nine>\ Line 10#footnote[Note.]]
}

#sample("free", 0pt)
#pagebreak()
#sample("reserved", 0.1pt)

#context {
  let column(name) = query(<nine>).find(m => m.value == name).location().position().x
  let slack(name) = query(<slack>).find(m => m.value.at(0) == name).value.at(1)
  assert(column("free") < 120pt, message: "line 9 stays in the first column without a reservation")
  assert(calc.abs((slack("free") - 10pt).pt()) < 0.01, message: "the first column has 10pt unused")
  assert(column("reserved") > 120pt, message: "a 0.1pt reservation moves line 9")
}
