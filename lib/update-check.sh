#!/bin/bash
# =============================================================================
# galaxybook-fan - "a new version is out" (runs as the user, from
# galaxybook-fan-update-check.timer: 60 s after login, then hourly)
#
# Goes to GitHub at most about once an hour, and always at the first check
# after login (as fingerprint-fix-sdcp's check does), and tells once per
# version. At login
# the network may not be up yet, so it tries for about 2 minutes; if GitHub
# still can't be reached it says nothing and records nothing, and the next
# hourly run tries again. The same if the new release's files aren't attached
# yet (gbfan_release_ready): it's only announced once they're there, so
# 'galaxybook-fan update' can install it. The service doesn't start at all while
# 'galaxybook-fan updates off' is set or the fix isn't installed.
#
# GBFAN_UPDATE_EVERY (seconds, default 55 minutes: the timer runs on the hour,
# so a full 60 would skip every other hour) and GBFAN_UPDATE_TRIES /
# GBFAN_UPDATE_WAIT (attempts, seconds between them) are for testing.
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
for f in fanpaths.sh fan-dkms.sh update.sh; do
    # shellcheck disable=SC1090
    source "$HERE/$f" 2>/dev/null || exit 0
done
[[ -e "$UPDATES_OFF" ]] && exit 0
GBFAN_HERE="$HERE"                    # notify-update.sh is beside this script

dir="${XDG_STATE_HOME:-$HOME/.local/state}/galaxybook-fan"
mkdir -p "$dir" 2>/dev/null || exit 0
now="$(date +%s)"
last="$(cat "$dir/last-update-check" 2>/dev/null || echo 0)"
[[ "$last" =~ ^[0-9]+$ ]] || last=0
# When this login's desktop session started (0 if systemd can't say): an
# answer from before it doesn't count, so the first check of a login asks
login="$(systemctl --user show -P ActiveEnterTimestamp --timestamp=unix graphical-session.target 2>/dev/null)"
login="${login#@}"; login="${login%%.*}"
[[ "$login" =~ ^[0-9]+$ ]] || login=0
(( last >= login && now - last < ${GBFAN_UPDATE_EVERY:-3300} )) && exit 0

cur="$(gbfan_installed_version)" || exit 0
latest=""
for (( i = 1; i <= ${GBFAN_UPDATE_TRIES:-8}; i++ )); do
    latest="$(gbfan_latest_version)" && break
    latest=""
    (( i < ${GBFAN_UPDATE_TRIES:-8} )) && sleep "${GBFAN_UPDATE_WAIT:-15}"
done
[[ -n "$latest" ]] || exit 0                  # not reached: the next run tries again
stamp() { date +%s > "$dir/last-update-check"; }
gbfan_version_newer "$cur" "$latest" || { stamp; exit 0; }
[[ "$(cat "$dir/notified-version" 2>/dev/null)" == "$latest" ]] && { stamp; exit 0; }
# A release whose files aren't attached yet: not recorded, so the next
# hourly run looks again
gbfan_release_ready "$latest" || exit 0
stamp
# The notification, with buttons where the desktop shows them (lib/update.sh)
gbfan_update_notify "$cur" "$latest" && gbfan_update_mark_told "$latest"
exit 0
