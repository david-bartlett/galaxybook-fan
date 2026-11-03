# Remove module files a failed DKMS removal leaves behind

PR #49 · Claude · 2026-11-03

## What changed
- `lib/fan-dkms.sh`: new `gbfan_remove_stray_modules`, run at the end of `gbfan_dkms_remove_all`. It deletes any `galaxybook_fan.ko*` in `/lib/modules/*/updates/dkms`, `updates` or `extra` (only regular files, only this module's name), then `depmod -a` for each kernel it touched. A file it can't delete gets a warning with the command.
- PLAN.md (`lib/fan-dkms.sh` row), CHANGELOG.

## Why
- Codex review of `c03a2fd`, finding 2: `gbfan_dkms_remove_all` ignored a failed `dkms remove` (e.g. *Could not locate dkms.conf*, the stale-version case) and then deleted `/var/lib/dkms/galaxybook-fan`, so the installed `.ko` stayed with nothing to remove it, and `uninstall.sh` said *Removed from DKMS*.
- Callers: `uninstall.sh` / the packages' pre-install step (`lib/clone-remove.sh`), package `remove`, and `install.sh`'s `install_module` before a fresh install (there it also saves DKMS from refusing an *unversioned module*). The package upgrade path (`configure`) doesn't call it and is unchanged: it already handles old files through `gbfan_dkms_install`.

## Tested
- Stand-in `dkms` failing with *Could not locate dkms.conf*, a registered 0.9.3, and fake kernels with `updates/dkms/galaxybook_fan.ko.zst`, `extra/galaxybook_fan.ko.xz` and another module's file: both of ours removed, the other module kept, `/var/lib/dkms` entry gone, `depmod -a` once per kernel; a second run does nothing.
- `bash -n`, `bash packaging/pre-script.sh | bash -n`, shellcheck (no new warnings).
- Not here: a real DKMS on any distro, a real uninstall.

## For the next person
- `/lib` is `/usr/lib` on every supported distro, so `/lib/modules` covers Arch too.
