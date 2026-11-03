# Fewer duplicate new-version notifications

PR #57 · Claude · 2026-11-03

## What changed
- `told` (`lib/notify-update.sh`), `notify-dbus.py`'s `NOTIFY_SHOWN_FILE` write and `gbfan_update_mark_told` (`lib/update.sh`) never replace a newer version already in `notified-version` (`sort -V` / `_version`).
- `gbfan_update_notify`: after a refused `systemd-run`, checks `is-active` again before the plain fallback.
- PLAN.md (§5 login check), CHANGELOG.

## Why
- Codex review of `8bb26e3` (0.9.8), on #56. All three findings were duplicates; none was a missed release:
  1. An older release's notification redrawn by *What's new* overwrote a newer version's record. Fixed.
  2. A notifier stopped between appearing and being noted. **Left on purpose**: noting earlier brings back #56's missed-release case. The window is up to 0.5 s, or the notification's lifetime with a notify-send without `--print-id`. Documented in `notify-update.sh` and PLAN.md.
  3. Two callers starting the same unit at once, one falling back to a plain copy. Fixed with the recheck. In practice only `updates check` (its own unit name) runs beside the timer.

## Tested
- `told` through `notify-update.sh`, with `notified-version` already 0.9.10 / 0.9.9 / absent / equal: an older version never replaces a newer one, and newer or equal is written.
- `gbfan_update_mark_told`: the same.
- `notify-dbus.py` with a stand-in `gi` module: the same three cases.
- A fake `systemd-run` that refuses while the unit becomes active: no plain copy.
- `bash -n`, `py_compile`, shellcheck: no new warnings.

## For the next person
- fingerprint-fix-sdcp got the same review findings for its copy (its #162). The same fix goes there.
