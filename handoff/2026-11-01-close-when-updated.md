# The new-version notification closes once the new version is installed

PR #41 · Claude · 2026-11-01

## What changed
- `lib/notify-update.sh`: the announced version (from the URL's `/tag/vX.Y.Z`) and the installed `VERSION` file beside it (or the clone's); `updated()` compares them with `sort -V`. `wait_notify_send` runs `notify-send --print-id …` in the background, notices a click within 0.5 s, and every 2 s, once `updated`, calls `gdbus … CloseNotification ID` (once); it prints the button (line 2 of notify-send's output). Without `--print-id` it's plain `notify-send` as before.
- `lib/notify-dbus.py`: `NOTIFY_WATCH_FILE` / `NOTIFY_WATCH_VERSION`: every 2 s it reads the file and, once it's that version or newer, closes its own notification and prints nothing.
- CHANGELOG, PLAN.md §4.

## Why
- David: after updating another way the notification stayed on screen. There's no way to list other programs' notifications, so the notification's own process watches for the update.

## Tested
- Stand-ins for `notify-send` (waits, `--print-id`), `gdbus` and `xdg-open`, KDE: VERSION changed after 3 s → `CloseNotification 42`, script ended about 2 s later; a What's new click still opens the page and re-shows. shellcheck, `bash -n`, `py_compile`.
- Not tested here: the D-Bus helper's watch (needs GNOME), and whether KDE / Cinnamon / MATE / Xfce allow `CloseNotification` from another D-Bus connection.

## For the next person
- fingerprint-fix-sdcp has the same change (its own PR); keep `notify-dbus.py` in step.
