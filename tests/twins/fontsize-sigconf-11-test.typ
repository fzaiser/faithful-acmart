// fontsize-sigconf-11-test — sigconf (two-column proceedings) at the NON-DEFAULT
// 11pt base. Matched twin: fontsize-sigconf-11-test.tex. A titled document so the
// title block switches acmart into two-column mode (a titleless proceedings doc
// stays single-column); the body then exercises the proceedings section-heading
// ladder at 11pt — a distinct scaling axis from the single-column acmsmall
// fontsize twins. Two-column extraction reorders, so text is word-bag gated.
#import "/src/lib.typ": acmart

#show: acmart.with(
  format: "sigconf",
  font-size: 11pt,
  title: "Proceedings Heading Scaling at Eleven Point",
  conference: (name: "ACM Conference", short: "Conference'17", venue: "Washington, DC, USA"),
  booktitle: "Proceedings of ACM Conference (Conference'17)",
  isbn: "978-1-4503-XXXX-X/2018/06",
  doi: "XXXXXXX.XXXXXXX",
  acm-year: 2018, acm-month: 6,
  copyright: "acmlicensed", copyright-year: 2018,
  authors: (
    (name: "Ben Trovato", email: "trovato@corporation.com",
     affiliation: (institution: "Institute for Clarity", city: "Dublin", country: "USA")),
  ),
  abstract: [
    A proceedings document set at an 11pt base to compare the two-column section
    heading ladder between the LaTeX and Typst renderings.
  ],
)

= Proceedings Heading Scaling
The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor
jugs. How vexingly quick daft zebras jump! The five boxing wizards jump quickly.
Sphinx of black quartz, judge my vow.

== A Nested Heading
We study the proceedings section-heading fonts at a non-default base size. The
sigconf headings scale from the base size on their own ladder, distinct from the
single-column journal formats, so an 11pt base exercises a different heading-size
rung than the acmsmall fontsize twins.

=== A run-in level three
A run-in subsubsection heading followed immediately by body text. Two driven jocks
help fax my big quiz. Five quacking zephyrs jolt my wax bed. The job requires
extra pluck and zeal from every young wage earner. How razorback-jumping frogs
can level six piqued gymnasts. Jackdaws love my big sphinx of quartz. The five
boxing wizards jump quickly while a waltz badinage nymph for quick jigs vex bud.
