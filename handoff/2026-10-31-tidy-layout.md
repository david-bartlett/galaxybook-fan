# Tidier layout: module/ and lib/

PR #5 · Claude · 2026-10-31

## What changed
- `git mv` (history kept): the module's files to `module/` (`galaxybook_fan.c`, `galaxybook_fan_config.h`, `Makefile`, `dkms.conf`); the installer's helpers to `lib/` (`dsdt-fan-config.py`, `samsung-galaxybook-fan-check.sh`). `install.sh` and `uninstall.sh` stay at the top.
- `install.sh` finds them through `MODULE_SRC` and `LIB_SRC`. `--record-state` still records the top folder, where `install.sh` is, so the notifications don't change.
- The release workflow checks `module/dkms.conf`. README, PLAN.md and AGENTS.md list the new paths.

## Why
- David wanted the same kind of tidy layout as fingerprint-fix-sdcp. `packaging/` can sit alongside these later.

## Tested
- `bash -n`, `py_compile`; every path `install.sh` reads through `MODULE_SRC` and `LIB_SRC` exists in the new layout. No kernel headers here, so no module build.
- Not tested here: a real install and uninstall.

## For the next person
- **The release tool must update `module/dkms.conf`**, not `dkms.conf`. This is a matching samsung-galaxybook-dev-tools PR; merge both before the next release. With the old tool, a release stops before changing anything (it can't find the version line).
- No LICENSE file yet: David to choose (the module is marked GPL-2.0).
