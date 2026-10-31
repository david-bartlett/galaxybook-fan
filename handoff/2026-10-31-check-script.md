# check-galaxybook-fan.sh, one model list, issue forms

PR #8 · Claude · 2026-10-31

## What changed
- `tools/check-galaxybook-fan.sh`: the read-only "will it work on my laptop?" check (PLAN.md §5.1). `tools/build-check-script.sh` makes the single-file copy (models and parser built in); the release workflow attaches it to each release, and the release page's first step and the README's top section link to it (`releases/latest/download/…`).
- `lib/models.sh`: `BOOK5_MODELS` and `CONFIRMED_MODELS` (was `TESTED_MODELS` inside `install.sh`), with `gbfan_model` and `gbfan_in_list`. `install.sh` sources it; behaviour is the same, the wording says "confirmed working".
- `.github/ISSUE_TEMPLATE/`: *Works on my model* (requires the check's report, and ticks for "not in the confirmed list" and "fan speed shows"), *Bug report*, `config.yml` linking the confirmed list.
- README: *Will it work on my laptop?* at the top with the confirmed-models table. PLAN.md §4, §5.1 (incl. how to confirm a model), §7.1, §8.1.

## Why
- David wants people with other Book 5 models to check before installing, and to report working models once, without duplicate issues.

## Tested
- Built the single file and ran it against hand-made DSDTs (the 940XHA's `_FST` shape gives the same summary as David's real laptop), with `/sys` and `/etc` paths redirected: confirmed model; unconfirmed, not installed; unconfirmed, installed and reading (report printed); fan at 0 RPM; installed but no sensor; firmware already fixed; unrecognised `_FST`; Samsung but not Book 5; not Samsung; `iasl` missing. Also run from the clone (not built). YAML of the workflow and forms parses.
- Not tested: on the real laptop, and the release workflow's new step (the next release runs it).

## For the next person
- The repository is private, so the download links and issue forms only work for other people once it's public.
- Confirming a model = `lib/models.sh` + README table + CHANGELOG, one PR (PLAN.md §5.1).
