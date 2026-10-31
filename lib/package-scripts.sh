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
    local v kver reason rpm d old dev
    v="$(tr -d '[:space:]' < "$GBFAN_LIBDIR/VERSION")"
    kver="$(uname -r)"
    GBFAN_LOG="$(mktemp)"       # global: the EXIT trap runs after this function returns

    trap 'gbfan_dkms_resume_initramfs; rm -f "$GBFAN_LOG"' EXIT
    gbfan_dkms_defer_initramfs >/dev/null

    # Other versions (an upgrade): the new one replaces them
    for d in /var/lib/dkms/"$PKG_NAME"/*/; do
        old="$(basename "$d")"
        [[ "$old" =~ ^[0-9][0-9.]*$ && "$old" != "$v" ]] || continue
        modprobe -r "$MOD_NAME" 2>/dev/null || true
        dkms remove "${PKG_NAME}/${old}" --all >/dev/null 2>&1 || true
    done

    [[ -d /var/lib/dkms/$PKG_NAME/$v ]] || dkms add -m "$PKG_NAME" -v "$v" >/dev/null 2>&1 || true
    info "checking the module for ${kver}; DKMS builds it from this laptop's firmware if needed"
    if dkms install -m "$PKG_NAME" -v "$v" -k "$kver" >"$GBFAN_LOG" 2>&1; then
        if grep -q 'already installed' "$GBFAN_LOG"; then
            info "already built for ${kver}"
        else
            info "built and installed for ${kver}; DKMS rebuilds it for new kernels"
        fi
    else
        reason="$(gbfan_dkms_build_reason "$v" || true)"
        warn "the module wasn't built for ${kver}${reason:+: ${reason#galaxybook-fan: }}"
        [[ -z "$reason" ]] && tail -5 "$GBFAN_LOG" >&2
        warn "the package is installed; see 'galaxybook-fan status', and 'sudo galaxybook-fan rebuild' once it's sorted"
    fi

    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable "$UNBIND_SVC" >/dev/null 2>&1 || true
    # restart, not enable --now: the unit stays active after it has run
    # (RemainAfterExit), so a copy left active by install.sh would never re-run
    systemctl restart "$UNBIND_SVC" >/dev/null 2>&1 || true
    systemctl --global enable "$USER_CHECK_TIMER" >/dev/null 2>&1 || true
    # and unbind straight away in case systemd isn't running
    for dev in "$ACPI_FAN_DRV"/PNP0C0B:*; do
        [[ -e "$dev" ]] || continue
        echo "$(basename "$dev")" > "$ACPI_FAN_DRV/unbind" 2>/dev/null || true
    done

    if modprobe "$MOD_NAME" 2>/dev/null; then
        sleep 1
        rpm="$(fan_rpm || true)"
        info "module loaded${rpm:+ - fan: ${rpm} RPM}"
    elif secure_boot_on && dkms status -m "$PKG_NAME" -v "$v" -k "$kver" 2>/dev/null | grep -q installed; then
        warn "Secure Boot is on and the module's signing key isn't enrolled, so it can't load yet."
        warn "Enrol the key once (you choose a one-time password), then reboot and pick"
        warn "Enroll MOK -> Continue -> Yes -> the password -> Reboot:"
        warn "  sudo mokutil --import $(dkms_cert)"
    else
        warn "the module didn't load - see: sudo dmesg | grep ${MOD_NAME}"
    fi

    # The login check compares against this kernel and BIOS from now on
    "$CHECK_SCRIPT" --record-state "" package >/dev/null 2>&1 || true
    return 0
}

remove() {
    local dev name
    modprobe -r "$MOD_NAME" 2>/dev/null || true
    trap gbfan_dkms_resume_initramfs EXIT
    gbfan_dkms_defer_initramfs >/dev/null
    gbfan_dkms_remove_all >/dev/null 2>&1 || true

    systemctl disable --now "$UNBIND_SVC" >/dev/null 2>&1 || true
    systemctl --global disable "$USER_CHECK_TIMER" >/dev/null 2>&1 || true
    # Give the fan back to the stock acpi-fan driver
    for dev in /sys/bus/platform/devices/PNP0C0B:*; do
        [[ -e "$dev" ]] || continue
        name="$(basename "$dev")"
        [[ -e "$ACPI_FAN_DRV/$name" ]] || echo "$name" > "$ACPI_FAN_DRV/bind" 2>/dev/null || true
    done

    rm -f "$STATE_FILE" "$STATUS_FILE" "$FORCE_FLAG"
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
