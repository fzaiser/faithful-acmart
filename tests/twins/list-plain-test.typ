// list-plain-test — list geometry WITHOUT review/nonacm: acmart's own
// dimensions apply (labelsep 4pt, leftmargini 24.5pt, nested 8.5pt); see
// list-test for the review/nonacm (amsart-values) side of the class's
// hook-ordering bug.
#import "/src/lib.typ": acmart
#show: acmart.with(format: "acmsmall")

= Lists
Text before the itemized list establishes the paragraph baseline and the
no-indent paragraph after a section heading.

- First bullet item in an itemized list.
- Second bullet item, slightly longer so it may wrap around to a second line
  for spacing checks.
- Third bullet item follows immediately with no itemsep glue.

The paragraph after the itemized list should resume the normal ACM paragraph
indent. It is long enough to wrap so the left edge and the following line can be
compared.

+ First enumerated item.
+ Second enumerated item follows immediately with no itemsep glue.

The paragraph after the enumerated list should also be indented.

- A top-level bullet introducing a nested list.
  - A nested dash item at the 8.5pt second-level indent.
  - A second nested item that is long enough to wrap onto another line to check the nested hanging indent.
    - A third-level star item.
- A second top-level bullet directly after the nested block.

+ A numbered item with a nested enumerate.
  + The nested label hangs left of the nested body.
  + A second nested numbered item.
+ A second top-level numbered item.

#quote(block: true)[
  A quoted paragraph set off from the text by the list margins on both sides,
  long enough to wrap onto a second line so both edges can be compared, with no
  first-line indent.
]

The paragraph after the quotation should resume the normal paragraph indent.
