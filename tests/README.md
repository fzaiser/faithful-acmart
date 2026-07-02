# tests/

Test documents, organized by kind:

| path | contents |
|---|---|
| `twins/` | matched pairs `NAME.tex` (real LaTeX acmart) + `NAME.typ` (ours), identical content, diffed page-by-page |
| `typst-only/` | Typst-only docs with no LaTeX twin: smoke/alias/feature checks and the upstream-ref port (`sample-acmsmall.typ`, compared against the bundled sample) |
| `golden/` | committed Tier 1 golden raster hashes (`typst.sha256`) |
| `out/` | generated PDFs + diffs (gitignored; created by `test.py build`) |

Which directory a test lives in is derived from its `kind` in the matrix
(`Test.subdir`): `twin` → `twins/`, everything else → `typst-only/`. The matrix
and every gate live in [`../tools/test_matrix.py`](../tools/test_matrix.py) and
[`../tools/test.py`](../tools/test.py); see
[`../CONTRIBUTING.md`](../CONTRIBUTING.md) for how to build, check, and diff.
