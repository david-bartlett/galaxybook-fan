# updates status: the on / off command on its own line

PR #<n> · Claude · 2026-11-01

## What changed
- `lib/galaxybook-fan` `cmd_updates status` (also shown by `galaxybook-fan status`): *"New version" notifications: on (GitHub checked at login and hourly)*, then *To turn them off: sudo galaxybook-fan updates off* on the next line (off: *To turn them on: …*). It was *on, GitHub asked hourly (sudo galaxybook-fan updates off)*.
- CHANGELOG.

## Why
- David: the command in brackets read as if the notifications were off.

## Tested
- `bash -n`, shellcheck; both states printed by hand.
