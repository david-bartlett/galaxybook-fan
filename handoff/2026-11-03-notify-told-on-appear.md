# Count a release as announced the moment its notification appears

PR #56 · Claude · 2026-11-03

## What changed
- `lib/notify-update.sh`: no early write and no `untold`. `told()` writes `notified-version` when a notification has appeared:
  - `wait_notify_send` reads notify-send's `--print-id` output every 0.5 s (it was every 2 s), and again after it exits
  - without `--print-id`, after notify-send returns 0
  - after any plain notify-send that worked
- `lib/notify-dbus.py`: writes `NOTIFY_SHOWN_TEXT` to `NOTIFY_SHOWN_FILE` once `Notify` has returned an ID. `notify-update.sh` passes its told file and version.
- `lib/update.sh`: `gbfan_update_notify` returns 0 without starting anything while its unit (`galaxybook-fan-notify-<version>`) is still active, so an hourly check can't start a second notifier while the first is still waiting. Before, `systemd-run` would fail on the name and fall back to a plain duplicate.
- PLAN.md (§5 login check), CHANGELOG.
- This replaces #55's "write at start, take back on failure". That note's description of `untold` no longer holds.

## Why
- Codex review of `d00b3a9` (0.9.7; the first one on the current code, after it fetched): with #55, a notifier killed before anything appeared (logout) never ran `untold`, so the release stayed counted and was never announced.

## Tested
- Fakes for `systemd-run`, `systemctl --user is-active` and `notify-send` (with a delay before the ID and time on screen):
  - shown at once: told
  - killed before it appeared: not told
  - killed while on screen: told
  - notify-send failing: not told, 2 calls
  - unit already active: nothing started, not told
- `bash -n`, `py_compile`, shellcheck: no new warnings.
- Not here: `notify-dbus.py`'s write against a real session bus (only compiled), and a real desktop.

## For the next person
- The installed version's scripts draw the notification, so this takes effect from the release after the one that ships it.
