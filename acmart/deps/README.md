# Upstream dependencies of acmart (vendored for audit reference)

These are **not** part of the acmart bundle (the pristine acmart v2.18 sources
live in [`acmart/`](../)). They are the external LaTeX packages that acmart
*loads*, whose behaviour this Typst port also reproduces. They are kept here so a
reviewer can diff the Typst port against the exact source it was matched to,
without needing a TeX installation. Like everything under `acmart/`, this
directory is excluded from the published Typst Universe package (see
`typst.toml`).

All files are redistributed under the **LaTeX Project Public License (LPPL)
1.3c**, the license under which each is published.

| File | Package / version | Ported into | What is matched |
|---|---|---|---|
| `amsart.cls` | `amscls`, v2.20.6 (2020/05/29) | `src/parts/spacing.typ`, `src/formats/_base.typ` | acmart does `\LoadClass{amsart}`. The `\@typesizes` font-size ladder, the per-step `\baselineskip`, and the `\small`/`\med`/`\bigskip` = 0.7× scaling (→ 2.1/4.2/8.4pt, the documented "skips are NOT article defaults" gotcha) originate here, **not** in `acmart.dtx`. |
| `biblatex-software/software.bbx` | `biblatex-software`, 2022/08/01 | `src/parts/acmref-biblatex.typ` | The software bibliography drivers: `[SW]`/`[SW Rel.]`/`[SW Mod.]`/`[SW exc.]` labels, HAL/URL/VCS/SWHID identifier blocks. |
| `biblatex-software/software.dbx` | `biblatex-software`, 2022/08/01 | `src/parts/acmref-biblatex.typ` | The `software`/`softwareversion`/`softwaremodule`/`codefragment` data model + field inheritance. |
| `biblatex-software/english-software.lbx` | `biblatex-software`, 2022/08/01 | `src/parts/acmref-biblatex.typ` | English localization strings for the software labels. |

Source: TeX Live 2024 (`kpsewhich <file>`). To refresh, re-copy from a current
TeX distribution and update the versions above.

## Not vendored (intentionally)

- **`acmart.cls`** — generated from [`../acmart.dtx`](../acmart.dtx) via
  [`../acmart.ins`](../acmart.ins) (docstrip); the test harness builds it into
  `tests/out/latex/acmart.cls`. It is a build product, not a source.
- **`amsmath` / `amsthm` / `biblatex` core** — acmart's theorem styles
  (`acmplain`/`acmdefinition`) and the ACM `.bbx`/`.cbx` deltas are defined in
  acmart's own sources (already vendored); only the small, specific pieces above
  are inherited unmodified from an external package, so only those are kept here.
