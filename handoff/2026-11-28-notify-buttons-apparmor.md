# Notification buttons where AppArmor confines notify-send

Claude · 2026-11-28

## What changed
- `lib/notify-update.sh`: `notify-dbus.py` (straight over D-Bus) is used on every desktop but Budgie, not just GNOME; `notify-send --action` is the fallback when PyGObject is missing. If `notify-dbus.py` can't show it (exit 2), desktops other than GNOME try `notify-send --action` before the plain notification; GNOME goes straight to the plain one, as before. The `default` action (click the notification for the release page) and its line in the text stay GNOME-only (`$gnome`).
- Comments in `lib/notify-update.sh` and `lib/notify-dbus.py`, PLAN.md (§4 map and the "New versions" paragraph), CHANGELOG.

## Why
- David, Mint 27 (Cinnamon 6.8.4, libnotify 0.8.8): no buttons. Cinnamon's `GetCapabilities` lists `actions`, but the journal has `apparmor="DENIED" operation="dbus_method_call" … member="GetCapabilities" mask="send" label="notify-send" peer_label="unconfined"` for every notification. Ubuntu 26.04 ships an AppArmor profile for `notify-send`; with the capabilities call denied, it says *Actions are not supported* and drops them. That's the same "notify-send drops the buttons" seen on Ubuntu 26.04 GNOME (October), which is why `notify-dbus.py` exists.
- `python3` isn't confined, so `notify-dbus.py`'s `Notify` call works.

## Tested
- A stand-in notification server (Gio, on a private `dbus-run-session` bus) that records `Notify` calls and presses buttons, with `XDG_CURRENT_DESKTOP` set:
  - X-Cinnamon: Update now and What's new, no `default`, first line only; What's new opens the page and the notification is shown again, then Update now opens the terminal; `notify-send` never used.
  - KDE: both buttons over D-Bus.
  - `ubuntu:GNOME`: `default` and the click line, as before.
  - With no server (D-Bus fails), X-Cinnamon falls back to `notify-send --action`. Budgie still uses `notify-send`.
- `bash -n`, `shellcheck -S warning`. Nothing on a real desktop.
- To test: Mint 27 Cinnamon (the case), and that KDE (Fedora, CachyOS) and Xfce (MX) still show both buttons and the What's new → shown again loop now that they also go through `notify-dbus.py`.

## For the next person
- fingerprint-fix-sdcp's `notify-update.sh` and `notify-open-manager.sh` got the same change (keep them in step).
