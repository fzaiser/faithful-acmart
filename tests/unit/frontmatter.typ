#import "/src/parts/frontmatter.typ": format-received, render-ccs-concepts

// These content-producing cases check that input normalization completes without panicking.
#let is-content(x) = type(x) == content

#assert(is-content(format-received((("2020",),))))
#assert(is-content(format-received((("Received", "2020"), ("revised", "2021")))))
#assert(is-content(format-received(("2020", ("revised", "2021")))))
#assert.eq(format-received("2020"), "2020")

#assert(is-content(render-ccs-concepts((
  (500, "Information systems"),
  (300, "Information systems", "Data management systems"),
))))

// The XML and ccdesc significance deliberately disagree to test precedence.
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
#assert.eq(parse-ccs(paste), from-desc)
#assert.eq(parse-ccs(paste.text), from-desc)
#assert.eq(parse-ccs([ #paste ]), from-desc)
#assert.eq(parse-ccs("\\ccsdesc [ 300 ] {Networks~Network reliability}"),
  ((300, "Networks", "Network reliability"),))

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

#assert.eq(parse-ccs(((500, "Networks", "Network reliability"),)),
  ((500, "Networks", "Network reliability"),))
#assert.eq(parse-ccs(()), none)
#assert.eq(parse-ccs(none), none)
