# Show the command first on the release page

PR #58 · Claude · 2026-11-03

## What changed
- `.github/release-install.md`, *2. Install*: the columns are now Distro, Command, File to download first.

## Why
- David asked for this to match the release page of fingerprint-fix-sdcp (its PR #165).

## Tested
- `bash .github/release-notes.sh 0.9.9` writes the page with the table in the new order and the version filled in.
- How it looks on a real release page can't be seen until the next release.

## For the next person
- The release page for 0.9.9 keeps the old table; the change shows from the next release.
