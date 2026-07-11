// sigchi-a-test — landscape SIGCHI extended-abstract format (best-effort).
// Sans default, wide left margin, 2pt-rule title, unnumbered sections. Golden-smoke.
#import "/src/lib.typ": acmart, sidebar, marginfigure, margintable, fulltextwidth, tabular, toprule, midrule, bottomrule

#show: acmart.with(
  format: "sigchi-a",
  title: "A Two-Column Conference Sample",
  conference: (short: "Conference'17", date: "June 2018", venue: "Washington, DC, USA"),
  booktitle: "Proceedings of ACM Conference (Conference'17)",
  isbn: "978-1-4503-XXXX-X/2018/06",
  doi: "XXXXXXX.XXXXXXX",
  acm-year: 2018, acm-month: 6,
  copyright: "acmlicensed", copyright-year: 2018,
  authors: (
    (name: "Ben Trovato", email: "trovato@corporation.com",
     affiliation: (institution: "Institute for Clarity in Documentation",
                   city: "Dublin", state: "Ohio", country: "USA")),
    (name: "Lars Thørväld", email: "larst@affiliation.org",
     affiliation: (institution: "The Thørväld Group",
                   city: "Hekla", country: "Iceland")),
    (name: "Valerie Béranger", email: "valerie@inria.fr",
     affiliation: (institution: "Inria Paris-Rocquencourt",
                   city: "Rocquencourt", country: "France")),
  ),
  abstract: [
    A short proceedings document used to compare the two-column conference layout
    between the LaTeX and Typst renderings: the full-width title and author grid,
    the first-column permission block, and the section typography.
  ],
  ccs: (
    (500, "Computing methodologies", "Massively parallel algorithms"),
    (300, "Computing methodologies", "Concurrent algorithms"),
  ),
  keywords: ("datasets", "neural networks", "gaze detection", "text tagging"),
)

= Introduction
This document exercises the sigconf format's two-column body, the spanning title block, and the serif-bold Large section headings. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim aeque doleamus animo, cum corpore dolemus, fieri tamen permagna accessio potest, si aliquod aeternum et infinitum impendere malum nobis opinemur. Quod idem licet transferre in voluptatem, ut postea variari voluptas distinguique possit, augeri amplificarique non possit. At etiam Athenis, ut e patre audiebam facete et urbane Stoicos irridente, statua est in quo a nobis philosophia defensa et.

== Background
A subsection to check the level-2 heading. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim aeque doleamus animo, cum corpore dolemus, fieri tamen permagna accessio potest, si aliquod aeternum et infinitum impendere malum nobis opinemur. Quod idem licet transferre in voluptatem, ut postea variari voluptas distinguique possit, augeri amplificarique non possit. At.

#sidebar[
  A sidebar note set small in the margin column, anchored at this point of the
  text, wrapping over a few short lines.
]
=== A subsubsection
A run-in subsubsection heading. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim aeque doleamus animo, cum corpore dolemus, fieri tamen permagna accessio potest, si aliquod aeternum et infinitum impendere.
#marginfigure[
  #figure(rect(width: 3cm, height: 1cm, fill: black), caption: [A margin figure caption.])
]

= Method
A second top-level section. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim aeque doleamus animo, cum corpore dolemus, fieri tamen permagna accessio potest, si aliquod aeternum et infinitum impendere malum nobis opinemur. Quod idem licet transferre in voluptatem, ut postea variari voluptas distinguique possit, augeri amplificarique non possit. At etiam Athenis, ut e patre audiebam facete et urbane Stoicos irridente, statua est in quo a nobis philosophia defensa et collaudata est, cum id, quod maxime placeat, facere possimus, omnis voluptas assumenda est, omnis dolor repellendus. Temporibus autem quibusdam et aut officiis debitis aut rerum necessitatibus saepe eveniet, ut et voluptates repudiandae sint et molestiae non recusandae. Itaque earum rerum.

#margintable[
  #figure(
    tabular(
      columns: 2,
      toprule(),
      [Key], [Value],
      midrule(),
      [One], [first],
      [Two], [second],
      bottomrule(),
    ),
    caption: [A margin table caption.],
  )
]

#figure(
  placement: none,
  rect(width: 6cm, height: 1.5cm, fill: black),
  caption: [A sigchi-a caption, set bold at the small size, long enough that it wraps onto a second line for the typography comparison.],
)

#fulltextwidth[
  #figure(
    rect(width: 100%, height: 1cm, fill: black),
    caption: [A full-text-width figure spanning the text plus the margin column via #raw("fulltextwidth").],
  )
]
