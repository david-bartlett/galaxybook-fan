# "What's new" keeps the notification

PR #27 · Claude · 2026-10-31

## What changed
- `lib/notify-update.sh`: the notification is shown with `--hint=boolean:resident:true` (the server keeps it when a button is pressed: GNOME does, KDE doesn't) and `--print-id` where `notify-send` has it. *What's new* opens the page in the background and loops to show the notification again with `--replace-id=<id>`, so it replaces itself rather than duplicating. *Update now* (terminal) or closing it ends the loop; at most 20 rounds. Without `--print-id` it's shown afresh.
- CHANGELOG, PLAN.md §4.

## Why
- David on KDE: pressing *What's new* closed the notification, so *Update now* was gone.

## Tested
- Here with a stub server: *What's new*, *What's new*, *Update now* → page opened twice, notification re-shown twice with `--replace-id=42`, then the terminal; *What's new* then closed → ends; no `--print-id` → re-shown as new, then the terminal. shellcheck, `bash -n`.
- Not tested: KDE and GNOME for real.

## For the next person
- Drawn by the installed version: the release after this one is the first whose announcement behaves like this.
