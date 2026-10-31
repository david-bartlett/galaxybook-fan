# "Update now" and "What's new" buttons

PR #26 · Claude · 2026-10-31

## What changed
- `lib/notify-update.sh`: the notification with `--action` buttons when `notify-send --help` lists `--action`: **Update now** (terminal: `xdg-terminal-exec`, else the desktop's usual from `XDG_CURRENT_DESKTOP`, else the first installed of a list like fingerprint-fix-sdcp's `terminal.py`) running `update-in-terminal.sh`; **What's new** (`xdg-open` the release). Same text as before either way; dismissed: nothing.
- `lib/update-in-terminal.sh`: `sudo galaxybook-fan update` with a title, then closes after 10 s on success or waits for Enter.
- `lib/update-check.sh`: starts `notify-update.sh` with `systemd-run --user --collect --unit=galaxybook-fan-notify-<version>` (it waits for a click), else the plain `notify-send` as before; `notified-version` written when either worked.
- Installed by `install-files.sh` and `install.sh` (755, library folder). README, PLAN.md §4 and *Login check*, CHANGELOG.

## Why
- David: like fingerprint-fix-sdcp's notification, but the command stays in the text for GNOME, which shows no buttons.

## Tested
- Here with stubs: `notify-send` returning `update` → Konsole started with `update-in-terminal.sh`; `whatsnew` → `xdg-open` the URL; dismissed → nothing; no `--action` support → plain notification. `update-in-terminal.sh` with `sudo` stubbed. shellcheck, `bash -n`.
- Not tested: a real desktop (buttons, terminal, systemd-run).

## For the next person
- The notification is drawn by the installed version: 0.7.1's notification still comes from 0.7.0 (no buttons). Buttons first show when the release after this one is announced to a laptop that has it.
