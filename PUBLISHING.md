# Publishing

Releases are submitted to [typst/packages](https://github.com/typst/packages) under `packages/preview/<name>/<version>/`.
Consult its [package guidelines](https://github.com/typst/packages/tree/main/docs) for current submission requirements.
[typst.toml](typst.toml) determines the package contents; new development files must be excluded there.

## Local package testing

To build the starter template directly or test `typst init`, link the repository into Typst's package data directory at `packages/preview/faithful-acmart/<version>`.
Use the manifest version and create the parent directories first.
On macOS, the data directory is `~/Library/Application Support/typst`; on Linux it is `$XDG_DATA_HOME/typst`, defaulting to `~/.local/share/typst`.

This local link takes precedence over a downloaded release of the same version.
Remove it after testing.
The regression and package checks already arrange their own inputs and need no link.

## Prepare a release

Complete these steps before submitting a new package version:

1. Review the [changelog](docs/changelog.md), including upgrade instructions for changed defaults and stricter validation, and replace its Unreleased heading with the version and release date.
   Update the manifest version and the package imports in `README.md`, `docs/`, and `template/main.typ`.
2. Run `uv run python tools/test.py docs` to refresh the SVG illustrations, inspect any changes, and run the [regression suite](CONTRIBUTING.md#validation).
3. If the example's appearance changed, rebuild the thumbnail with the local package link in place:

   ```sh
   tools/tc compile --format png --pages 1 --ppi 250 template/main.typ thumbnail.png
   ```

4. Check the package authors, repository URL, licenses, and asset provenance.
   Font files and the development ACM logo must remain excluded; the [CC badge notice](src/assets/cc/README.md) accompanies the shipped badges.
5. Commit the release and create its `v<version>` tag.
6. Assemble and validate the submission outside this repository:

   ```sh
   uv run python tools/test.py package \
     --out <packages-checkout>/packages/preview/faithful-acmart/<version>
   ```

The package command writes the bundle only after its checks pass and requires an empty destination.
It converts relative documentation links to GitHub views at the release tag, while keeping images and PDFs directly accessible.
Use relative inline links in source documents so the package command can rewrite them.

## Submit

Publish the release tag before submitting the bundle, so its documentation links resolve.
Commit the generated directory in a checkout of `typst/packages` and open a pull request.
Use a new version directory for every release; published versions are immutable.
