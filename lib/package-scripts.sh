#!/bin/bash
# =============================================================================
# galaxybook-fan - what the rpm, deb and Arch packages do after installing
# and before removing, so all three formats behave the same:
#
#   package-scripts.sh configure   after install or upgrade (rpm %post, deb
#                                  postinst configure, pacman post_install /
#                                  post_upgrade)
#   package-scripts.sh remove      before the package is removed - never on an
#                                  upgrade (rpm %preun with $1 = 0, deb prerm
#                                  remove, pacman pre_remove)
#   package-scripts.sh replace-clone   remove a copy installed with install.sh,
#                                  keeping what the package now owns (pacman
#                                  post_install / post_upgrade, before configure:
#                                  pacman runs nothing before unpacking; the rpm
#                                  and deb do this before, in pre-script.sh)
#
# Installed as /usr/lib/galaxybook-fan/package-scripts.sh. A package's install
# must never fail because of this: problems are explained, and the command
# says what to do (galaxybook-fan status / rebuild).
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
GBFAN_LAYOUT=package
# shellcheck source=fanpaths.sh
source "$HERE/fanpaths.sh"
# shellcheck source=fan-dkms.sh
source "$HERE/fan-dkms.sh"

info() { echo "galaxybook-fan: $*"; }
ok()   { echo "galaxybook-fan: $*"; }
warn() { echo "galaxybook-fan: WARNING: $*" >&2; }

fan_rpm() {
    local h
    for h in /sys/class/hwmon/hwmon*; do
        [[ "$(cat "$h/name" 2>/dev/null)" == "$MOD_NAME" ]] && { cat "$h/fan1_input" 2>/dev/null; return; }
    done
    return 1
}

# Run systemctl --user for everyone logged in now. "systemctl --global enable"
# only takes effect at each user's next login; this starts the timers in
# sessions that are already running (or stops them on removal), so nobody
# has to log out and in. Only sessions with a running desktop are touched.
user_systemctl_all() {
    local uid user bus
    for bus in /run/user/*/bus; do
        [[ -S "$bus" ]] || continue
        uid="$(basename "$(dirname "$bus")")"
        [[ "$uid" =~ ^[0-9]+$ && "$uid" -ge 1000 ]] || continue
        user="$(id -nu "$uid" 2>/dev/null)" || continue
        runuser -u "$user" -- env XDG_RUNTIME_DIR="/run/user/$uid" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
            systemctl --user "$@" >/dev/null 2>&1 || true
    done
}

secure_boot_on() {
    local var=/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d0-aa0d-00e098032b8c
    [[ -r "$var" ]] && [[ "$(od -An -t u1 -j 4 -N 1 "$var" 2>/dev/null | tr -d ' ')" == "1" ]]
}

# The certificate DKMS signs with: its config files in order, else its own pair
dkms_cert() {
    local f c="" v
    for f in /etc/dkms/framework.conf /etc/dkms/framework.conf.d/*.conf; do
        [[ -f "$f" ]] || continue
        v="$(sed -n 's/^[[:space:]]*mok_certificate=//p' "$f" | tail -1 | tr -d "\"'")"
        [[ -n "$v" ]] && c="$v"
    done
    echo "${c:-/var/lib/dkms/mok.pub}"
}

configure() {
    local v kver reason rpm d old hcmd k held=()
    v="$(tr -d '[:space:]' < "$GBFAN_LIBDIR/VERSION")"
    kver="$(uname -r)"
    GBFAN_LOG="$(mktemp)"       # global: the EXIT trap runs after this function returns

    trap 'gbfan_dkms_resume_initramfs; rm -f "$GBFAN_LOG"' EXIT
    gbfan_dkms_defer_initramfs >/dev/null

    # Other versions (an upgrade): the new one replaces them
    for d in /var/lib/dkms/"$PKG_NAME"/*/; do
        old="$(basename "$d")"
        [[ "$old" =~ ^[0-9][0-9.]*$ && "$old" != "$v" ]] || continue
        gbfan_unload || true
        dkms remove "${PKG_NAME}/${old}" --all >/dev/null 2>&1 || true
        # A deb upgrade deletes the old version's /usr/src first, and DKMS
        # then can't remove it ("Could not locate dkms.conf"; seen on Mint 22
        # and Ubuntu 26.04), leaving an entry that breaks 'dkms status' and
        # still holds the kernels it was installed for (seen on MX). Forget it,
        # noting those kernels, so the new version is installed for them below.
        while read -r k; do [[ -n "$k" ]] && held+=("$k"); done < <(gbfan_dkms_forget "$old")
    done

    [[ -d /var/lib/dkms/$PKG_NAME/$v ]] || dkms add -m "$PKG_NAME" -v "$v" >/dev/null 2>&1 || true
    info "checking the module for ${kver}; DKMS builds it from this laptop's firmware if needed"
    if gbfan_dkms_install "$v" "$kver" >"$GBFAN_LOG" 2>&1; then
        if grep -q 'already installed' "$GBFAN_LOG"; then
            info "already built for ${kver}"
        else
            info "built and installed for ${kver}; DKMS rebuilds it for new kernels"
        fi
    elif ! gbfan_has_headers "$kver"; then
        hcmd="$(gbfan_headers_cmd "$kver")"
        warn "the module wasn't built: the kernel headers for ${kver} aren't installed."
        [[ -n "$hcmd" ]] && warn "Install them: ${hcmd}"
        warn "then run: sudo galaxybook-fan rebuild"
    else
        reason="$(gbfan_dkms_build_reason "$v" || true)"
        warn "the module wasn't built for ${kver}${reason:+: ${reason#galaxybook-fan: }}"
        [[ -z "$reason" ]] && tail -5 "$GBFAN_LOG" >&2
        warn "the package is installed; see 'galaxybook-fan status', and 'sudo galaxybook-fan rebuild' once it's sorted"
    fi
    # Other kernels an old, forgotten version was installed for, and any the
    # new version is built for but not installed for (DKMS refused, over an
    # old version's file): install it there too, where their headers are
    # (else their old module stays until that kernel's next update, or
    # 'sudo galaxybook-fan rebuild' after booting it)
    for k in $( { printf '%s\n' "${held[@]}"; gbfan_dkms_built_only "$v"; } | sort -u); do
        [[ "$k" == "$kver" ]] && continue
        gbfan_has_headers "$k" || continue
        gbfan_dkms_install "$v" "$k" >/dev/null 2>&1
        # by what DKMS now says, not its exit status (see gbfan_dkms_install)
        if gbfan_dkms_installed_for "$v" "$k"; then
            info "also installed for ${k}"
        else
            warn "couldn't install the module for ${k}: 'sudo galaxybook-fan rebuild' after booting it"
        fi
    done

    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable "$UNBIND_SVC" >/dev/null 2>&1 || true
    systemctl --global enable "$USER_CHECK_TIMER" "$UPDATE_CHECK_TIMER" >/dev/null 2>&1 || true
    # ...and in sessions already running: the new-version timer at once (it
    # waits 60 s, then hourly); the login check's at its next login as before
    user_systemctl_all daemon-reload
    user_systemctl_all start "$UPDATE_CHECK_TIMER"

    if modprobe "$MOD_NAME" 2>/dev/null; then
        # Ours is reading the fan: take it from acpi-fan, now and at each boot.
        # restart, not enable --now: the unit stays active after it has run
        # (RemainAfterExit), so a copy left active by install.sh would never re-run
        systemctl restart "$UNBIND_SVC" >/dev/null 2>&1 || true
        gbfan_unbind_acpi_fan || true
        sleep 1
        rpm="$(fan_rpm || true)"
        info "module loaded${rpm:+ - fan: ${rpm} RPM}"
    elif secure_boot_on && dkms status -m "$PKG_NAME" -v "$v" -k "$kver" 2>/dev/null | grep -q installed; then
        warn "Secure Boot is on and the module's signing key isn't enrolled, so it can't load yet."
        warn "Enrol the key once (you choose a one-time password), then reboot and pick"
        warn "Enroll MOK -> Continue -> Yes -> the password -> Reboot:"
        warn "  sudo mokutil --import $(dkms_cert)"
    elif dkms status -m "$PKG_NAME" -v "$v" -k "$kver" 2>/dev/null | grep -q installed; then
        warn "the module didn't load - see: sudo dmesg | grep ${MOD_NAME}"
    fi
    # Not loaded (not built, refused, waiting for its key): the fan stays
    # with acpi-fan, which may well work here (an earlier Galaxy Book, a DSDT
    # override); the unbind service skips itself at boot until ours loads
    if [[ ! -d /sys/module/$MOD_NAME ]]; then
        systemctl stop "$UNBIND_SVC" >/dev/null 2>&1 || true
        gbfan_bind_acpi_fan
    fi

    # The login check compares against this kernel and BIOS from now on
    "$CHECK_SCRIPT" --record-state "" package >/dev/null 2>&1 || true
    return 0
}

remove() {
    gbfan_unload || true
    trap gbfan_dkms_resume_initramfs EXIT
    gbfan_dkms_defer_initramfs >/dev/null
    gbfan_dkms_remove_all >/dev/null 2>&1 || true

    systemctl disable --now "$UNBIND_SVC" >/dev/null 2>&1 || true
    systemctl --global disable "$USER_CHECK_TIMER" "$UPDATE_CHECK_TIMER" >/dev/null 2>&1 || true
    user_systemctl_all stop "$UPDATE_CHECK_TIMER" "$USER_CHECK_TIMER"
    # Give the fan back to the stock acpi-fan driver
    gbfan_bind_acpi_fan

    rm -f "$STATE_FILE" "$STATUS_FILE" "$FORCE_FLAG" "$UPDATES_OFF"
    rmdir "$GBFAN_ETC" "$STATE_DIR" 2>/dev/null || true
    return 0
}

# The install.sh copy's paths are the clone layout, so this runs in a
# subshell with lib/fanpaths.sh read again for that layout.
replace_clone() {
    (
        GBFAN_LAYOUT=clone
        # shellcheck source=fanpaths.sh
        source "$HERE/fanpaths.sh"
        # shellcheck source=fan-dkms.sh
        source "$HERE/fan-dkms.sh"
        # shellcheck source=clone-remove.sh
        source "$HERE/clone-remove.sh"
        gbfan_clone_installed || exit 0
        local from
        from=$(sed -n 's/^INSTALL_DIR=//p' "$STATE_FILE" 2>/dev/null | head -1)
        info "removing the copy installed with install.sh${from:+ (from ${from})}; the package replaces it"
        trap gbfan_dkms_resume_initramfs EXIT
        if GBFAN_KEEP_VERSION="$(tr -d '[:space:]' < "$HERE/VERSION")" gbfan_remove_clone; then
            info "the install.sh copy is removed; from now on use 'galaxybook-fan status' and 'sudo galaxybook-fan rebuild'"
            [[ -n "$from" ]] && info "the package doesn't use ${from}: keep it or delete it, as you like"
        else
            warn "the install.sh copy is still here: ${MOD_NAME} couldn't be unloaded."
            warn "Close anything reading the fan speed (or reboot), then install the package again."
        fi
        return 0
    )
}

case "${1:-}" in
    configure)     configure ;;
    remove)        remove ;;
    replace-clone) replace_clone ;;
    *) echo "Usage: $0 configure|remove|replace-clone" >&2; exit 2 ;;
esac
