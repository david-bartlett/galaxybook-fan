#!/bin/bash
# ============================================================================
# galaxybook-fan - uninstall
#
# Removes the DKMS module, its autoload/options files, the acpi-fan unbind
# service (and any old udev rule) and the DKMS signing drop-in (if install.sh
# created it), then rebinds the stock acpi-fan driver.
#
# Usage: sudo ./uninstall.sh
# ============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Names and paths shared with install.sh (clone layout), and the DKMS helpers
GBFAN_LAYOUT=clone
for _f in fanpaths.sh fan-dkms.sh; do
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/lib/$_f" || { echo "lib/$_f missing from ${SCRIPT_DIR}" >&2; exit 1; }
done

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC}  $*"; }
fail() { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }
warn() { echo -e "\033[1;33m[WARN]${NC}  $*"; }

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root: sudo ./uninstall.sh"
    exit 1
fi

if gbfan_package_installed; then
    fail "The galaxybook-fan package is installed - remove it with your package manager instead (e.g. sudo dnf remove galaxybook-fan)."
fi

echo
echo "================================================"
echo "  Samsung Galaxy Book fan speed (DKMS) - uninstall"
echo "================================================"
echo

if [[ -d /sys/module/$MOD_NAME ]]; then
    modprobe -r "$MOD_NAME" && ok "Unloaded ${MOD_NAME}" || fail "Couldn't unload ${MOD_NAME}"
fi

# Suspend DKMS's post_transaction initramfs rebuild (Fedora runs dracut
# --regenerate-all there) for this script's DKMS steps - galaxybook_fan is
# never in the initramfs. The trap puts it back even if the script fails.
trap gbfan_dkms_resume_initramfs EXIT
gbfan_dkms_defer_initramfs

if [[ -d /var/lib/dkms/$PKG_NAME ]]; then
    gbfan_dkms_remove_all
    ok "Removed from DKMS"
fi
rm -rf /usr/src/"${PKG_NAME}"-* && ok "Removed source from /usr/src"

for f in "$MODLOAD_CONF" "$MODPROBE_CONF" "$DKMS_SIGN_CONF" "$DRACUT_CONF" "$FORCE_FLAG"; do
    [[ -f "$f" ]] && rm -f "$f" && ok "Removed ${f}"
done
rmdir "$GBFAN_ETC" 2>/dev/null || true
[[ -f "$GBFAN_CMD" ]] && rm -f "$GBFAN_CMD" && ok "Removed the galaxybook-fan command"

if [[ -f "$UNBIND_SERVICE" ]]; then
    systemctl disable "$(basename "$UNBIND_SERVICE")" >/dev/null 2>&1 || true
    rm -f "$UNBIND_SERVICE"
    systemctl daemon-reload
    ok "Removed $(basename "$UNBIND_SERVICE")"
fi

if [[ -f "$UDEV_RULE" ]]; then
    rm -f "$UDEV_RULE"
    udevadm control --reload
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
removed_monitor=0
for f in "/etc/systemd/system/${MONITOR_SVC}" "$POLKIT_RULE" "$CHECK_SCRIPT" "$USER_CHECK_SCRIPT"; do
    [[ -f "$f" ]] && rm -f "$f" && removed_monitor=1
done
rm -rf "$GBFAN_LIBDIR"
rmdir /usr/local/lib/samsung-galaxybook 2>/dev/null || true
rm -f /var/lib/samsung-galaxybook/fan-state /run/samsung-galaxybook/fan-status
systemctl daemon-reload
[[ $removed_monitor -eq 1 ]] && ok "Removed the login check (timer, monitor service, polkit rule)"

# Shared graphical session helper - only if this fix registered for it, and
# only removed when no other fix still uses it
if [[ -f "$SESSION_HELPER_USERS/galaxybook-fan" ]]; then
    rm -f "$SESSION_HELPER_USERS/galaxybook-fan"
    _session_helper_in_use=false
    if [[ -d "$SESSION_HELPER_USERS" ]] && [[ -n "$(ls -A "$SESSION_HELPER_USERS" 2>/dev/null)" ]]; then
        _session_helper_in_use=true
    fi
    # webcam-toggle versions without a marker still rely on it
    for USER_HOME in /home/*/; do
        [[ -f "${USER_HOME}.config/systemd/user/webcam-switch-watch.service" ]] && _session_helper_in_use=true
    done
    if $_session_helper_in_use; then
        info "Graphical session helper kept — still used by another fix"
    else
        rm -f /etc/systemd/user/samsung-galaxybook-session.target \
              /usr/local/bin/samsung-galaxybook-session-start.sh \
              /etc/xdg/autostart/samsung-galaxybook-session.desktop
        rmdir "$SESSION_HELPER_USERS" /etc/samsung-galaxybook 2>/dev/null || true
        info "Removed graphical session helper"
    fi
fi

# Rebind acpi-fan to any unbound PNP0C0B fan device
rebound=0
for dev in /sys/bus/platform/devices/PNP0C0B:*; do
    [[ -e "$dev" ]] || continue
    name="$(basename "$dev")"
    if [[ ! -e "$ACPI_FAN_DRV/$name" ]]; then
        echo "$name" > "$ACPI_FAN_DRV/bind" 2>/dev/null && ok "Rebound acpi-fan to ${name}" && rebound=1
    fi
done
[[ $rebound -eq 0 ]] && info "acpi-fan already bound (or no fan device found)"

echo
ok "Done. Fan speed reporting is back to the stock (broken) acpi-fan driver."
echo
