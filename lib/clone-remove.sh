# shellcheck shell=bash
# =============================================================================
# galaxybook-fan - remove a copy installed with install.sh (the clone layout)
#
# Used by uninstall.sh, and built into the packages' pre-install step (rpm
# %pre, deb preinst) by packaging/pre-script.sh, so installing a package over
# an install.sh copy replaces that copy instead of refusing. One copy of the
# removal steps for both.
#
# Source lib/fanpaths.sh (GBFAN_LAYOUT=clone) and lib/fan-dkms.sh first; the
# caller defines info, ok and warn.
# =============================================================================

# Is a copy installed with install.sh here? Only files install.sh alone makes
# count (every version had the unbind service or the older udev rule): the
# autoload file can be a removed-but-not-purged deb's conffile, which this
# must leave alone, or dpkg wouldn't put it back on a reinstall.
gbfan_clone_installed() {
    [[ -e "$GBFAN_CMD" || -e "$CHECK_SCRIPT" || -e "$UNBIND_SERVICE" \
        || -e "$UDEV_RULE" || -d "$GBFAN_LIBDIR" ]]
}

# Remove it all and give the fan back to acpi-fan. Returns 1, having changed
# nothing, if the module is loaded and can't be unloaded.
# GBFAN_KEEP_VERSION=X.Y.Z: run after a package with that version has been
# unpacked (Arch's post_install, where pacman can't run anything earlier):
# keep the files the package now owns or uses as well - its source in
# /usr/src, the autoload file, the force flag and the state - and don't rebind
# acpi-fan (the package's install takes the fan straight back).
gbfan_remove_clone() {
    local f d home udir user uid removed_monitor=0 in_use dev name rebound=0
    local keep="${GBFAN_KEEP_VERSION:-}"

    if [[ -d /sys/module/$MOD_NAME ]]; then
        gbfan_unload || { warn "Couldn't unload ${MOD_NAME}"; return 1; }
        ok "Unloaded ${MOD_NAME}"
    fi

    # Suspend DKMS's post_transaction initramfs rebuild (Fedora runs dracut
    # --regenerate-all there) for these DKMS steps - galaxybook_fan is never in
    # the initramfs. Callers also run gbfan_dkms_resume_initramfs from an EXIT
    # trap, so it's put back even if this stops half way.
    gbfan_dkms_defer_initramfs
    if [[ -d /var/lib/dkms/$PKG_NAME ]]; then
        gbfan_dkms_remove_all
        ok "Removed from DKMS"
    fi
    for d in /usr/src/"${PKG_NAME}"-*; do
        [[ -e "$d" && "$d" != "/usr/src/${PKG_NAME}-${keep}" ]] || continue
        rm -rf "$d" && ok "Removed ${d}"
    done
    gbfan_dkms_resume_initramfs

    for f in "$MODPROBE_CONF" "$DKMS_SIGN_CONF" "$DRACUT_CONF"; do
        [[ -f "$f" ]] && rm -f "$f" && ok "Removed ${f}"
    done
    if [[ -z "$keep" ]]; then
        for f in "$MODLOAD_CONF" "$FORCE_FLAG"; do
            [[ -f "$f" ]] && rm -f "$f" && ok "Removed ${f}"
        done
        rmdir "$GBFAN_ETC" 2>/dev/null || true
    fi
    [[ -f "$GBFAN_CMD" ]] && rm -f "$GBFAN_CMD" && ok "Removed the galaxybook-fan command"

    if [[ -f "$UNBIND_SERVICE" ]]; then
        # --now: stop it too, or it stays "active" (RemainAfterExit) after the
        # unit file has gone, and a later install's enable --now wouldn't re-run it
        systemctl disable --now "$(basename "$UNBIND_SERVICE")" >/dev/null 2>&1 || true
        rm -f "$UNBIND_SERVICE"
        systemctl daemon-reload 2>/dev/null || true
        ok "Removed $(basename "$UNBIND_SERVICE")"
    fi

    if [[ -f "$UDEV_RULE" ]]; then
        rm -f "$UDEV_RULE"
        udevadm control --reload 2>/dev/null || true
        ok "Removed ${UDEV_RULE}"
    fi

    # Login check: user timers for every user, root monitor, polkit rule, scripts
    for home in /home/*/; do
        udir="${home}.config/systemd/user"
        rm -f "${udir}/${USER_CHECK_TIMER}" "${udir}/${USER_CHECK_SVC}" \
              "${udir}/graphical-session.target.wants/${USER_CHECK_TIMER}"
    done
    user="$(loginctl list-sessions --no-legend 2>/dev/null | awk '$4 == "seat0" {print $3}' | head -1)"
    uid="$(id -u "$user" 2>/dev/null)"
    if [[ -n "$user" && -n "$uid" ]]; then
        runuser -u "$user" -- env XDG_RUNTIME_DIR="/run/user/${uid}" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus" \
            systemctl --user daemon-reload 2>/dev/null || true
    fi
    for f in "/etc/systemd/system/${MONITOR_SVC}" "$POLKIT_RULE" "$CHECK_SCRIPT" "$USER_CHECK_SCRIPT"; do
        [[ -f "$f" ]] && rm -f "$f" && removed_monitor=1
    done
    rm -rf "$GBFAN_LIBDIR"
    rmdir /usr/local/lib/samsung-galaxybook 2>/dev/null || true
    [[ -z "$keep" ]] && rm -f "$STATE_FILE" "$STATUS_FILE"
    systemctl daemon-reload 2>/dev/null || true
    [[ $removed_monitor -eq 1 ]] && ok "Removed the login check (timer, monitor service, polkit rule)"

    # Shared graphical session helper - only if this fix registered for it, and
    # only removed when no other fix still uses it
    if [[ -f "$SESSION_HELPER_USERS/galaxybook-fan" ]]; then
        rm -f "$SESSION_HELPER_USERS/galaxybook-fan"
        in_use=false
        if [[ -d "$SESSION_HELPER_USERS" ]] && [[ -n "$(ls -A "$SESSION_HELPER_USERS" 2>/dev/null)" ]]; then
            in_use=true
        fi
        # webcam-toggle versions without a marker still rely on it
        for home in /home/*/; do
            [[ -f "${home}.config/systemd/user/webcam-switch-watch.service" ]] && in_use=true
        done
        if $in_use; then
            info "Graphical session helper kept — still used by another fix"
        else
            rm -f "$SESSION_HELPER_TARGET" "$SESSION_HELPER_SCRIPT" "$SESSION_HELPER_AUTOSTART"
            rmdir "$SESSION_HELPER_USERS" /etc/samsung-galaxybook 2>/dev/null || true
            info "Removed graphical session helper"
        fi
    fi

    [[ -n "$keep" ]] && return 0
    # Rebind acpi-fan to any unbound PNP0C0B fan device
    for dev in /sys/bus/platform/devices/PNP0C0B:*; do
        [[ -e "$dev" ]] || continue
        name="$(basename "$dev")"
        if [[ ! -e "$ACPI_FAN_DRV/$name" ]]; then
            echo "$name" > "$ACPI_FAN_DRV/bind" 2>/dev/null && ok "Rebound acpi-fan to ${name}" && rebound=1
        fi
    done
    [[ $rebound -eq 0 ]] && info "acpi-fan already bound (or no fan device found)"
    return 0
}
