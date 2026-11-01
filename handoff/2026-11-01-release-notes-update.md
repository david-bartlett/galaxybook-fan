# Release page: 3. Update

PR #<n> · Claude · 2026-11-01

## What changed
- `.github/release-install.md` (the release page's install section): new **3. Update** with `sudo galaxybook-fan update` (from 0.7.0) and `galaxybook-fan updates check` (from 0.8.0); older versions and `install.sh` copies install the file as in 2 (the text that was in the IMPORTANT box). The box's "Already installed?" now points to 3.
- CHANGELOG.

## Why
- David: someone watching the repository gets GitHub's email at once, but the check may not see the release for up to 6 hours.

## Tested
- `bash .github/release-notes.sh` renders it (sections 1–3, then What's new).
