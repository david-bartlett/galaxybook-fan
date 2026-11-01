# Release page: What's new at the top

PR #<n> · Claude · 2026-11-01

## What changed
- `.github/release-notes.sh`: prints the box at the top of `.github/release-install.md` (everything before its first `## `), then *What's new* (+ *Full changelog* collapsed), then the rest (1. Check, 2. Install, 3. Update). Was: all of `release-install.md`, then *What's new*.
- PLAN.md §7.1, CHANGELOG.

## Why
- David: *What's new* up the top, under the IMPORTANT box, and both repos' release pages alike (fingerprint-fix-sdcp gets the same layout and a numbered Update section in its own PR).

## Tested
- `bash .github/release-notes.sh 0.8.9`: box, What's new, Full changelog, 1. Check, 2. Install, 3. Update.

## For the next person
- Keep the box first in `release-install.md` and start each section with `## `: the script splits on the first `## `.
