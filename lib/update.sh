# shellcheck shell=bash
# =============================================================================
# galaxybook-fan - is there a newer release? Shared by the login check (which
# says so once per version, at most once a day) and 'galaxybook-fan update'.
# Source lib/fanpaths.sh first.
#
# The latest release comes from where github.com/.../releases/latest
# redirects to (.../releases/tag/vX.Y.Z): no GitHub API, so no rate limit.
# While the repository is private GitHub answers 404 to this, so nothing is
# found and nothing is said. GBFAN_REPO_URL points it somewhere else, for
# testing.
# =============================================================================

GBFAN_REPO_URL="${GBFAN_REPO_URL:-https://github.com/david-bartlett/galaxybook-fan}"

# The installed version: the package's VERSION file, or the one install.sh
# writes beside it; else what DKMS has registered
gbfan_installed_version() {
    local v=""
    [[ -r "$GBFAN_LIBDIR/VERSION" ]] && v="$(tr -d '[:space:]' < "$GBFAN_LIBDIR/VERSION")"
    [[ -n "$v" ]] || v="$(gbfan_dkms_version 2>/dev/null || true)"
    [[ -n "$v" ]] && echo "$v"
}

# The newest release's version, e.g. 0.7.0 (fails when GitHub can't be
# reached, or says nothing usable)
gbfan_latest_version() {
    local url v
    command -v curl >/dev/null 2>&1 || return 1
    url="$(curl -fsS -o /dev/null --connect-timeout 5 --max-time 15 \
        -w '%{redirect_url}' "$GBFAN_REPO_URL/releases/latest" 2>/dev/null)" || return 1
    v="${url##*/tag/v}"
    [[ "$url" == */tag/v* && "$v" =~ ^[0-9]+(\.[0-9]+)*$ ]] || return 1
    echo "$v"
}

# gbfan_version_newer CURRENT LATEST - true if LATEST is newer
gbfan_version_newer() {
    [[ -n "$1" && -n "$2" && "$1" != "$2" ]] \
        && [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" == "$2" ]]
}

# How to update, for how it was installed
gbfan_update_hint() {
    local method dir
    method="$(sed -n 's/^INSTALL_METHOD=//p' "$STATE_FILE" 2>/dev/null | tail -1)"
    dir="$(sed -n 's/^INSTALL_DIR=//p' "$STATE_FILE" 2>/dev/null | tail -1)"
    if [[ "$method" == package ]]; then
        echo "sudo galaxybook-fan update"
    else
        echo "git pull (or the new release's source code), then sudo ./install.sh, in ${dir:-the galaxybook-fan folder}"
    fi
}

gbfan_release_url() { echo "$GBFAN_REPO_URL/releases/tag/v$1"; }

# The notification's title and text (CURRENT LATEST), shared by the hourly
# check and 'galaxybook-fan updates check'. The command and the link are in
# the text on every desktop (GNOME shows no buttons; a click there opens the
# release page, notify-update.sh), each on its own line so
# they don't run together when wrapped.
gbfan_update_title() { echo "galaxybook-fan $2 is available"; }
gbfan_update_text() {
    printf 'You have %s.\nTo update, run: %s\n\nWhat'"'"'s new: %s' "$1" "$(gbfan_update_hint)" "$(gbfan_release_url "$2")"
}

# Show it: with "Update now" / "What's new" where buttons work
# (notify-update.sh, which waits for a click, so it runs on its own via
# systemd-run), else plainly. Run as the user, in their desktop.
gbfan_update_notify() {
    # notify-update.sh beside the script that's running (GBFAN_HERE: a clone's
    # lib/ when run from one), else the installed library folder
    local cur="$1" latest="$2" unit="${3:-galaxybook-fan-notify-$2}" title text
    local notifier="${GBFAN_HERE:-$GBFAN_LIBDIR}/notify-update.sh"
    title="$(gbfan_update_title "$cur" "$latest")"
    text="$(gbfan_update_text "$cur" "$latest")"
    if [[ -x "$notifier" ]] && command -v systemd-run >/dev/null 2>&1 \
            && systemd-run --user --collect --quiet --unit="$unit" "$notifier" \
                "$title" "$text" "$(gbfan_release_url "$latest")" 2>/dev/null; then
        return 0
    fi
    notify-send -t 0 -a "Samsung Galaxy Book Fixes" -i system-software-update "$title" "$text"
}

# Remember a version was announced to this user (so it's said once)
gbfan_update_mark_told() {
    local dir="${XDG_STATE_HOME:-$HOME/.local/state}/galaxybook-fan"
    mkdir -p "$dir" 2>/dev/null && echo "$1" > "$dir/notified-version"
}
