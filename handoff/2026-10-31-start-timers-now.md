# Update timer starts at once; public

PR #25 · Claude · 2026-10-31

## What changed
- `lib/package-scripts.sh`: `user_systemctl_all` runs `systemctl --user` for every logged-in user with a session bus (`/run/user/<uid>/bus`, uid ≥ 1000, via `runuser`). `configure` reloads and starts `galaxybook-fan-update-check.timer` in those sessions; `remove` stops both user timers there. The login-check timer still starts at the next login (it's for kernel/BIOS changes, which come with a reboot).
- `lib/update-check.sh`: icon `system-software-update` (standard; `software-update-available` showed a blank page on Fedora KDE), and the text on separate lines ("You have X." / "To update, run: …" / blank / "What's new: <link>"): on KDE the command and link wrapped into what looked like one command.
- PLAN.md: public since 31 October 2026 (0.7.0); §3 timer note; §11 the `main` branch ruleset is what's left.

## Tested
- David, Fedora 45 KDE, after going public: the 0.6.2-2 test build showed "galaxybook-fan 0.7.0 is available ... sudo galaxybook-fan update" with the release link (blank icon, fixed here).
- Here: `bash -n`, shellcheck. `user_systemctl_all` can't run here (no systemd); 0.7.1's upgrade through `galaxybook-fan update` on each distro exercises it.

## For the next person
- Release 0.7.1 after merging; every test distro (on 0.7.0) should notify within the hour, then `sudo galaxybook-fan update` on each tests dnf, apt and pacman.
