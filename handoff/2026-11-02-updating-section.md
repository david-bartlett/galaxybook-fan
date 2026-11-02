# Give the README an Updating section

PR #45 · Claude · 2026-11-02

## What changed
- The README has a new *Updating* section after *Uninstall*: the two notification buttons, the update commands, what happens with an `install.sh` copy, and a collapsed section on how the check works.
- *New versions* moved out of `docs/compatibility-and-updates.md`, which is now `docs/compatibility.md`.
- `PLAN.md`'s file map and `docs/installing.md`'s link follow the new name.

## Why
- David wanted updating beside install and uninstall, presented like fingerprint-fix-sdcp's.

## Tested
- Wording checked against `lib/update.sh`, `lib/notify-update.sh` and the `galaxybook-fan` command.
- Links and anchors checked by script, and GitHub's rendered HTML checked on the branch.
- Not tested here: the notification itself, which needs a desktop and a new release.

## For the next person
- The update commands are listed twice in the README: in *Updating* and in the collapsed list of all commands. Keep them the same, as `--help` shows that list too.
