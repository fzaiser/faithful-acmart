// sigplan-test — two-column proceedings format (twin).
// Matched twin: sigplan-test.tex. Exercises the two-column layout: the spanning
// centered conference title, the centered author grid, the first-column copyright
// block (conference info + permission + ISBN), and the serif-bold Large sections.
#import "/src/lib.typ": acmart, theorem, definition, proof

#show: acmart.with(
  format: "sigplan",
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
    A short proceedings document used to compare the sigplan two-column layout
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

=== A subsubsection
A run-in subsubsection heading. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim aeque doleamus animo, cum corpore dolemus, fieri tamen permagna accessio potest, si aliquod aeternum et infinitum impendere.

= Structures
The sigplan style overrides several defaults: enumerate labels are _1._/_a._, theorem heads are bold at zero indent with upright notes, proofs carry an italic unindented label, and captions bold only their label.

+ First enumerated item, labeled "1." rather than "(1)".
+ Second enumerated item for the label comparison.

#theorem(name: "Fermat")[A theorem with a note: the head is bold, the note stays upright, and the body is italic.]

#definition[A definition keeps a bold head and an upright body in sigplan.]

#proof[A proof label is italic and unindented in sigplan, ending with a QED square.]

#figure(
  placement: none,
  rect(width: 4cm, height: 1cm, fill: black),
  caption: [A sigplan caption whose label is bold while this caption text stays regular, long enough to wrap onto a second line.],
)

= Method
A second top-level section. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magnam aliquam quaerat voluptatem. Ut enim aeque doleamus animo, cum corpore dolemus, fieri tamen permagna accessio potest, si aliquod aeternum et infinitum impendere malum nobis opinemur. Quod idem licet transferre in voluptatem, ut postea variari voluptas distinguique possit, augeri amplificarique non possit. At etiam Athenis, ut e patre audiebam facete et urbane Stoicos irridente, statua est in quo a nobis philosophia defensa et collaudata est, cum id, quod maxime placeat, facere possimus, omnis voluptas assumenda est, omnis dolor repellendus. Temporibus autem quibusdam et aut officiis debitis aut rerum necessitatibus saepe eveniet, ut et voluptates repudiandae sint et molestiae non recusandae. Itaque earum rerum.

