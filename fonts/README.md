# fonts/ — bundled fonts

acmart uses Libertinus (text/sans/math) and Inconsolata/`zi4` (mono). The
Libertinus builds shipped in some system font folders are **feature-stripped**
(empty GSUB → no small caps, ligatures, or kerning), which silently breaks
theorem small caps and degrades text. So the **full OpenType** builds are bundled
here and used by every build via `tools/tc` (`--font-path fonts
--ignore-system-fonts`).

Contents (all SIL OFL — see `OFL.txt`):

- `LibertinusSerif-*` (Regular/Bold/Italic/BoldItalic/Semibold/SemiboldItalic)
- `LibertinusSans-*` (Regular/Bold/Italic)
- `LibertinusMath-Regular` (math is single-weight)
- `Inconsolatazi4-Regular/Bold` (Inconsolata has no italic — this is complete)

Source: TeX Live, `texmf-dist/fonts/opentype/public/{libertinus-fonts,inconsolata}`.
To refresh, copy those OTFs here. End users installing the published *package*
must have full Libertinus + Inconsolata installed system-wide (Typst packages
don't bundle fonts).
