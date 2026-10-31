# "What's new" keeps the notification

PR #27 · Claude · 2026-10-31

## What changed
- `lib/notify-update.sh`: *What's new* opens the page in the background and loops to show the notification again, with `--replace-id=<id>` from `--print-id` where `notify-send` has them, so it replaces itself rather than duplicating. *Update now* (terminal) or closing it ends the loop; at most 20 rounds. Without `--print-id` it's shown afresh.
- **Tried and dropped: the `resident` hint.** On David's KDE, *What's new* then only hid the notification and `notify-send` kept running: it reports a button only once the notification closes, and KDE moved the resident one into its history instead of closing it. So no hint, and no closing by D-Bus either: every desktop closes a non-resident notification on a button press.
- CHANGELOG, PLAN.md §4.

## Why
- David on KDE: pressing *What's new* closed the notification, so *Update now* was gone; and it must disappear on *Update now*.

## Tested
- Here with a stub server: *What's new*, *What's new*, *Update now* → page opened twice, notification re-shown twice with `--replace-id=42`, then the terminal; *What's new* then closed → ends; no `--print-id` → re-shown as new, then the terminal. shellcheck, `bash -n`.
- Not tested: KDE and GNOME for real.

## For the next person
- Drawn by the installed version: the release after this one is the first whose announcement behaves like this.
