#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", nonacm: true, bib-backend: "biblatex", cite-style: "author-year")

#heading(numbering: none, level: 1)[Versions]
A version is spelled out wherever a driver prints one: in an article #cite("VerArticle"), a manual #cite("VerManual"), a misc #cite("VerMisc"), an online entry #cite("VerOnline"), a report #cite("VerReport") and a dataset #cite("VerDataset") -- but the thesis driver prints none #cite("VerThesis"), and software keeps its own inline wording #cite("NdSoftware").
A version inherits its parent's date only when it has none of its own #cite("SwPlainChild"): a date that starts open supplies an empty year, and nothing is inherited over it #cite("SwOpenChild").
A parent two cited versions point at joins the list in its own right #cite("SwOpenChild", "SwPlainChild"), where a parent with one cited version does not #cite("SwLoneChild").
A cross-referenced entry takes every field of its parent that it has none of its own, and the parent's title arrives in whichever slot the child's type asks for #cite("IhFirst", "IhSecond"): a booktitle here, and a journal title in an article #cite("IhArticle").
A cross-referenced entry reads its parent through BibTeX's field and type names alike, so a child's own journal or address blocks what the parent would pass down #cite("AlKid", "AlConf"), and it takes every component of the parent's date, day and range and all #cite("DcKid") -- a date of its own that biber cannot read blocks nothing #cite("DrKid").
An entry that names no container still opens one #cite("SoloIn"), and a chapter joins its publisher with a comma where a chapter number would take a stop #cite("PgBook").
A legacy field spelling renames rather than overwrites, so an entry that carries both keeps the canonical one #cite("TwoSpellings"), and a proceedings entry prints every stage its own driver has #cite("FullProc").
A date biber cannot read is no date at all and blocks no inheritance #cite("BogusKid"), while a date it can read stops its parent's range where it stands #cite("ChainKid").
Pages take their comma with no publisher ahead of them #cite("NoPubPages"), an archive of its own parenthesizes the class #cite("CustomEprint"), and an editor behind a bare container keeps the lower case the colon left #cite("NoBookEditor").
An event prints its addon and its own date range #cite("EvFull"), a proceedings with nothing between its title and its date keeps the comma the stages between them would have used #cite("PrMin", "PrSer"), and a part prints without a volume #cite("PtOnly").
A date biber rejects outright leaves the parent's to be inherited #cite("DtM13"), an open end does not outlive the child that dates itself #cite("OpKid"), an empty canonical spelling keeps the legacy one out #cite("EmCanon"), and a single page is one #cite("PgOne").

#heading(numbering: none, level: 1)[Misc, online and the types that alias to them]
A misc entry always shows a parenthesized date #cite("MiscMonth"), before which it puts its location and organization #cite("MiscOrgLoc", "MiscNoName").
It drops its URL for a DOI #cite("MiscDoiUrl") and runs an eprint straight on from a URL #cite("MiscUrlEprint").
An online entry does the opposite: it never shows a DOI #cite("OnlineDoiUrl", "OnlineDoiOnly"), ignores howpublished and type #cite("OnlineHowOrg"), and dates itself only when it has a month #cite("VerOnline", "OnlineWww").
A presentation #cite("MiscPresentation") and a paper under review #cite("MiscUnderreview") have no driver of their own and take the misc one.

#heading(numbering: none, level: 1)[Undated entries]
An entry with no date falls back to a fixed stand-in #cite("NdArticle", "NdMisc"), which the author-year style letters in parentheses when two entries share it #cite("NdDatasetA", "NdDatasetB").
The parentheses a driver would have put a date inside are printed empty #cite("NdDatasetMonth"), and a driver that would have printed nothing prints nothing #cite("NdOnline").

#bibliography("/tests/twins/biblatex-misc-test.bib")
