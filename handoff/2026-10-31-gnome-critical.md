# GNOME: keep the new-version notification on screen

PR #<n> · Claude · 2026-10-31

## What changed
- `lib/notify-update.sh`: on GNOME (`XDG_CURRENT_DESKTOP` has GNOME, not Budgie: `$gnome`) the notification gets `-u critical`; the GNOME click action (#27) uses the same test. Other desktops unchanged (`-t 0` only).
- CHANGELOG, PLAN.md §4.

## Why
- David on Ubuntu 26.04: the notification slid into GNOME's list after a few seconds, so there was no time to click it. GNOME ignores `-t 0`; only critical notifications stay. He tried `notify-send -u critical` with the actions: it stayed, and the click and buttons (on hover) came through. fingerprint-fix-sdcp already sends critical.

## Tested
- Stub `notify-send`: `-u critical` and the default action only for ubuntu:GNOME, not KDE, budgie:GNOME or X-Cinnamon. shellcheck, `bash -n`.
- David: the same notify-send call by hand on Ubuntu 26.04.

## For the next person
- A notification is drawn by the installed version: the release after this is the first whose GNOME notification stays.
