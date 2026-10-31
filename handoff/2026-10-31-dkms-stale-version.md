# Old DKMS version left after a deb upgrade

PR #<n> · Claude · 2026-10-31

## What changed
- `lib/fan-dkms.sh`: `gbfan_dkms_forget VERSION` deletes `/var/lib/dkms/galaxybook-fan/VERSION` and the `kernel-*` links into it, when `dkms remove` couldn't. `gbfan_dkms_version` now returns the installed `VERSION` when DKMS has it, else the newest registered (`sort -V`), not the first directory.
- `lib/package-scripts.sh` `configure`: after `dkms remove` of each other version, `gbfan_dkms_forget` it.
- PLAN.md §7 (packages), CHANGELOG.

## Why
- David upgraded 0.7.0 → 0.8.1 on Mint 22.3 (deb, from the file manager): `galaxybook-fan status` said "Version 0.7.0, built for: no kernel yet"; `dkms status` said `Could not locate dkms.conf … 0.7.0/source/dkms.conf`. dpkg removes the old package's files (its `/usr/src` copy) before the new `postinst`, and DKMS 3.0 can't remove a version without its source. The 0.8.1 module was built and loaded all along.

## Tested
- Here on a fake `/var/lib/dkms` tree (0.7.0 and 0.8.1, a kernel link each): the version picked is 0.8.1 with and without `VERSION`; forgetting 0.7.0 leaves 0.8.1 and its link. `bash -n`, shellcheck (no new warnings).
- Not tested here: a real apt upgrade (David's Mint is in exactly the broken state).

## For the next person
- rpm runs the new `%post` before removing the old files, so Fedora doesn't hit this; pacman removes first but its DKMS hook handles it.
