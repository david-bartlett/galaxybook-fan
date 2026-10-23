#!/bin/bash
# ============================================================================
# galaxybook-fan - uninstall
#
# Removes the DKMS module, its autoload/options files, the acpi-fan unbind
# udev rule and the DKMS signing drop-in (if install.sh created it), then
# rebinds the stock acpi-fan driver.
#
# Usage: sudo ./uninstall.sh
# ============================================================================
set -uo pipefail

PKG_NAME="galaxybook-fan"
MOD_NAME="galaxybook_fan"
MODLOAD_CONF="/etc/modules-load.d/${MOD_NAME}.conf"
MODPROBE_CONF="/etc/modprobe.d/${MOD_NAME}.conf"
UDEV_RULE="/etc/udev/rules.d/90-galaxybook-acpi-fan-unbind.rules"
DKMS_SIGN_CONF="/etc/dkms/framework.conf.d/${PKG_NAME}-signing.conf"
ACPI_FAN_DRV="/sys/bus/platform/drivers/acpi-fan"

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

if lsmod | grep -q "^${MOD_NAME} "; then
    modprobe -r "$MOD_NAME" && ok "Unloaded ${MOD_NAME}" || fail "Couldn't unload ${MOD_NAME}"
fi

if command -v dkms >/dev/null 2>&1 && dkms status -m "$PKG_NAME" 2>/dev/null | grep -q .; then
    dkms remove -m "$PKG_NAME" --all >/dev/null 2>&1 && ok "Removed from DKMS"
fi
rm -rf /usr/src/"${PKG_NAME}"-* && ok "Removed source from /usr/src"

for f in "$MODLOAD_CONF" "$MODPROBE_CONF" "$DKMS_SIGN_CONF"; do
    [[ -f "$f" ]] && rm -f "$f" && ok "Removed ${f}"
done

if [[ -f "$UDEV_RULE" ]]; then
    rm -f "$UDEV_RULE"
    udevadm control --reload
    ok "Removed ${UDEV_RULE}"
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
