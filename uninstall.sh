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

PKG_NAME="galaxybook-fan"
MOD_NAME="galaxybook_fan"
MODLOAD_CONF="/etc/modules-load.d/${MOD_NAME}.conf"
MODPROBE_CONF="/etc/modprobe.d/${MOD_NAME}.conf"
UDEV_RULE="/etc/udev/rules.d/90-galaxybook-acpi-fan-unbind.rules"   # old versions only
UNBIND_SERVICE="/etc/systemd/system/galaxybook-acpi-fan-unbind.service"
DKMS_SIGN_CONF="/etc/dkms/framework.conf.d/${PKG_NAME}-signing.conf"
ACPI_FAN_DRV="/sys/bus/platform/drivers/acpi-fan"
CHECK_SCRIPT="/usr/local/bin/samsung-galaxybook-fan-check.sh"
USER_CHECK_SCRIPT="/usr/local/bin/samsung-galaxybook-fan-user-check.sh"
PARSER_DIR="/usr/local/lib/samsung-galaxybook/fan"
MONITOR_SVC="samsung-galaxybook-fan-monitor.service"
USER_CHECK_SVC="samsung-galaxybook-fan-user-check.service"
USER_CHECK_TIMER="samsung-galaxybook-fan-user-check.timer"
POLKIT_RULE="/etc/polkit-1/rules.d/49-samsung-galaxybook-fan-monitor.rules"

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
info() { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC}  $*"; }
fail() { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root: sudo ./uninstall.sh"
    exit 1
fi

echo
echo "================================================"
echo "  Samsung Galaxy Book fan speed (DKMS) - uninstall"
echo "================================================"
echo

if [[ -d /sys/module/$MOD_NAME ]]; then
    modprobe -r "$MOD_NAME" && ok "Unloaded ${MOD_NAME}" || fail "Couldn't unload ${MOD_NAME}"
fi

# Same as install.sh / fnkeys-fix-book5: suspend DKMS's post_transaction
# initramfs rebuild (Fedora runs dracut --regenerate-all there) for this
# script's DKMS steps - galaxybook_fan is never in the initramfs. The trap
# removes the drop-in again even if the script fails.
DKMS_DEFER_CONF="/etc/dkms/framework.conf.d/zz-${PKG_NAME}-defer-initramfs.conf"
trap 'rm -f "$DKMS_DEFER_CONF"' EXIT
if grep -qs '^[[:space:]]*post_transaction=' /etc/dkms/framework.conf \
        || grep -rqs '^[[:space:]]*post_transaction=' /etc/dkms/framework.conf.d/; then
    mkdir -p "$(dirname "$DKMS_DEFER_CONF")"
    echo 'post_transaction=""' > "$DKMS_DEFER_CONF"
fi

if [[ -d /var/lib/dkms/$PKG_NAME ]]; then
    # Remove every registered version in the module/version form current DKMS expects
    for d in /var/lib/dkms/"$PKG_NAME"/*/; do
        v="$(basename "$d")"
        [[ -L "${d%/}" || "$v" == kernel-* || "$v" == "source" || "$v" == "*" ]] && continue
        info "Removing ${PKG_NAME}/${v} from DKMS"
        dkms remove "${PKG_NAME}/${v}" --all || true
    done
    rm -rf /var/lib/dkms/"$PKG_NAME"
    ok "Removed from DKMS"
fi
rm -rf /usr/src/"${PKG_NAME}"-* && ok "Removed source from /usr/src"

for f in "$MODLOAD_CONF" "$MODPROBE_CONF" "$DKMS_SIGN_CONF" "/etc/dracut.conf.d/${PKG_NAME}.conf"; do
    [[ -f "$f" ]] && rm -f "$f" && ok "Removed ${f}"
done

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
rm -rf "$PARSER_DIR"
rmdir /usr/local/lib/samsung-galaxybook 2>/dev/null || true
rm -f /var/lib/samsung-galaxybook/fan-state /run/samsung-galaxybook/fan-status
systemctl daemon-reload
[[ $removed_monitor -eq 1 ]] && ok "Removed the login check (timer, monitor service, polkit rule)"

# Shared graphical session helper - only if this fix registered for it, and
# only removed when no other fix still uses it
SESSION_HELPER_USERS="/etc/samsung-galaxybook/session-helper.d"
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
