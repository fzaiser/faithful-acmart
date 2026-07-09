// bib-relative-test — regression test that a RELATIVE bibliography path resolves
// against the user's file, on the `bibtex` engine backend (the harder case). The
// `bibliography` shadow threads a single positional path as an un-indexed `arguments`
// value all the way to the engine's `read(..args)`, and an `arguments` value keeps
// the caller's location — so `"bib-relative.bib"` resolves next to THIS file, and its
// cite @RelKey renders. If the shadow instead extracted the path string, the origin
// would be lost and the engine would search the package's src/ dir and fail to
// compile. (Multiple files or a `title:` force indexing, so they require an absolute
// path — covered by the `bibtex-relative-path` expected-error case. The default
// "typst" backend forwards to std.bibliography(..args), which is relative-safe too.)
#import "/src/lib.typ": *
#show: acmart.with(format: "acmsmall", title: "Relative Bibliography Path", doi: none, bib-backend: "bibtex")

= Body
A citation of the sibling bibliography @RelKey.

#bibliography("bib-relative.bib")
