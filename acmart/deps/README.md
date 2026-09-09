# Upstream reference dependencies

These sources accompany the bundled acmart class so its inherited behavior can be inspected and tested against fixed versions.
They were copied from TeX Live 2024 and are redistributed under the LaTeX Project Public License 1.3c.

| Source | Version |
|---|---|
| `amsart.cls` | amscls 2.20.6, 2020/05/29 |
| `biblatex-software/` | 2022/08/01 |

The test harness stages these files with the class and bibliography styles when building LaTeX references.
To update them, locate the files with `kpsewhich`, copy them from the chosen TeX distribution, and update the provenance above.

[acmart.dtx](../acmart.dtx) is the class source.
The committed [acmart.cls](../acmart.cls) is its generated, non-tagged form, included for convenient inspection.
Regenerate it from the `acmart/` directory with:

```sh
pdflatex -interaction=nonstopmode acmart.ins
```
