# Session helper: start the graphical session for each login

Claude · 2026-11-28

## What changed
- `packaging/files/session-start.sh.in` (clone and package installs): passes the session's environment to the user manager first, at every login (it used to exit before that when `graphical-session.target` was active). On desktops other than GNOME and KDE Plasma, when the target became active before this session began (`systemctl --user show graphical-session.target -p ActiveEnterTimestampMonotonic` < `loginctl show-session $XDG_SESSION_ID -p TimestampMonotonic`), it stops the target and starts it again, so the user services start for this session. A lock (`$XDG_RUNTIME_DIR/samsung-galaxybook-session.lock`) serialises the copies.
- The same text in fnkeys-fix-book5 (install.sh), fingerprint-fix-sdcp and galaxybook-intel-camera.

## Why
- David, Mint 27: Cinnamon Wayland, then MATE, then Cinnamon X11. `loginctl` showed the MATE session still `State=closing` 25 minutes later, and the user journal had no `graphical-session.target` start at the Cinnamon X11 login: the helper saw it active (from MATE) and exited, so nothing ran for Cinnamon (fnkeys' XKB setup there; here the login checks and update check stay with the old session's environment).
- GNOME and KDE Plasma run their own session services under `graphical-session.target`, so the helper never stops it there.

## Tested
- Mocked only: the rendered helper (clone and package) against stand-ins for `systemctl`, `loginctl` and `dbus-update-activation-environment`: a normal login starts it; left from before this login → stop, start; started during this login (another copy ran first) → left; GNOME, KDE and Budgie → never stopped; no session time → left, as before. The old helper fails the stale cases. `shellcheck -S warning`.
- Not tested: a real desktop switch.

## For the next person
- Keep the helper the same in all four repos; whichever fix installs last writes the shared `/usr/local/bin` copy.
