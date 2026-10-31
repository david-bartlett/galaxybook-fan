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
    info "building the module for ${kver} from this laptop's firmware (DKMS)"
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

case "${1:-}" in
    configure) configure ;;
    remove)    remove ;;
    *) echo "Usage: $0 configure|remove" >&2; exit 2 ;;
esac
