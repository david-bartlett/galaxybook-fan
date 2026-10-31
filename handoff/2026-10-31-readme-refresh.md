# README up to date with the packages

PR #21 · Claude · 2026-10-31

## What changed
- README: *Install* (the package table) moved up, straight after *Will it work on my laptop?*; `install.sh` is its own section further down, linked from there.
- Wording that described only `install.sh` now covers the packages: DKMS's `gen-config.sh` makes the config before every build; the unbind service and login check are "the fix"; a failed DSDT check means the module isn't built (only `install.sh` saves `/tmp/galaxybook-fan-dsdt.dsl`); `GALAXYBOOK_FAN_FORCE=1` alongside `--force`; Initramfs and Secure Boot cover the packages (they never prompt; they print the `mokutil` command), both now `##` sections.
- *Tested on*: a *Package* column, today's package tests in the intro, CachyOS's LTS kernel, Mint's uninstall now tested on 22.3. The "tested again before the first packaged release" promise is gone; `--test-native` and the login check's notifications are still from 0.2.
- *Files*: collapsed; adds `lib/package-scripts.sh`, `lib/clone-remove.sh`, `.github/workflows/release.yml`; the config header line no longer says the installer copies it to `/usr/src`.
- PLAN.md §2: distros line (packages; Mint 22.3, MX 25.3).

## For the next person
- `--test-native` and a real login-check notification (e.g. after a kernel update) haven't been re-tested since 0.2.
- `.github/release-install.md` was checked and needs no change; the 0.6.1 release page is as published.
