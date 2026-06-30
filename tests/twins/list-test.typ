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
