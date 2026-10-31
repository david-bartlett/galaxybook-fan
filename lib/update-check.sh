#!/bin/bash
# =============================================================================
# galaxybook-fan - "a new version is out" (runs as the user, from
# galaxybook-fan-update-check.timer: 30 s after login, then hourly)
#
# Goes to GitHub at most once a day, and tells once per version. At login the
# network may not be up yet, so it tries for about 2 minutes; if GitHub still
# can't be reached it says nothing and records nothing, and the next hourly
# run tries again. The service doesn't start at all while
# 'galaxybook-fan updates off' is set or the fix isn't installed.
#
# GBFAN_UPDATE_EVERY (seconds, default a day) and GBFAN_UPDATE_TRIES /
# GBFAN_UPDATE_WAIT (attempts, seconds between them) are for testing.
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
for f in fanpaths.sh fan-dkms.sh update.sh; do
    # shellcheck disable=SC1090
    source "$HERE/$f" 2>/dev/null || exit 0
done
[[ -e "$UPDATES_OFF" ]] && exit 0

dir="${XDG_STATE_HOME:-$HOME/.local/state}/galaxybook-fan"
mkdir -p "$dir" 2>/dev/null || exit 0
now="$(date +%s)"
last="$(cat "$dir/last-update-check" 2>/dev/null || echo 0)"
[[ "$last" =~ ^[0-9]+$ ]] || last=0
(( now - last < ${GBFAN_UPDATE_EVERY:-86400} )) && exit 0

cur="$(gbfan_installed_version)" || exit 0
latest=""
for (( i = 1; i <= ${GBFAN_UPDATE_TRIES:-8}; i++ )); do
    latest="$(gbfan_latest_version)" && break
    latest=""
    (( i < ${GBFAN_UPDATE_TRIES:-8} )) && sleep "${GBFAN_UPDATE_WAIT:-15}"
done
[[ -n "$latest" ]] || exit 0                  # not reached: the next run tries again
date +%s > "$dir/last-update-check"

gbfan_version_newer "$cur" "$latest" || exit 0
[[ "$(cat "$dir/notified-version" 2>/dev/null)" == "$latest" ]] && exit 0
# The command and the link are in the text on every desktop (GNOME shows no
# buttons), each on its own line so they don't run together when wrapped.
# Where buttons work, notify-update.sh adds "Update now" and "What's new"; it
# waits for a click, so it runs on its own (systemd-run) and this script ends.
title="galaxybook-fan $latest is available"
msg="You have $cur.
To update, run: $(gbfan_update_hint)

What's new: $(gbfan_release_url "$latest")"
if [[ -x "$HERE/notify-update.sh" ]] && command -v systemd-run >/dev/null 2>&1 \
        && systemd-run --user --collect --quiet --unit="galaxybook-fan-notify-$latest" \
            "$HERE/notify-update.sh" "$title" "$msg" "$(gbfan_release_url "$latest")" 2>/dev/null; then
    echo "$latest" > "$dir/notified-version"
elif notify-send -t 0 -a "Samsung Galaxy Book Fixes" -i system-software-update "$title" "$msg"; then
    echo "$latest" > "$dir/notified-version"
fi
exit 0
