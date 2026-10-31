# "What's new" keeps the notification

PR #27 · Claude · 2026-10-31

## What changed
- `lib/notify-update.sh`: *What's new* opens the page in the background, waits 2 s (so the notification pops up after the browser window), and shows a **fresh** copy of the notification. Desktops close a notification when one of its buttons is pressed, so there's never two. *Update now* (terminal) or closing it ends the loop; at most 20 rounds.
- **Tried and dropped on David's KDE:**
  - the `resident` hint: *What's new* only hid the notification and `notify-send` kept waiting. It reports a button once the notification closes, and KDE kept the resident one instead.
  - `--replace-id` (from `--print-id`) to re-show it in place: the notification never came back and `notify-send` waited on it. KDE updates the already-closed one quietly instead of showing it.
- CHANGELOG, PLAN.md §4.

## Why
- David on KDE: pressing *What's new* closed the notification, so *Update now* was gone; and it must disappear on *Update now*.

## Tested
- Here with a stub server: *What's new* then *Update now* → page opened, a fresh notification 2 s later, then the terminal; closed → ends. shellcheck, `bash -n`.
- Not tested: KDE and GNOME for real.

## For the next person
- Drawn by the installed version: the release after this one is the first whose announcement behaves like this.
