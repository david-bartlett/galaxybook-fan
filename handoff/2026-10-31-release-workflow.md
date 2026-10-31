# Release workflow

PR #3 · Claude · 2026-10-31 (first opened as #2, which was merged into the project-docs branch instead of main)

## What changed
- `.github/workflows/release.yml`: on a `v*` tag (or run by hand for a tag) it checks `VERSION`, `dkms.conf`, `install.sh` and `CHANGELOG.md` all have the tag's version, then creates the GitHub release.
- `.github/release-notes.sh` (same as fingerprint-fix-sdcp's) and `.github/release-install.md`: the release page is install steps, *What's new* from the bold CHANGELOG lines, and the full section collapsed.
- PLAN.md §4 and §7.1 describe it.

## Tested
- `bash -n` on the notes script; the workflow YAML parses; the notes script run on a copy with `## Unreleased` renamed to a version gives the expected What's new and Full changelog.
- Not tested: the workflow on GitHub. The first real release will run it.

## For the next person
- No packages yet: users install from the release's source code. Packages are an idea in PLAN.md §10.
