# New-version check: every 6 hours, complete releases only

PR (this one) · Claude · 2026-10-31

## What changed
- `lib/update-check.sh`: GitHub at most every 6 hours (`GBFAN_UPDATE_EVERY` default 21600, was 86400). A newer release is announced only if `gbfan_release_ready` says its files are attached; if not, `last-update-check` isn't written, so the next hourly run looks again. Already-told versions are skipped before that request.
- `lib/update.sh`: new `gbfan_package_format` and `gbfan_package_pattern` (moved from `lib/galaxybook-fan`'s `package_format` and `cmd_update`, one copy for both), and `gbfan_release_ready VERSION`: the release's `SHA256SUMS` downloads and, for a package install, lists this system's package (an install.sh copy only needs `SHA256SUMS`).
- `lib/galaxybook-fan`: `updates check` says "being released, try again in a few minutes" instead of announcing an unfinished release; `update`'s SHA256SUMS error says the same; `updates on/status` say 6 hours.
- `.github/workflows/release.yml`: `gh release create --draft`, upload, then `gh release edit --draft=false --latest`, only if it's still a draft (a re-run for an old tag mustn't make it latest).
- Timer description, README, PLAN.md §4 and §7.1, CHANGELOG.

## Why
- David: an emergency release the same day waited until the next day. And `releases/latest` pointed to a new release for the moment between `gh release create` and `gh release upload`, so a check could announce it with no files for `galaxybook-fan update`.

## Tested
- Here: `bash -n`, shellcheck, the workflow's YAML; update-check.sh against a stub GitHub (see the PR).
- Not tested: a real release with the draft step (the next release is the first). Check on its run that the release only appears at the end, marked Latest.

## For the next person
- fingerprint-fix-sdcp has a similar updater; David asked whether it needs the same.
