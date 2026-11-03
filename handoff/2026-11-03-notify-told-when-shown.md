# Count a release as announced only once its notification is shown

PR #55 · Claude · 2026-11-03

## What changed
- `lib/update.sh`: `gbfan_update_notify` passes `GBFAN_TOLD_FILE` (from the new `gbfan_update_told_file`) and `GBFAN_TOLD_VERSION` to `notify-update.sh` through `systemd-run --setenv`. Without `systemd-run`, it marks the version itself after a plain `notify-send` that worked, and returns 1 if that failed.
- `lib/notify-update.sh`: writes `notified-version` as it starts (so an hourly check doesn't announce it again while it's on screen), and `untold` removes it if the first notification can't be shown at all: D-Bus exit 2 followed by a failing plain `notify-send`, `notify-send` with buttons giving no ID and the plain retry failing too, or the plain-only path failing. `wait_notify_send` now returns non-zero when no ID was printed.
- `lib/update-check.sh` and `galaxybook-fan updates check` no longer mark it themselves.
- PLAN.md (§4 `update.sh` row, §5 login check), CHANGELOG.

## Why
- Codex review of `07c23bc`, finding 4: `systemd-run` returns 0 once the job starts, so `update-check.sh` wrote `notified-version` even when `notify-update.sh` then couldn't show anything, and that release was never announced.

## Tested
- Fakes for `systemd-run` (runs the notifier with its `--setenv`s) and `notify-send` (`--print-id` and `--action`, working or failing), on KDE:
  - systemd-run ok, notify-send fails: not marked (main marked it)
  - systemd-run ok, works: marked
  - no systemd-run, works: marked
  - no systemd-run, fails: not marked, returns 1
- GNOME with a stand-in `python3`: D-Bus exit 2 then notify-send fails: not marked; D-Bus exit 2 then notify-send works: marked; D-Bus shown: marked.
- `bash -n`; shellcheck: no new warnings.
- Not here: a real desktop.

## For the next person
- The installed version's scripts draw the notification, so this only helps from the release after the one that ships it.
- fingerprint-fix-sdcp has the same notifier design (`notify-update.sh`, `notify-dbus.py`) and may have the same gap.
