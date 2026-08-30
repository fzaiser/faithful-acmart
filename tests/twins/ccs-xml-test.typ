// ccs-xml-test — CCS concepts supplied as the ACM CCS tool's <ccs2012> XML.
// Matched twin: ccs-xml-test.tex, which typesets the equivalent \ccsdesc lines.
// Exercises the XML input path end-to-end: grouping of an interleaved repeated area, the 500 (bold) / 300 (italic) / default-100 (roman) significance styles, and a trailing area-only repeat (Networks) whose only visible effect is acmart's @concepts counter quirk: the list ends "; " instead of ".".
#import "/src/lib.typ": acmart

#show: acmart.with(
  format: "acmsmall",
  title: "Classified Concepts",
  journal: "JACM",
  acm-volume: 37, acm-number: 4, acm-article: 111, acm-year: 2018, acm-month: 8,
  doi: "XXXXXXX.XXXXXXX",
  copyright: "acmlicensed", copyright-year: 2018,
  authors: (
    (name: "Grace Hopper", email: "hopper@example.org",
     affiliation: (institution: "Compiler Institute", city: "Arlington", country: "USA")),
  ),
  abstract: [
    A short note whose only purpose is to typeset a CCS Concepts line parsed from the ACM CCS tool's output.
  ],
  ccs: "
<ccs2012>
 <concept>
  <concept_id>10010520.10010553.10010562</concept_id>
  <concept_desc>Computer systems organization~Embedded systems</concept_desc>
  <concept_significance>500</concept_significance>
 </concept>
 <concept>
  <concept_id>10003033.10003083.10003095</concept_id>
  <concept_desc>Networks~Network reliability</concept_desc>
  <concept_significance>300</concept_significance>
 </concept>
 <concept>
  <concept_id>10010520.10010553.10010554</concept_id>
  <concept_desc>Computer systems organization~Robotics</concept_desc>
  <concept_significance>100</concept_significance>
 </concept>
 <concept>
  <concept_id>10003033</concept_id>
  <concept_desc>Networks</concept_desc>
  <concept_significance>100</concept_significance>
 </concept>
</ccs2012>
",
  keywords: ("classification", "concepts"),
)

= Body
The CCS line above groups the interleaved repeated area, styles the specifics by significance, and ends without a period because of the area-only concept.
