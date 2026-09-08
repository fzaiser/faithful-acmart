// review-ruler-on-test — the review/authordraft line-number ruler belongs to the
// running head. acmart hangs it off \fancyhead[LO] (acmart.dtx:8107), so
// \pagestyle{empty} takes it away with the rest of the head; the port keeps it
// in the page header for the same reason. The body carries no digits of its
// own, so every number on the page is a ruler number: this document keeps the
// head and must show them, while review-ruler-test suppresses it and shows none.
// Titleless because a title block pins page one's chrome before a body
// `set page` reaches it.
#import "/src/lib.typ": acmart
#show: acmart.with(format: "acmsmall", review: true, print-acm-reference: false)

= Body
A paragraph with no numerals in it at all, so the extracted text carries a digit
only where the review ruler put one.
