# TODO

- Investigate replacing pikepdf with PyMuPDF to reduce dependencies, assessing support for PDF structure, reading-order and link checks, and side-by-side PDF generation without adding custom PDF parsing or weakening validation.
- Investigate reducing the layout passes a paper needs; the sample papers leave one of Typst's five unused. Leads: theorems, proofs, and citations read `cfg-state` in context, so they render only in pass 2, which show rules inside `acmart` would avoid; find other state updates or counters emitted inside `context`.
