// acmtog-test — two-column journal format.
// Matched twin: acmtog-test.tex. Exercises the two-column journal layout: the
// spanning LEFT-aligned @i title, the author LIST (not grid), the contact-info
// footnote + ACM bibstrip, 9pt parindent, and the sans-large sections.
#import "/src/lib.typ": acmart

#show: acmart.with(
  format: "acmtog",
  title: "A Two-Column Journal Sample",
  journal: "TOG",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  short-authors: "Trovato et al.",
  authors: (
    (name: "Ben Trovato", email: "trovato@corporation.com",
     affiliation: (institution: "Institute for Clarity in Documentation",
                   city: "Dublin", state: "Ohio", country: "USA")),
    (name: "Valerie Béranger",
     affiliation: (institution: "Inria Paris-Rocquencourt",
                   city: "Rocquencourt", country: "France")),
  ),
  abstract: [
    A short journal document in the acmtog format, used to compare the two-column
    journal layout — spanning left title, author list, contact-info footnote and
    ACM bibstrip — between the LaTeX and Typst renderings.
  ],
  keywords: ("datasets", "neural networks", "gaze detection"),
)

= Introduction
This document exercises the acmtog format's two-column journal layout. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim aeque doleamus animo, cum corpore dolemus, fieri tamen permagna accessio potest, si aliquod aeternum et infinitum impendere malum nobis opinemur. Quod idem licet transferre voluptatem.

== Background
A subsection to check the level-2 heading. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim aeque doleamus animo, cum corpore dolemus.

= Method
A second top-level section. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim aeque doleamus animo, cum corpore dolemus, fieri tamen permagna accessio potest, si aliquod aeternum et infinitum impendere malum nobis opinemur. Quod idem licet transferre in voluptatem, ut postea variari voluptas distinguique possit, augeri amplificarique non possit. At etiam Athenis, ut e patre audiebam facete et urbane Stoicos irridente, statua est in quo a nobis philosophia defensa et collaudata est, cum id, quod maxime placeat, facere.
