# Show the command first on the release page

PR #58 · Claude · 2026-11-03

## What changed
- `.github/release-install.md`, *2. Install*: the columns are now Distro, Install command, Download these files, and each file links to that file in the same release, through `@VERSION@`.

## Why
- David asked for this to match the release page of fingerprint-fix-sdcp (its PRs #165 and #166).

## Tested
- `bash .github/release-notes.sh 0.9.9` writes the page with the table in the new order and the version filled in.
- All 4 download links on that page are real files in the 0.9.9 release.
- How it looks on a real release page can't be seen until the next release.

## For the next person
- The live 0.9.9 page keeps the old table until David updates it by hand: Claude sessions can't edit releases. This template gives the new table to every later release.
