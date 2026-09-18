# Repository guidance

Read [CONTRIBUTING.md](CONTRIBUTING.md) for setup, validation, and documentation conventions.
Consult [DESIGN.md](DESIGN.md) before changing layout assumptions.
A change that should preserve rendering must pass the existing raster goldens.

Work on `main` unless the user requests otherwise.
Follow the user's instructions for staging, commits, and publication.

## Documentation scope

Change documentation only when the task makes existing guidance incorrect or leaves a necessary user workflow undocumented.
Put each explanation in one canonical location; do not repeat it across related files.
Prefer editing or deleting existing prose over adding sections.
Do not create documentation files unless explicitly requested.
Before finishing, remove documentation additions that merely describe the implementation, repeat another source, or record the work performed.
