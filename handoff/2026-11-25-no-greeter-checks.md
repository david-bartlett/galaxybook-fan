# Login checks: not on the login screen, and never a password prompt

PR #62 · Claude · 2026-11-25

## What changed
- `packaging/files/user-check.{timer,service}.in` and `update-check.{timer,service}.in`: `ConditionUser=!@system`.
- `packaging/files/user-check.sh.in`: `systemctl --no-ask-password start` for the monitor (stderr quietened). A user polkit doesn't allow simply gets no root check, rather than a prompt.
- PLAN.md (§5 *Login check*), CHANGELOG.

## Why
- David, CachyOS, kernels 7.3.6 and 7.4.0-rc4: after a kernel upgrade and reboot, a password prompt for the galaxybook-fan helper appeared **on the login screen**, before logging in.
- The packages run `systemctl --global enable` for the user timers (`lib/package-scripts.sh`), so they're enabled for every user, including the greeter's (GDM's `gdm`). The greeter session reaches `graphical-session.target`, so the login check ran as `gdm`. On a new kernel it starts the root monitor; `gdm` isn't in `wheel`, so the polkit rule doesn't apply and polkit asked interactively, on the greeter.
- The update check would also have run as `gdm` (network checks and a possible notification on the greeter).
- `install.sh` enables them only for the installing user, so clone installs weren't affected.

## Tested
- `systemd-analyze condition 'ConditionUser=!@system'`: fails as root and as a `useradd -r` system account (uid 996, like gdm); succeeds as a normal user (uid 1500). (`nobody`, 65534, also succeeds, but no desktop session runs as `nobody`.)
- All four rendered units parse with `systemd-analyze verify`. The rendered `user-check.sh` passes `bash -n` and `dash -n`.
- Not here: a real greeter session, or polkit itself.

## For the next person
- fingerprint-fix-sdcp's packages enable their user timers the same way, so check whether it has the same exposure.
