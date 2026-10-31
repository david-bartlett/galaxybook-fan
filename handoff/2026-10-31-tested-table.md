# README: tested-on table after packaging step 1

PR #14 · Claude · 2026-10-31

## What changed
- README's *Tested on*: a one-line summary, with the per-distro table in a collapsible section. Current kernels; Mint 22.3 instead of 27 (beta), which was replaced on the laptop; MX 25.3; a column for the `galaxybook-fan` command. Says which columns were tested on 31 Oct (install, check, command) and which on 23 Oct with 0.2 (`--test-native`, login check, uninstall).

## Tested
- David's results on 31 Oct: install from main, `galaxybook-fan status`, `check` and `rebuild` on all five distros; `/usr/src` has `gen-config.sh` and no ready-made header everywhere. Signing: Fedora akmods key, Ubuntu and Mint MOK keys (all enrolled; modules loaded); MX and CachyOS Secure Boot off (they don't boot with it on). MX rebuilt all three of its kernels.

## For the next person
- `--test-native`, the login check and uninstall weren't re-run with the new code; on Mint they were only ever run on 27 (beta). Worth re-running before the first packaged release.
