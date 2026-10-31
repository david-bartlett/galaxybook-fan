# The check: the chmod +x way too

PR #9 · Claude · 2026-10-31

## What changed
- README and the release page: under `sudo bash check-galaxybook-fan.sh`, the alternative `chmod +x check-galaxybook-fan.sh` then `sudo ./check-galaxybook-fan.sh`. Same note in the script's header comment.

## Why
- David downloaded it from the 0.4.0 release and tried `./check-galaxybook-fan.sh`, which was refused: browsers save downloads without permission to run.
