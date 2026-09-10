#import "/src/lib.typ": *

#let bst-opts = (
  format: "acmsmall",
  nonacm: true,
  bib-backend: "bibtex",
  cite-style: "numeric",
  title: "BibTeX Backend Corrections",
)

#let bst-body = [
  = Cross-references and locators
  Two articles share a volume, so the volume joins the list #cite("FxCrossA", "FxCrossB").

  A locator on an author-only citation #cite("FxLocatorA", supplement: [p. 3]) and on a
  year-only citation #cite("FxLocatorA", form: "year", supplement: [Sec. 2]).
  The helpers take one too: #cite-author("FxLocatorB", supplement: [n. 4]) and
  #cite-year("FxLocatorB", supplement: [#emph[passim]]).
  Several keys attach the locator once: #cite("FxLocatorA", "FxLocatorB", form: "author", supplement: [p. 7]).
  Without a supplement the same forms stay bare: #cite("FxLocatorA", form: "author") and
  #cite("FxLocatorB", form: "year").

  #bibliography(("/tests/typst-only/fix-quirks.bib",))
]
