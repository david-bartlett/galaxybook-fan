# Make sure the module file is really installed (Ubuntu 26.04)

PR #35 · Claude · 2026-11-01

## What changed
- `lib/fan-dkms.sh`: new `gbfan_dkms_not_in_place VERSION` lists kernels DKMS calls installed but whose file isn't in place: the warning in either wording (*Diff between built and installed module* on DKMS 3.0, *Differences between built and installed modules* on 3.2), or no `galaxybook_fan.ko*` in `/lib/modules/<k>/updates/dkms` or `extra`. `gbfan_dkms_install` force-installs for those (#31 matched only the 3.0 wording).
- CHANGELOG, PLAN.md.

## Why
- David's Ubuntu 26.04 (DKMS 3.2.2), `apt install` 0.8.1 → 0.8.6: *the module didn't load*. `dkms status`: `0.8.6 … installed (Differences between built and installed modules)`; `modules.dep` listed `updates/dkms/galaxybook_fan.ko.zst` but the file didn't exist (`modprobe`: *Unknown symbol in module*, misleading); the built one in `/var/lib/dkms/…/0.8.6/…/module/` was fine and signed with his MOK. Likely: the first install refused over 0.8.1's file (*unversioned module*), #29 deleted that file and retried, and DKMS 3.2 had already recorded 0.8.6 as installed, so it skipped the copy.

## Tested
- The status-line parsing on sample lines (both wordings → force; plain *installed* → file check; *built* → skipped). `bash -n`, shellcheck (no new notes).
- Not run here: `gbfan_dkms_install` against a stand-in `dkms` (this session's safety check refuses scripts that source a library with `rm`).
- David on Ubuntu 26.04, from the broken state: `apt install --reinstall` of this branch's deb → `dkms status` `galaxybook-fan/0.8.6, 7.0.0-42-generic, x86_64: installed`, no warning.
