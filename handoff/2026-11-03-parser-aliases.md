# Parser: refuse an Alias for the returned package or the table

PR #52 · Claude · 2026-11-03

## What changed
- `lib/dsdt-fan-config.py`: `parse_fst` returns the package's name (`ret`). The new `check_return_package` runs after `parse_table` in both the header path and `--status`. It needs exactly one `Name (ret, Package (n))` with n ≥ 3 (the fan device's own, else the whole DSDT), and refuses any `Alias (a, b)` anywhere whose a or b ends in the returned package's name or the table's.
- PLAN.md (§4 parser row, §8.1 variants), `docs/how-it-works.md`, CHANGELOG.

## Why
- Codex review of `07c23bc` (same code as `eb31ed6`): step 9 compares names only. With `Alias (FANT, SFST)` in place of SFST's declaration, every store into SFST changes FANT. Codex ran the variant in `acpiexec`: raw 2 gave 12 RPM, while the generated table said 3820.

## Tested
- iasl-built DSDTs (16 now, from the real 940XHA `_FST`). The real shape, with and without the Switch, is accepted, with headers byte-identical to main's.
- Main accepted these, and the branch refuses them: `Alias (FANT, SFST)` (with and without DerefOf), an `Alias` of FANT in another scope (iasl writes it as `PC00.LPCB.FAN0.FANT`), SFST as a Buffer, SFST as a 2-entry Package. Earlier variants are unchanged.
- `py_compile`; `build-check-script.sh` output passes `bash -n`.
- Not here: David's real DSDT (`install.sh --check`), in case it has an unrelated `Alias` with one of these names.

## For the next person
- An Alias of FANT that only reads it would be harmless, but it's refused anyway (strict, as §9 asks). If a real BIOS has one, look at it before loosening this.
- Runtime tricks from other methods (`CopyObject`, `RefOf` stores) aren't looked for. Only `_FST` and declarations are checked.
- Codex's container had no kernel headers, although the install script lists `linux-headers-generic`. The environment may have been built before the script was added.
