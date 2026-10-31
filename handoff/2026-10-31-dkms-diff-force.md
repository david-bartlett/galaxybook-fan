# Install over an old module file DKMS keeps (Diff between built and installed)

PR #<n> · Claude · 2026-10-31

## What changed
- `lib/fan-dkms.sh` `gbfan_dkms_install`: after installing, every kernel whose `dkms status` line says *Diff between built and installed module* gets `dkms install --force`. Used by `package-scripts.sh configure` and `galaxybook-fan rebuild`.
- CHANGELOG, PLAN.md.

## Why
- David's Mint 22.3 after `sudo galaxybook-fan update` 0.8.1 → 0.8.3: `galaxybook-fan/0.8.3 … installed (WARNING! Diff between built and installed module!)`. The installed `galaxybook_fan.ko.zst` was from 19:54 (an earlier install), the built one from 22:42; same size, different sha256. After #29 forgets the old version, its module file stays; DKMS 3.0 sees a module it takes for the same one (no `MODULE_VERSION`, same source) and doesn't replace it, but records the new version as installed. Debian 13's DKMS refuses instead (#29's "unversioned module" case).
- Harmless while the module source doesn't change between releases, wrong the day it does.

## Tested
- Stand-in `dkms` acting like Mint's: first install keeps the file and status shows the warning → `--force` once → status clean; already clean → no `--force`. `bash -n`, shellcheck (no new notes).
- Not tested here: real DKMS 3.0 (David's Mint is in this state now).

## For the next person
- Adding `MODULE_VERSION` to the module would let DKMS tell versions apart by itself; not done, as it changes the module.
