# New-version check: hourly and at each login

PR #38 · Claude · 2026-11-01

## What changed
- `lib/update-check.sh`: GitHub at most every 55 minutes (`GBFAN_UPDATE_EVERY` default 3300; was 21600), and always when `last-update-check` is from before this login (`graphical-session.target`'s `ActiveEnterTimestamp`). 55, not 60: the timer runs on the hour and the stamp is written a moment later, so with 60 the next hour's run would find it under an hour old and skip.
- Wording: timer description, `galaxybook-fan` messages and help table, README, the release page (`.github/release-install.md`), PLAN.md, `update.sh` comment. CHANGELOG.

## Why
- David: match fingerprint-fix-sdcp (hourly, and at each login), so a second release the same day isn't missed for hours.

## Tested
- `bash -n`, shellcheck; the login timestamp parsing (`@1793520000.123456` → 1793520000).

## For the next person
- fingerprint-fix-sdcp's check has the on-the-hour problem: its cache is reused if under 3600 s old, so on the hour it skips every other run. Fixed there separately.
