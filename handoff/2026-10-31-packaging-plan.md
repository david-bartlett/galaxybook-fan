# Packaging plan

PR #7 · Claude · 2026-10-31

## What changed
- PLAN.md §10: the agreed plan for rpm, deb and Arch packages (one architecture-independent package per format; config generation in DKMS `PRE_BUILD`; a `galaxybook-fan` command for packaged installs; Book 5 only; six steps, one PR each). The old "Packages" idea is removed from the ideas list, now §11.

## Why
- David wants galaxybook-fan packaged like fingerprint-fix-sdcp, for the same distros. He agreed the `PRE_BUILD` approach and the command, and asked that the packages install only on a Galaxy Book 5.

## For the next person
- Next is step 1 (preparation). Check what each package manager does when a DKMS build fails during install before relying on it.
- Arch can't refuse in `.install` (pacman ignores its exit status), so the Book 5 check must also be in `gen-config.sh`.
