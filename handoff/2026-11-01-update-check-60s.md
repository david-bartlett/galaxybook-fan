# New-version check 60 s after login

PR #<n> · Claude · 2026-11-01

## What changed
- `packaging/files/update-check.timer.in`: `OnActiveSec=60s` (was 30s), with a comment why; descriptions and comments in `update-check.sh`, `package-scripts.sh`, `fanpaths.sh`, README, PLAN.md say 60 s. README's update paragraph tidied (a repeated "tells you").
- CHANGELOG.

## Why
- David: when both fixes have a new release, their notifications came together. fingerprint-fix-sdcp's check stays at 30 s after login.

## Tested
- `bash packaging/render.sh` of the timer; `bash -n` on the changed scripts.

## For the next person
- The timer applies at the next login (or when a package install starts it in a running session); the hourly runs aren't changed, so the two can still coincide at an hour, rarely.
