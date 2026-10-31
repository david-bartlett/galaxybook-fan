# "Update now" and "What's new" buttons

PR #26 · Claude · 2026-10-31

## What changed
- `lib/notify-update.sh`: the notification with `--action` buttons when `notify-send --help` lists `--action`: **Update now** (terminal: `xdg-terminal-exec`, else the desktop's usual from `XDG_CURRENT_DESKTOP`, else the first installed of a list like fingerprint-fix-sdcp's `terminal.py`) running `update-in-terminal.sh`; **What's new** (`xdg-open` the release). Same text as before either way; dismissed: nothing.
- `lib/update-in-terminal.sh`: `sudo galaxybook-fan update` with a title, then closes after 10 s on success or waits for Enter.
- `lib/update.sh`: the notification's wording (`gbfan_update_title` / `gbfan_update_text`) and showing it (`gbfan_update_notify`: `notify-update.sh` via `systemd-run --user --collect`, as it waits for a click; else plain `notify-send`), plus `gbfan_update_mark_told`. `notify-update.sh` is looked for beside the running script (`GBFAN_HERE`), so a clone's copy is used when run from one.
- `lib/update-check.sh` uses those; **`galaxybook-fan updates check`** (as the user; refuses root, whose notification wouldn't reach the desktop) looks now, prints the result and shows the notification if there's a newer release.
- Installed by `install-files.sh` and `install.sh` (755, library folder). README, PLAN.md §4 and *Login check*, CHANGELOG.

- Each button is offered only where it can work: *Update now* where a terminal is found, *What's new* where `xdg-open` (or `gio open`) exists. `xdg-utils` is recommended by the deb and rpm, an optdepend on Arch (`notify-send` itself was already a dependency of all three: `libnotify-bin` / `libnotify`).

## Why
- David: like fingerprint-fix-sdcp's notification, but the command stays in the text for GNOME, which shows no buttons.

## Tested
- Here, `galaxybook-fan updates check` as a user against a fake GitHub (0.6.2 installed, 0.7.0 out): prints the new version and how to update, and `systemd-run` → `notify-update.sh` with both buttons → *Update now* → Konsole with `update-in-terminal.sh`; marks it told; refuses root; "up to date" when it is.
- Buttons offered: no `xdg-open`/`gio` → only *Update now*; with it → both; no terminal → only *What's new*.
- With stubs: `notify-send` returning `update` → Konsole started with `update-in-terminal.sh`; `whatsnew` → `xdg-open` the URL; dismissed → nothing; no `--action` support → plain notification. `update-in-terminal.sh` with `sudo` stubbed. shellcheck, `bash -n`.
- Not tested: a real desktop (buttons, terminal, systemd-run).

## For the next person
- The notification is drawn by the installed version: 0.7.1's notification still comes from 0.7.0 (no buttons). Buttons first show when the release after this one is announced to a laptop that has it.
