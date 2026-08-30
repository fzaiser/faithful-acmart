# Publishing `faithful-acmart` to Typst Universe

The runbook for packaging, publishing, and updating this package on
[Typst Universe](https://typst.app/universe/). Complements
[`CONTRIBUTING.md`](CONTRIBUTING.md) (the development/validation workflow).

Packages live in the [`typst/packages`](https://github.com/typst/packages) repo under
`packages/preview/<name>/<version>/` and are imported as `@preview/<name>:<version>`.
The authoritative rules are in that repo's
[`docs/`](https://github.com/typst/packages/tree/main/docs) — `manifest.md`,
`licensing.md`, `resources.md`, `documentation.md`, `tips.md`. This file records how
those rules were applied here so future releases don't have to re-derive them.

## Rules that shaped this package

- **Name.** The bare/canonical name (`acmart`) and unamended entity names (`acm`) are
  reserved for official packages. Community templates use a *unique, non-descriptive*
  part + a descriptive part → **`faithful-acmart`** (precedented by `clean-acmart`).
- **Description.** ~40–60 chars, must **not** contain "Typst", "package", or "template",
  and should indicate the document type. Ours:
  `Every ACM paper format, matching LaTeX acmart.`
- **License.** Must be OSI-approved or a CC variant; a `LICENSE` file must exist and
  match the manifest. Per-part licensing uses an SPDX `AND` expression documented in the
  README. Ours: **`MIT AND MIT-0`** — package MIT, `template/` dir MIT-0 so instantiated
  papers carry no attribution burden.
- **Fonts cannot be bundled.** `resources.md`: shipping fonts in a package (or template
  dir) is *not allowed*. We document installation instead (see below).
- **Copyrighted / trademarked assets** may ship only if the holder's policy clears it,
  and the README must mark which files aren't under the package license.
- **Template packages** must declare `[template]`, at least one `category`, and a
  `thumbnail`. No large files / large numbers of files; exclude dev-only content.

## Current manifest (already configured in [`typst.toml`](typst.toml))

| Field | Value |
|---|---|
| `name` / `version` | `faithful-acmart` / `0.1.0` |
| `entrypoint` | `src/lib.typ` |
| `compiler` | `0.14.0` (stable math-symbol names for the `.bib` TeX layer; PDF tags) |
| `license` | `MIT AND MIT-0` (+ `LICENSE`, `template/LICENSE`) |
| `description` | `Every ACM paper format, matching LaTeX acmart.` |
| `categories` / `disciplines` | `["paper"]` / `["computer-science"]` |
| `[template]` | `path = "template"`, `entrypoint = "main.typ"`, `thumbnail = "thumbnail.png"` |

### What ships vs. what's excluded

**Ships:** `src/` (`lib.typ`, `formats/`, `parts/`, `assets/cc/`), `template/`
(`main.typ`, `refs.bib`, `LICENSE`), `README.md`, `LICENSE`, `typst.toml`, and
`thumbnail.png` (auto-excluded from the downloaded bundle but present for the preview).

**Excluded** (dev-only, via `exclude` in `typst.toml` — add new dev docs here):
`/.github`, `/.venv`, `/acmart`, `/fonts`, `/tests`, `/tools`, `/tmp`,
`/.gitignore`, `/.python-version`, `/CLAUDE.md`, `/CONTRIBUTING.md`, `/DESIGN.md`,
`/PUBLISHING.md`, `/TODO.md`, `/acmart-upstream-findings.md`, `/pyproject.toml`,
`/uv.lock`, `/src/README.md`, `/src/assets/acm-jdslogo.png`.

## Assets & fonts (the parts that need care)

- **Fonts — not bundled.** The README tells users to install `Libertinus Serif`,
  `Libertinus Sans`, `Libertinus Math`, and `Inconsolatazi4` and pass `--font-path`
  (CLI) or add them to the project (web app). Only *Libertinus Serif* is embedded in
  Typst, so the others fall back until installed. The dev copies live in `fonts/`
  (excluded).
- **ACM JDS logo — not bundled.** It is ACM's trademark. The `acmcp` format takes a
  user-supplied `acmcp-logo: image(...)` and errors if it's missing; the dev copy
  `src/assets/acm-jdslogo.png` is excluded.
- **CC badges — official, unmodified.** `src/assets/cc/cc-<type>.svg` are the official
  Creative Commons 88×31 press-kit SVGs, downloaded directly from
  `https://mirrors.creativecommons.org/presskit/buttons/88x31/svg/<type>.svg`
  (`cc-zero.svg` for CC0). They are CC **trademarks** — not in the SPDX license; the
  `cc` copyright block links each badge to its licence deed. See
  [`src/assets/cc/README.md`](src/assets/cc/README.md). To refresh them, re-download
  from the same URLs — do **not** re-vectorize (that counts as modifying the mark).

## Local testing (the package symlink)

Building the example or running `typst init` locally needs the package linked into
Typst's data directory (matched twins import `/src/lib.typ`, so `test.py check` does
not need it):

```sh
ln -sfn "$PWD" "$HOME/Library/Application Support/typst/packages/preview/faithful-acmart/0.1.0"
# then:
typst init @preview/faithful-acmart:0.1.0
```

The symlink sits in the `preview` namespace deliberately, so that `typst init` and the
template's literal `@preview` import can be tested unchanged (`@local` could not
exercise either). The flip side: Typst searches the data directory before the package
cache, so once this version is published the symlink **shadows the released copy** for
every document on this machine. Remove it after testing, and suspect it first if local
output ever disagrees with what users see.

## Pre-submission checklist

```sh
# 1. Harness green
tools/venv/bin/python tools/test.py check

# 2. Thumbnail: page 1 of the example, longer edge >=1080 px, <=3 MiB
tools/tc compile --format png --pages 1 --ppi 250 template/main.typ thumbnail.png
#    optional: oxipng -o4 --strip safe thumbnail.png

# 3. The regression harness assembles the manifest-filtered bundle, asserts an
#    allowlist, checks the README's links and @preview versions, compiles a fresh
#    template project plus every README ```typst example from it, and runs the
#    official linter offline:
tools/venv/bin/python tools/test.py package

# 4. To install/update the official linter (needs rustc >= 1.85.1)
cargo install --git https://github.com/typst/package-check --locked
```

Also confirm `authors` and `repository` in `typst.toml` and the copyright holder/year
in `LICENSE` / `template/LICENSE`.

> **Note:** `typst-package-check` reports a `repository … unreachable` error until the
> GitHub repo is actually pushed and public — expected before the first push.

## Submitting (first publish)

1. Fork `typst/packages`. A sparse checkout keeps it small:
   ```sh
   git clone --depth 1 --no-checkout --filter="tree:0" git@github.com:<you>/packages
   cd packages && git sparse-checkout init
   git sparse-checkout set packages/preview/faithful-acmart
   git remote add upstream git@github.com:typst/packages
   git config remote.upstream.partialclonefilter tree:0
   git checkout main
   ```
2. Assemble the submission with the harness. It stages the shipped files, rewrites the
   README's relative links to unshipped files to the `v<version>` tag, and writes the
   bundle only after every package check passes (note the doubled `packages/`):
   ```sh
   tools/venv/bin/python tools/test.py package \
     --out <packages checkout>/packages/preview/faithful-acmart/<version>
   ```
   Never copy a `.git` directory into the checkout; submodules are not accepted.
3. Commit and open a PR. First-time authors get extra review; after merge + CI it can
   take ~30 min to appear on Universe. Published versions are permanent.

## Releasing a new version

1. Bump `version` in `typst.toml`.
2. Update `template/main.typ`'s import to `@preview/faithful-acmart:<new-version>` and
   the version numbers in `README.md` — `test.py package` fails on any `@preview`
   import that disagrees with the manifest.
3. Re-point the local symlink (above) to the new version.
4. Regenerate `thumbnail.png` if the output changed.
5. Tag the release commit in the main repo and push the tag before assembling the
   release copy: `git tag -a v<new-version> <commit> -m "faithful-acmart <new-version>"`
   then `git push origin v<new-version>`.
6. Assemble a **new** `packages/preview/faithful-acmart/<new-version>/` directory with
   `test.py package --out` (never edit an already-published version) and open a PR.
   The updater should be the same author as the previous version, or the previous
   author is consulted.

## Gotchas (learned the hard way)

- **Fonts can't be bundled** — only Libertinus Serif is embedded; sans/math/mono need a
  user install. Everything else about "faithful" output depends on this.
- **`MIT AND MIT-0`** requires *both* `LICENSE` (MIT) and `template/LICENSE` (MIT-0) to
  be present and the split noted in the README.
- **The thumbnail is auto-excluded** and must not be `image()`'d anywhere in the package.
- **There are two README contexts.** The repository's `README.md` uses relative links
  throughout — they work on GitHub, in editors, and in forks. Staging keeps each link
  whose target ships and rewrites the rest to the immutable release tag
  (`…/blob/v<version>/DESIGN.md`, `…/tree/v<version>/fonts`; images go to
  `raw.githubusercontent.com` so they render on Universe). Never commit that rewrite
  back to the development README, and never write absolute `…/main/…` links there: the
  package gate rejects them, verifies every relative link's target exists, and compiles
  each fenced `typst` example in the README against the staged bundle. The gate parses
  only the canonical forms — plain inline `](target)` links (no titles, no reference
  style) and column-0 ` ```typst ` fences — and fails on anything else rather than
  letting it slip past the rewrite. Create and push the tag before submitting the
  staged copy; otherwise its links 404.
- **Community tooling:** `typst-package-check` (lint), `tytanic` (tests), `typship`
  (install/submit).
