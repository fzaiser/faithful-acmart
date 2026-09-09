# Development fonts

These OpenType files come from TeX Live's `texmf-dist/fonts/opentype/public/{libertinus-fonts,inconsolata}` and are licensed under the [SIL Open Font License](OFL.txt).
Refresh them from those directories.

`tools/tc` uses these copies and ignores system fonts to keep builds reproducible.
Some system Libertinus builds lack OpenType features needed for small caps, ligatures, and kerning.
The published package excludes fonts; installation instructions are in the [main README](../README.md#fonts).
