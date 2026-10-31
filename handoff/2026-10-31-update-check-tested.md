# New-version check: tested on Fedora, PLAN.md details

PR #24 · Claude · 2026-10-31

## What changed
- PLAN.md §3: where the new-version check lives (script, user units, off switch, per-user state, `VERSION`), and that a newly installed user timer only starts at the next login. §9: it's the update-check timer that notifies, not the login check.
- Docs only.

## Tested (David, Fedora 45, the #23 branch as rpm 0.6.2-2)
- `galaxybook-fan status` shows the notifications are on; `updates off` / `on` switch them and `status` follows.
- `sudo galaxybook-fan update`: "Couldn't find the newest release on GitHub (... isn't public yet)", as expected while private.
- `galaxybook-fan-update-check.timer` wasn't listed until David logged out and in (the package enables it for every user; a running session doesn't pick it up). After that it ran 30 s after login (20 s after the login check), retried while GitHub answered 404 (19:20:18 → 19:22:03, 8 tries), finished with status 0 and no notification, next run on the hour.

## For the next person
- Released as 0.7.0 (features: x.Y.0). Install 0.7.0 by hand once on each test distro, then log out and in, so each has the check.
- The end-to-end test (a real notification, then `sudo galaxybook-fan update` through dnf, apt and pacman) waits for the first release after the repository goes public (0.7.1).
- Possible improvement: start the timer in sessions that are already running when a package is installed (as `install.sh` does with `systemctl --user` for the user it runs for).
