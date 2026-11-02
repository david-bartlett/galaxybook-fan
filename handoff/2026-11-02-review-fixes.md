# Fixes from a code review

PR #42 · Claude · 2026-11-02

## What changed
- `lib/samsung-galaxybook-fan-check.sh`: `record_state` writes with `printf`, leaving out an `INSTALL_DIR` with a newline; new `read_state` reads the four known keys line by line. `monitor` uses it instead of `source "$STATE_FILE"`.
- `lib/dsdt-fan-config.py`: `parse_fst` step 8, one letter per statement (`M { R S C A I E D L O P Q T }`), and the whole method must match `M{R(S{(C{A})+})?I{P+}E{DLO?[PQ]*Q[PQ]*}T}`. P stores the level (`var`), Q the RPM (`rvar`).
- `lib/package-scripts.sh`: `configure` adds `gbfan_dkms_kernels "$old"` to `held` before `dkms remove --all`.
- `install.sh`: `install_module` notes the kernels of every registered version before removing them, and installs the new version for each (headers permitting) after the running kernel's.
- PLAN.md (state file, upgrades, testing), README (what's refused), CHANGELOG.

## Why
- A Codex review of `02783e9` found the first three: the state file sourced as root (a folder with spaces broke it; `$(…)` or `;` ran), the whitelist checking statements but not their order, and a successful `dkms remove --all` losing every kernel but the running one. `install.sh` had the same gap as the package.

## Tested
- State file with spaces, `;` and `$(…)`, a newline, and `=` in the folder name: the new reader gets the text, nothing runs; the old `source` ran the commands and lost the spaced name. `sed` readers unchanged.
- Parser with test DSDTs built with iasl: the 940XHA shape (with and without the Switch) passes, headers byte-identical to main's; `DerefOf` still "fixed"; six changed versions main accepted (`Local0 = One` after the read, two `Local0--`, two lookups, offset after the store, an assignment in the If, the offset nested in an If) are refused. `build-check-script.sh` output passes `bash -n`.
- `configure` with a stand-in DKMS (0.8.0 on two kernels, upgrade to 0.9.0): main left only the running kernel; the branch also installs the second.
- `bash -n`, shellcheck (no new warnings), `py_compile`.
- Not here: the real DSDT (David's `install.sh --check`), a real package upgrade (needs a new version number), `install.sh` over an earlier install with two kernels.

## For the next person
- The parser's order check is strict on purpose. A real BIOS that's refused needs its `_FST` looked at, then the shape widened, never loosened by guesswork.
