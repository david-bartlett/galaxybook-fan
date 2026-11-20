# How it's built, SECURITY.md and CONTRIBUTING.md

PR #61 · Claude · 2026-11-17

## What changed
- README: "How it stays safe" gains **It only reads** (checked: the module's only firmware call is `acpi_evaluate_integer` on the fan field); a new **How it's built and tested** section (Claude writes, Codex reviews, David tests every release on real hardware across five distros, PRs and SHA256SUMS, the update check as the only network use).
- New `SECURITY.md` and `CONTRIBUTING.md`; PLAN.md's file map lists them; CHANGELOG has Unreleased lines (added at the end of the section).

## Why
- David asked how to raise confidence in the public repos: being open about AI use and the testing, and a private way to report security problems, were what was missing (the tested-on table, uninstall docs and SHA256SUMS were already there).

## Tested
- Markdown only; links and anchors checked against the repo.
- Not tested: GitHub's private vulnerability reporting must be turned on in the repository's settings for SECURITY.md's link to work.

## For the next person
- The README's AI wording is David's to adjust.
