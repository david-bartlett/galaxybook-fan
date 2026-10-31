# galaxybook-fan check / test-native from the clone

PR #12 · Claude · 2026-10-31

## What changed
- `lib/galaxybook-fan` uses the installed check scripts when they're there, and otherwise the clone's (`lib/samsung-galaxybook-fan-check.sh`, `tools/check-galaxybook-fan.sh`). Before, `sudo ./lib/galaxybook-fan check` from a clone failed with "check-galaxybook-fan.sh is missing", and `test-native` needed the installed login-check script.

## Tested
- From a clone with nothing installed: `check` runs the clone's check; `test-native` runs (no fan device in the test machine, so "No ACPI fan device").
