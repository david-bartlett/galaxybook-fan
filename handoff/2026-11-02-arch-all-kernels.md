# install.sh: every kernel on Arch-based distros

PR #<number> · Claude · 2026-11-02

## What changed
- `install.sh` `install_module`: on `PKG_MGR=pacman`, adds every `/lib/modules/<k>/build` whose `/lib/modules/<k>/vmlinuz` exists to `others`, the list #42 added for an earlier install's kernels. The loop after the running kernel's install puts the module on each one.
- README (install.sh section), PLAN.md §upgrades, CHANGELOG.

## Why
- David: on CachyOS a clone install only built for the running kernel, so the LTS kernel in Limine had no fan reading until its next update. The packages already cover it (Arch's DKMS pacman hook builds for every kernel with headers when `/usr/src/*/dkms.conf` is installed). Same rule as fnkeys-fix-book5 (samsung-galaxybook-fixes #15): Arch only, as Fedora and Debian keep old fallback kernels.
- Manjaro checked on a live USB: kernel `7.1.8-1-MANJARO`, owned by `linux71` (headers `linux71-headers`, which install.sh's pacman-owner lookup already picks).

## Tested
- The kernel choice against a stand-in `/lib/modules`: running + LTS (both with build and vmlinuz) picked; leftover headers with no vmlinuz and a kernel without headers skipped; nothing on `dnf`.
- `bash -n`, shellcheck (no new warnings).
- Not here: a real clone install on CachyOS.

## For the next person
- The `vmlinuz` check isn't in fnkeys-fix-book5's loop; headers left from a removed kernel would get a module there.
