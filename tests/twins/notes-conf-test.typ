// notes-conf-test — frontmatter footnote isolator for an acmsmall CONFERENCE
// paper. Matched twin: notes-conf-test.tex. \acmConference lowers
// \if@ACM@journal@bibstrip@or@tog under acmsmall (acmart.dtx:5104), so the
// authors-addresses stream is empty here: no `thanks` and no contact block. That
// leaves exactly two footnote streams — the ordinary top-matter notes and the
// copyright/permission block — which is the stream combination notes-test
// (journal, three streams) cannot reach.
#import "/src/lib.typ": acmart

#show: acmart.with(
  format: "acmsmall",
  title: "A Title With a Note",
  title-note: [This funding note is attached to the title.],
  subtitle: "A Subtitle With a Note",
  subtitle-note: [And this one is attached to the subtitle.],
  acm-year: 2018,
  doi: "XXXXXXX.XXXXXXX",
  conference: (
    short: "Conference acronym 'XX",
    name: "Make sure to enter the correct conference title from your rights confirmation email",
    date: "June 03--05, 2018",
    venue: "Woodstock, NY",
  ),
  isbn: "978-1-4503-XXXX-X/2018/06",
  copyright: "acmlicensed", copyright-year: 2018,
  short-authors: "Researcher and Scientist",
  authors: (
    (name: "Alice Researcher", note: (
       [Alice did the experiments.],
       [Alice wrote the supplemental material.],
     ),
     email: "alice@example.edu",
     affiliation: (institution: "Example University",
                   city: "Townsville", country: "USA")),
    (name: "Bob Scientist", corresponding: true, email: "bob@example.edu",
     affiliation: (institution: "Sample Institute",
                   city: "Metropolis", country: "USA")),
  ),
  abstract: [
    A short abstract anchoring the front matter so the footnote stack, the title
    and subtitle notes, and the author notes can be compared between the LaTeX and
    Typst renderings when the authors-addresses stream is absent.
  ],
)

= Introduction
This document isolates the top-matter footnotes of a conference paper typeset in
the acmsmall journal format, where the contact-information stream is suppressed
and the notes sit directly above the copyright block.
