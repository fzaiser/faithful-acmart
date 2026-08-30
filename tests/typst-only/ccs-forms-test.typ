// ccs-forms-test — a document whose `ccs` is the ACM CCS tool's output pasted into a raw block (backslashes stay literal there, unlike in a string), locking the paste → parse-ccs → render pipeline into the golden.
// The paste's XML deliberately disagrees with its \ccsdesc line (300 vs 500): the \ccsdesc precedence shows in the golden as a BOLD specific, and the trailing area-only \ccsdesc ends the line in "; ".
// The parse-ccs input-form asserts live in tests/unit/frontmatter.typ; the rejection paths are ERROR_CASES in the matrix.
#import "/src/lib.typ": acmart

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

#show: acmart.with(
  format: "acmsmall",
  title: "CCS Input Forms",
  journal: "JACM",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  copyright: "acmlicensed", copyright-year: 2018,
  authors: (
    (name: "Ada Lovelace", email: "ada@example.org",
     affiliation: (institution: "Analytical Engine Institute", country: "UK")),
  ),
  abstract: [The CCS line below is parsed from the raw-block paste above.],
  ccs: paste,
  keywords: ("classification", "concepts"),
)

= Body
The CCS Concepts line ends in a semicolon: the paste's second concept is area-only.
