# Package install wording

PR #16 · Claude · 2026-10-31

## What changed
- `lib/package-scripts.sh configure`: the first line now reads "checking the module for KVER; DKMS builds it from this laptop's firmware if needed", because on a reinstall or upgrade the next line is "already built for KVER".

## Tested
- `bash -n`. Message text only; no logic changed.

## For the next person
- Next is packaging step 4, the deb (PLAN.md §10.3). It reuses `install-files.sh`, `package-scripts.sh` and `pkg-pre.sh.in`; maintainer scripts run under dash.
