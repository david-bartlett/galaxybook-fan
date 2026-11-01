# The new-version notification is critical on every desktop

PR #33 · Claude · 2026-11-01

## What changed
- `lib/notify-update.sh`: `-u critical` with `-t 0` for every desktop (it was GNOME only, #32). `lib/update.sh`'s plain fallback too. GNOME still gets `notify-dbus.py` and the click.
- CHANGELOG, PLAN.md §4.

## Why
- David on Mint's Cinnamon: the notification slid away. `notify-send -t 0` alone went away after a few seconds; with `-u critical` it stayed. fingerprint-fix-sdcp's notification has always been critical on every desktop and stays on KDE, Cinnamon, MATE, Xfce and GNOME, so critical everywhere is known to be fine.

## Tested
- Stub `notify-send`: Cinnamon, KDE, MATE and Xfce all get `-u critical`, none the GNOME click action. `bash -n`, shellcheck.
- David: the two notify-send calls by hand on Cinnamon.
