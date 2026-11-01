# Short new-version notification when it has buttons

PR #<n> · Claude · 2026-11-01

## What changed
- `lib/notify-update.sh`: when it shows buttons, the text is MESSAGE's first line (*You have X.Y.Z.*), plus the GNOME click line; the full MESSAGE (command and link) is kept in `$full` for when there are no buttons, and for the plain fallback if `notify-dbus.py` fails.
- README (update paragraph), PLAN.md §4, CHANGELOG.

## Why
- David's screenshot on Ubuntu 26.04 (0.8.6 → 0.8.7): the command and link repeated the buttons, and GNOME ran the lines together. He agreed to the mock-up (short text with buttons, full text without).

## Tested
- Stubs: GNOME → helper with *You have 0.8.6.* and the click line; KDE → `notify-send --action` with *You have 0.8.6.*; `notify-send` without `--action` and the helper failing → the full text. shellcheck, `bash -n`.

## For the next person
- `gbfan_update_text` (lib/update.sh) still builds the full text: the first line must stay *You have X.Y.Z.* for this to read right.
