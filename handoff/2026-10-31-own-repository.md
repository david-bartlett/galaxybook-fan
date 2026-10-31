# Own repository: project docs and VERSION

PR (this one) · Claude · 2026-10-31

## What changed
- galaxybook-fan moved out of `samsung-galaxybook-fixes` (`extras/galaxybook-fan`) into this repository with its full history (28 commits; a committed `__pycache__/*.pyc` was left out). The old folder there now only has a README pointing here, and is tagged `galaxybook-fan-final`.
- Added `PLAN.md`, `AGENTS.md`, `handoff/` and `CHANGELOG.md`, following fingerprint-fix-sdcp's layout.
- Added `VERSION` (`0.2.0`); `dkms.conf` and `install.sh` changed from `0.2` to `0.2.0` to match, since the release tool needs three numbers and keeps all three in step.
- README: the new files in the Files table.

## Why
- David is splitting fixes out of `extras/` into their own repositories, each private until it's ready, with the same contributor and release setup as fingerprint-fix-sdcp.

## Tested
- `bash -n` on the scripts; the version change is only the DKMS version string, and `install.sh` already removes every older `galaxybook-fan` DKMS version and `/usr/src/galaxybook-fan-*`.
- Not tested here: a real install. David reinstalls on each distro anyway, so the login check's notifications point at this folder instead of the old one.

## For the next person
- No release workflow or release tool yet: both are separate PRs (the workflow in this repository, the tool in samsung-galaxybook-dev-tools).
- Ideas in PLAN.md §10: Galaxy Book 6, packages, going public.
