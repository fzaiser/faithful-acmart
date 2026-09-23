# Repository guidance

Read [CONTRIBUTING.md](CONTRIBUTING.md) for setup, validation, and documentation conventions.
Consult [DESIGN.md](DESIGN.md) before changing layout assumptions.
A change that should preserve rendering must pass the existing raster goldens.

Work on `main` unless the user requests otherwise.
Follow the user's instructions for staging, commits, and publication.

## Documentation and comments

These constraints apply to every task, including implementation, debugging, and review.
Do not add documentation or comments merely to demonstrate that work was done.

For documentation files:

- Unless documentation work is requested, edit docs only to correct guidance made inaccurate by the change or to explain a necessary user workflow affected by the task.
- Do not create documentation files unless explicitly requested.
  A request to implement, fix, review, or test something does not authorize a report file.
- Put plans, investigation results, review findings, test summaries, and completion reports in chat.
  Private working notes belong in the ignored `scratch/` directory; generated test output belongs in `tests/out/`.
  Do not append these reports to existing documentation either.
- Describe how the system works now and what the reader needs to do.
  Keep change history in changelogs, commit messages, or PR descriptions; omit experiment logs, abandoned approaches, and task narratives from ordinary docs.
- Keep each explanation in one canonical location, following [CONTRIBUTING.md](CONTRIBUTING.md#documentation).
  Link instead of duplicating; prefer updating existing prose over adding sections.
- Write concise, complete explanations for a human with less context.
  Use lists or tables when they make choices or steps easier to scan.
  Keep local implementation details beside the code, rather than turning `DESIGN.md` into a walkthrough of functions or layout passes.

For code comments:

- Add a comment only for an important fact that is not apparent from the code: a constraint, invariant, upstream quirk, workaround, or surprising API contract.
  Useful contracts include arguments accepted without effect and distinctions between `auto`, `none`, and explicit values.
- Explain why the code needs its shape, rather than narrating its operations.
  Keep the explanation close to the code it qualifies.
- Omit task history, experiment counts, test results, and descriptions of deleted code.
  Do not repeat values, signatures, or behavior already clear from names and expressions.
- Preserve useful explanations when shortening comments.
  Concision is not a reason to remove a non-obvious contract or the rationale for a safeguard.

### Required final review

Before finishing, inspect the documentation and comment diff, including staged changes:

1. Check that no unrequested report or documentation file was added.
2. For each added or edited explanation, identify the reader's question it answers.
   Remove material that only records the work, repeats another source, or restates the code.
3. Check that useful contracts and constraints survived the cleanup, and that the remaining prose describes current behavior.

Perform this review as part of the work; do not create a checklist or report file for it.
