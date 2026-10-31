# GNOME: the new-version notification stays, with working buttons

PR #32 · Claude · 2026-10-31

## What changed
- `lib/notify-update.sh`: on GNOME (`XDG_CURRENT_DESKTOP` has GNOME, not Budgie: `$gnome`) the notification gets `-u critical`; the GNOME click action (#27) uses the same test. Other desktops unchanged (`-t 0` only).
- `lib/notify-dbus.py` (new, 755, installed beside `notify-update.sh` by `install-files.sh` and `install.sh`): `URGENCY APP ICON TITLE BODY [KEY LABEL]...`, sends `Notify` over D-Bus with Gio, waits for `ActionInvoked` / `NotificationClosed` for its id, prints the key; exit 2 if it can't (no PyGObject or bus). `notify-update.sh` uses it on GNOME (else `notify-send --action`), falls back to a plain `notify-send` on exit 2. Buttons kept as `KEY=LABEL` in `acts`, shared by both ways.
- Packages recommend PyGObject: deb `python3-gi`, rpm `python3-gobject`, Arch optdepend `python-gobject`.
- CHANGELOG, PLAN.md §4.

## Why
- David on Ubuntu 26.04: the notification slid into GNOME's list after a few seconds, so there was no time to click it. GNOME ignores `-t 0`; only critical notifications stay. He tried `notify-send -u critical` with the actions: it stayed, and the click and buttons (on hover) came through. fingerprint-fix-sdcp already sends critical.

## Tested
- Stub `notify-send`: `-u critical` and the default action only for ubuntu:GNOME, not KDE, budgie:GNOME or X-Cinnamon. shellcheck, `bash -n`.
- David on Ubuntu 26.04: `notify-send -u critical` stayed on screen but printed *Actions are not supported by this notifications server. Displaying non-interactively.* (exit 1), so the script's `choice` was always empty; yet `GetCapabilities` lists `actions`, a `gdbus call … Notify` showed the button, and a Python/Gio script that sends `Notify` and waits got `ActionInvoked (22, 'update')` and `(23, 'whatsnew')`.
- Stubs (`notify-send`, `python3`, `xdg-open`): GNOME → `notify-dbus.py` with critical, all three actions and the click line, What's new opens and re-shows; helper exit 2 → plain critical `notify-send` without the click line; no PyGObject → `notify-send --action`; KDE unchanged. `py_compile`, shellcheck, `bash -n`.

## For the next person
- Why notify-send refuses on that GNOME wasn't found (libnotify 0.8.8). If a later libnotify fixes it, notify-dbus.py can stay: it works either way.
- A notification is drawn by the installed version: the release after this is the first whose GNOME notification stays.
