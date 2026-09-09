#import "/src/lib.typ": acmart

#show: acmart.with(
  format: "acmsmall",
  title: "Author-Draft Mode",
  journal: "JACM",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  short-authors: "Trovato",
  author-draft: true,
  submission-id: "123-A56-BU3",
  authors: (
    (name: "Ben Trovato", email: "trovato@corporation.com",
     affiliation: (institution: "Institute for Clarity in Documentation",
                   city: "Dublin", country: "USA")),
  ),
  abstract: [
    A short abstract to anchor the front matter while exercising author-draft mode.
  ],
)

= Introduction
Body text so the draft watermark and the line-numbered margin have content to sit
behind. #lorem(60)
