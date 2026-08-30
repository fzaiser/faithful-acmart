// Direct unit tests for pure top-matter helpers (src/parts/frontmatter.typ).
//
// These run WITHOUT the LaTeX/pdftotext harness: the file compiles, and a failing
// #assert (or a panic in an exercised helper) aborts the Typst compile. Run
//   tools/tc compile tests/unit/frontmatter.typ /dev/null
// or via the harness as the "unit" tier (tools/test.py unit / test.py check).

#import "/src/parts/frontmatter.typ": format-received, render-ccs-concepts

// format-received returns content, so we assert on its type: the point of these
// cases is that malformed/edge input is handled without panicking.
#let is-content(x) = type(x) == content

// Regression: a bare date wrapped in a 1-element array used to panic on item.at(1)
// (index out of bounds). It is now treated as a bare date (stage defaults in).
#assert(is-content(format-received((("2020",),))))
// The documented forms still work: (stage, date) pairs and bare-date strings.
#assert(is-content(format-received((("Received", "2020"), ("revised", "2021")))))
#assert(is-content(format-received(("2020", ("revised", "2021")))))
// A non-array value passes through verbatim.
#assert.eq(format-received("2020"), "2020")

// render-ccs-concepts must tolerate both a 2-tuple (significance, area) with no
// specific and a full 3-tuple, exercising the .at(2, default: none) path.
#assert(is-content(render-ccs-concepts((
  (500, "Information systems"),
  (300, "Information systems", "Data management systems"),
))))

// parse-ccs normalizes the `ccs` option's input forms to (significance, area,
// specific) tuples. The ACM tool's paste carries both the CCSXML and the
// \ccsdesc lines; \ccsdesc wins — it is what LaTeX typesets — so the XML's
// deliberately different significance (300) must NOT survive.
#import "/src/parts/frontmatter.typ": parse-ccs
#let paste = ```
\begin{CCSXML}
<ccs2012>
 <concept>
  <concept_id>10011007.10010940.10010941.10010942.10010948</concept_id>
  <concept_desc>Software and its engineering~Virtual machines</concept_desc>
  <concept_significance>300</concept_significance>
 </concept>
</ccs2012>
\end{CCSXML}

\ccsdesc[500]{Software and its engineering~Virtual machines}
\ccsdesc{Software and its engineering}
```
#let from-desc = (
  (500, "Software and its engineering", "Virtual machines"),
  (100, "Software and its engineering", none),
)
#assert.eq(parse-ccs(paste), from-desc) // raw block input
#assert.eq(parse-ccs(paste.text), from-desc) // the same paste as a plain string
#assert.eq(parse-ccs([ #paste ]), from-desc) // raw block wrapped in a content block
// \ccsdesc tolerates whitespace around the significance and before the argument.
#assert.eq(parse-ccs("\\ccsdesc [ 300 ] {Networks~Network reliability}"),
  ((300, "Networks", "Network reliability"),))

// XML-only input: entity decoding, whitespace trimming, a missing
// <concept_significance> (defaults to 100, like \ccsdesc's optional argument),
// and an area-only concept.
#let xml-only = "
<ccs2012>
 <concept>
  <concept_desc> Information systems~Language models </concept_desc>
 </concept>
 <concept>
  <concept_desc>Hardware &amp; emerging technologies</concept_desc>
  <concept_significance>300</concept_significance>
 </concept>
</ccs2012>
"
#assert.eq(parse-ccs(xml-only), (
  (100, "Information systems", "Language models"),
  (300, "Hardware & emerging technologies", none),
))

// Tuple lists pass through unchanged; no concepts at all normalizes to none
// (the CCS section is omitted, as in LaTeX with an empty \@concepts).
#assert.eq(parse-ccs(((500, "Networks", "Network reliability"),)),
  ((500, "Networks", "Network reliability"),))
#assert.eq(parse-ccs(()), none)
#assert.eq(parse-ccs(none), none)
