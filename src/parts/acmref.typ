// Public facade for the pure-Typst ACM bibliography backends.
//
// The implementation is split by responsibility:
//   * acmref-common.typ: rendering/state primitives shared by both backends,
//   * acmref-bst.typ: ACM-Reference-Format.bst renderer,
//   * acmref-biblatex.typ: ACM BibLaTeX + software drivers,
//   * acmref-cite.typ: cite registration, sorting, labels, and bibliography output.

// Typst re-exports imported bindings, so a plain `#import` here already makes these
// names available to importers of this facade — no re-`let` aliasing needed.
#import "acmref-common.typ": tex-render-state
#import "acmref-cite.typ": bbl-cite, bbl-citet, bbl-citealt, bbl-citeyear, bbl-citeyearpar, bbl-citeauthor, bbl-shortcite, bbl-bibliography, cite-style-state
