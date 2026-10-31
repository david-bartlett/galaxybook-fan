# The check: the distro's own name

PR #13 · Claude · 2026-10-31

## What changed
- `tools/check-galaxybook-fan.sh`: `distro_name` uses `/etc/lsb-release`'s `DISTRIB_DESCRIPTION` when its `DISTRIB_ID` differs from os-release's `ID`, with the os-release name in brackets ("MX 25.1 Infinity (based on Debian GNU/Linux 13 (trixie))"). Otherwise os-release's `PRETTY_NAME`, as before.

## Why
- On MX the check said "Debian GNU/Linux 13 (trixie)", which is accurate but unclear in a *Works on my model* report.

## Tested
- `distro_name` with os-release / lsb-release contents for MX, Mint, Ubuntu, Fedora (no lsb-release) and CachyOS: only MX changes. Not run on MX itself yet (David pulls it there).
