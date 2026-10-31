# Packaging step 1: DKMS config step, shared paths, the galaxybook-fan command

PR #10 · Claude · 2026-10-31

## What changed
- `module/gen-config.sh` + `PRE_BUILD="gen-config.sh"` in `module/dkms.conf`: DKMS writes the config header from the DSDT before every build. `install.sh` copies it with `dsdt-fan-config.py` and `models.sh` into `/usr/src/galaxybook-fan-<version>/` and no longer copies a generated header.
- `lib/fanpaths.sh` (names and paths, `clone` and `package` layouts, `gbfan_package_installed`) and `lib/fan-dkms.sh` (DKMS steps) - sourced by `install.sh`, `uninstall.sh`, the command and the login check.
- `lib/galaxybook-fan`: the command (`status`, `check`, `rebuild`, `test-native`), installed as `/usr/local/sbin/galaxybook-fan`, with the library files and a built `check-galaxybook-fan.sh` in `/usr/local/lib/samsung-galaxybook/fan/`.
- Login check: notifications say `sudo galaxybook-fan rebuild` / `test-native`; uninstall hints depend on the recorded `INSTALL_METHOD` (`--record-state DIR METHOD`).
- `install.sh` / `uninstall.sh` refuse while the galaxybook-fan package is installed. `--force` is remembered in `/etc/galaxybook-fan/force`.

## Why
- PLAN.md §10.3 step 1: what the packages need, without breaking `install.sh`. A package can't run `install.sh` after a BIOS update, so the command does the rebuild.

## Tested
- Real DKMS 3.0.11 builds against Ubuntu 6.8 headers with hand-made DSDTs (`GBFAN_DSDT` / `GBFAN_DMI`): 940XHA shape builds (module contains the 940XHA product and DSDT ID); fixed firmware, unrecognised `_FST`, not a Book 5 and not Samsung all fail with the reason in `make.log`; not a Book 5 with the force flag builds.
- **Found:** DKMS 3.0.11 ignores a `PRE_BUILD`'s exit status (`run_build_script`), so `gen-config.sh` fails the build with an `#error` header instead.
- The command on a simulated install: `status`, `rebuild` (builds for each kernel; after a simulated BIOS update to an unrecognised `_FST` it refuses with the reason), `check`, help, unknown command. `bash -n` and shellcheck on every script.
- Not tested here: a full `install.sh` / `uninstall.sh` run (needs systemd and the laptop), loading the module, Secure Boot signing with `PRE_BUILD`.

## For the next person
- Package layout paths in `fanpaths.sh` are a first draft (`/usr/lib/galaxybook-fan`, `/usr/bin/galaxybook-fan`); step 2 settles them. The shared session helper is still in `/usr/local/bin` for both layouts - decide in step 2.
- Next: step 2, `packaging/` shared files.
