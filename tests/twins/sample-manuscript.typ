// sample-manuscript — port of the upstream acmart sample (acmart/samples,
// docstrip option `all,proceedings,manuscript`). Shares the authors/abstract/
// CCS/body with the other `all` samples (see _sample-common.typ); only the
// preamble differs: the `manuscript` review style with screen+review options and
// proceedings (conference) metadata. Diffed page-by-page against
// out/latex/manuscript.pdf.
#import "/src/lib.typ": acmart
#import "_sample-common.typ": sample-authors, sample-abstract, sample-ccs, sample-received, sample-body

#show: acmart.with(
  format: "manuscript",
  screen: true,
  review: true,
  title: "The Name of the Title Is Hope",
  conference: (
    short: "Conference acronym 'XX",
    name: "Make sure to enter the correct conference title from your rights confirmation email",
    venue: "Woodstock, NY",
    date: "June 03–05, 2018",
  ),
  isbn: "978-1-4503-XXXX-X/2018/06",
  doi: "XXXXXXX.XXXXXXX",
  acm-year: 2018,
  copyright: "acmlicensed", copyright-year: 2018,
  short-authors: "Trovato et al.",
  authors: sample-authors,
  abstract: sample-abstract,
  ccs: sample-ccs,
  received: sample-received,
)

#sample-body(documentclass: "manuscript,screen,review")
