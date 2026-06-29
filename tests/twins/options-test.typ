// options-test — class/topmatter option toggles.
// Matched twin: options-test.tex. Exercises the options with a visible effect in
// the single-column acmsmall layout — nonacm (drops the ACM footer, reference
// format, and page-1 copyright block), print-ccs: false (suppresses the CCS
// block), print-folios: false (no folios in the running head) — plus the
// single-column no-ops balance / natbib. Two pages so page 2 shows the
// suppressed folios in the running head.
#import "/src/lib.typ": acmart

#show: acmart.with(
  format: "acmsmall",
  title: "Exercising Document Options",
  journal: "JACM",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  short-authors: "Trovato",
  // toggled options under test
  nonacm: true,
  print-ccs: false,
  print-folios: false,
  balance: false,  // single-column no-op (two-column formats only)
  natbib: false,   // single-column no-op (bibliography is CSL-driven)
  authors: (
    (name: "Ben Trovato", email: "trovato@corporation.com",
     affiliation: (institution: "Institute for Clarity in Documentation",
                   city: "Dublin", country: "USA")),
  ),
  abstract: [
    A short abstract for a document that toggles several acmart options: nonacm,
    printccs, printfolios, balance, and natbib. The body is long enough to span two
    pages so that the suppressed folios in the running head can be observed.
  ],
  // print-ccs: false suppresses this in the title block (kept here to prove it).
  ccs: (
    (500, "Computing methodologies", "Massively parallel algorithms"),
  ),
  keywords: ("options", "nonacm", "folios"),
)

= Introduction
This document toggles several acmart options at once so that their combined
effect on the single-column journal layout can be compared between the LaTeX
class and the Typst port. The nonacm option removes the ACM journal footer, the
ACM reference format paragraph, and the page-one copyright block. The printccs
option suppresses the CCS Concepts line in the title block, while printfolios
removes the page folios from the running head on continuation pages.

The remaining toggled options, balance and natbib, have no effect in a
single-column layout: column balancing applies only to the two-column formats,
and citation handling here is driven by a citation-style language rather than by
the natbib package. They are accepted so that documents written for the LaTeX
class compile unchanged against the port.

= A Longer Section
To push the document onto a second page we repeat a few paragraphs of ordinary
prose. Each paragraph is set on the same baseline grid as the surrounding body
text, so the cumulative vertical advance should match the LaTeX reference closely
until the bottom of the first page is reached. The page-one footer is absent
because of the nonacm option, leaving the bottom margin clear.

The second page carries a running head. With folios suppressed, the head shows
only the short title on odd pages and the short authors on even pages, without
the article-and-page number that normally accompanies them. This is the most
visible consequence of printfolios on a journal article, and it is the reason the
test is deliberately two pages long rather than one.

We continue with another paragraph of filler so that the break onto the second
page is unambiguous. The exact wording is unimportant; what matters is that the
LaTeX and Typst documents contain identical text so that any divergence in the
rendered output is attributable to the option handling rather than to a
difference in content.

= More Filler
A further section keeps the prose flowing toward the second page. We describe, in
deliberately neutral terms, the way the running head is assembled on continuation
pages: the short title sits on the outer edge of odd pages, the short author list
on the outer edge of even pages, and the article-and-page identifier occupies the
inner edge of both. Disabling folios blanks the identifier entirely.

The body text remains on a single baseline grid throughout, which is what allows
the cross-engine metrics gate to compare the vertical advance of the two
renderings. Mixed-leading material such as the title block or a list would break
that uniformity, but ordinary paragraphs like these do not.

Another paragraph follows to guarantee that the content comfortably exceeds the
height of a single page. The precise number of lines is not important; the test
only needs to be long enough that a second page exists and carries a running
head, so that the folio suppression has somewhere to take effect.

= Yet More Material
We add one more section to leave headroom against small differences in
line-breaking between the two engines, which can otherwise push the page break
back and forth across the boundary. Keeping the document solidly two pages long
makes the page-count parity check stable.

The closing paragraphs reiterate that none of the toggled options change the body
typography: nonacm, printccs, and printfolios all act on the title block, the
footer, and the running head rather than on the running text. The balance and
natbib options act on nothing at all in this layout.

= Closing Remarks
Finally, a short closing section confirms that section numbering, paragraph
spacing, and the running head all behave as expected once the document spills
onto its second page. The reference format paragraph that would normally appear
in the title block is absent here, again because of the nonacm option.
