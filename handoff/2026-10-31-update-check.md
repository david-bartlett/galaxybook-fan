# New-version notification and `galaxybook-fan update`

PR #23 · Claude · 2026-10-31

## What changed
- `lib/update.sh`: installed version (library folder's `VERSION`, which `install.sh` now writes; else DKMS), latest version from the `releases/latest` redirect (no API), version compare (`sort -V`), update hint per install method. `GBFAN_REPO_URL` for tests.
- Login check (`user-check.sh.in`): `update_check` first, at most once a day, once per version, quiet on any failure, off when `/etc/galaxybook-fan/no-update-check` exists. No notification buttons (GNOME). Timer gains `OnCalendar=daily`.
- Command: `update` (format from rpm/dpkg/pacman; file picked from the release's `SHA256SUMS` by name pattern, checked with `sha256sum -c`, installed with dnf/apt/pacman in a world-readable temp folder so apt's `_apt` user can read it; install.sh copies get the hint) and `updates on|off|status`; `status` shows the setting.
- `curl` added to all three packages' dependencies; `update.sh` shipped by `install-files.sh` and `install.sh`; package removal and `uninstall.sh` remove the off flag (kept when a package replaces an install.sh copy).
- README *New versions*; PLAN.md (§4, login check, §7.1 file names are an interface, §9, §11 tag ruleset); packaging README; CHANGELOG.

## Why
- David wants releases on GitHub only (no COPR / PPA / AUR upkeep) and the fix to tell users about new versions, like fingerprint-fix-sdcp.
- Trust: SHA256SUMS sits on the same release, so it catches a broken download, not a compromised account. Mitigations agreed: passkeys / 2FA, watching the repository, a `v*` tag ruleset (restrict creations to the admin).

## Tested
- Here (Ubuntu 24.04, fake GitHub on localhost serving the redirect, `SHA256SUMS` and a real 0.7.0 deb built from this branch): login check as a user with a `notify-send` stub: notified once; nothing again the same day, nor a "day later" for the same version; nothing and no stamp offline; nothing with updates off. `galaxybook-fan update`: tampered checksum refused, nothing installed; real update 0.6.2 → 0.7.0 through apt; "up to date" after; not root, unreachable, nothing installed, install.sh copy hint. rpm and Arch packages built: `update.sh` included, `curl` required. shellcheck, `bash -n`.
- Not tested: the real GitHub (private: 404 until public), a real desktop notification, dnf and pacman installing through `update`.

## For the next person
- Can't work end to end until the repository is public. Then: release a new version and check the notification on one distro, and `sudo galaxybook-fan update` on each format.
