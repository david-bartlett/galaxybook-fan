# Parser: the table and the result come from the fan device itself

PR #53 · Claude · 2026-11-03

## What changed
- `lib/dsdt-fan-config.py`: new `own_decl`, which finds a `Name (X, …)` at the fan device's top level only (`direct_children`), exactly once. `parse_table` (the RPM table) and `check_return_package` (the package `_FST` returns) use it instead of searching every line inside the device, then the whole DSDT.
- PLAN.md (§4 parser row, §8.1 variants), `docs/how-it-works.md`, CHANGELOG.

## Why
- Codex review of `07c23bc`, finding 1: `find_blocks` over the device's lines also matched a device nested inside FAN0. With FANT in LPCB (the one `_FST` really reads, as ACPI looks upwards and never into a child device) and another in FAN0.SUB0, the nested one was used. Codex checked it in `acpiexec`: 4010 RPM, against 3820 in the generated table.
- The real 940XHA declares FANT and SFST in FAN0 itself, so the simple rule fits it. Resolving names upwards through Scopes elsewhere would need a namespace model, and nothing needs that yet.

## Tested
- iasl-built DSDTs (now 20). Real shape, with and without the Switch: accepted, headers byte-identical to main's.
- Now refused (main accepted them): FANT in LPCB plus a different one in FAN0.SUB0 (main built 3850 for raw 2 from the nested table); FANT only in LPCB; SFST only in LPCB.
- Now accepted (main refused it as "defined 2 times"): FAN0's own FANT and SFST, plus copies in a nested device. The header is identical to the real one's.
- Earlier variants are unchanged. `py_compile`; `build-check-script.sh` output passes `bash -n`.
- Not here: David's real DSDT (`install.sh --check`).

## For the next person
- A Book 5 model whose FANT or SFST is in a parent scope would now be refused, where main accepted it. None is known. If one turns up, resolve the name upwards properly (nearest ancestor wins) rather than going back to searching everywhere.
