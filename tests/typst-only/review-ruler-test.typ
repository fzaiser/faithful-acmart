// Keep this titleless so the body's page settings can suppress the header.
#import "/src/lib.typ": acmart
#show: acmart.with(format: "acmsmall", review: true, print-acm-reference: false)
#set page(header: none, footer: none)

= Body
A paragraph with no numerals in it at all, so the extracted text carries a digit
only where the review ruler put one.
