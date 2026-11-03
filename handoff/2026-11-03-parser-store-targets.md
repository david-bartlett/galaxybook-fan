# Parser: check where each _FST store goes

PR #50 · Claude · 2026-11-03

## What changed
- `lib/dsdt-fan-config.py` `parse_fst`:
  - Step 8's shape is now `…E{DLO?P*Q}T}`. Nothing may follow the RPM store in the Else (it was `[PQ]*Q[PQ]*`).
  - New step 9: every `P`/`Q` store must go into the package named in `Return (…)`, which must not be the lookup table. The RPM (`Q`) must go into slot 2 (ACPI's Revision, Control, Speed), and the off branch (`If`) must store the level into that same slot.
- PLAN.md (§4 parser row, §8.1 test variants and the real `_FST`), `docs/how-it-works.md` (what's refused), CHANGELOG.

## Why
- Codex review of `c03a2fd`, finding 1: the order check took any `NAME [const] = Local` as a store. So `FANT [Zero] = Local0` (changing the table) or `SFST [0x02] = Local0` after the RPM store (overwriting it) were accepted, with the original RPM table.
- David's real 940XHA `_FST` (pasted 2026-11-03): `Local0 = ^^H_EC.FANS`; Switch, five Cases (1→1, 2→2, 3→3, 4→3, 5→4); `SFST [One] = Local0`; `If ((Local0 == Zero)) { SFST [0x02] = Local0 }`; `Else { Local0--; Local1 = FANT [Local0]; Local1 += 0x0A; SFST [0x02] = Local1 }`; `Return (SFST)`. The new rules are written to that.

## Tested
- 11 test DSDTs built with iasl from that shape (compiled, then disassembled). The real shape, with and without the Switch, is accepted, with headers byte-identical to main's (and to `module/galaxybook_fan_config.h`'s table). `DerefOf` is still `fixed`.
- Main accepted, the branch refuses: Codex's two (RPM overwritten after the store, `FANT [Zero] = Local0`), the level stored after the RPM, the RPM stored into another package, the off branch setting only `SFST [One]`, the RPM in `SFST [One]`, and `Return (FANT)`.
- Still accepted (harmless to the RPM): a level store in the Else before the RPM store.
- `py_compile`, and `tools/build-check-script.sh` output passes `bash -n`.
- Not here: the real DSDT (David's `install.sh --check`).

## For the next person
- `SFST` is declared after `_FST` in the real DSDT. The parser doesn't need the package's declaration, only its name from `Return`.
- Writes to `FANT` from other methods elsewhere in the DSDT aren't looked for. Only `_FST` is checked.
