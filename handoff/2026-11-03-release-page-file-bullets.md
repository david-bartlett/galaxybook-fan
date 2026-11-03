# Put a bullet before each file on the release page

PR #59 · Claude · 2026-11-03

## What changed
- `.github/release-install.md`, *2. Install*: each file in the *Download these files* column has a `•` in front.

## Why
- David wants it to match fingerprint-fix-sdcp's release page (its PR #167), although each row here has one file.

## Tested
- Rendered the page with `bash .github/release-notes.sh 0.9.9`: 3 files, each with a bullet, and the links unchanged.

## For the next person
- The live 0.9.9 page needs the same change by hand: Claude sessions can't edit releases.
