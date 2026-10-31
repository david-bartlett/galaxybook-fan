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
for _f in fanpaths.sh fan-dkms.sh clone-remove.sh; do
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

# The removal steps are shared with the packages, which run them when they're
# installed over a copy made by install.sh (lib/clone-remove.sh)
trap gbfan_dkms_resume_initramfs EXIT
gbfan_remove_clone || fail "Nothing was removed: unload ${MOD_NAME} first (sudo modprobe -r ${MOD_NAME}), then try again"

echo
ok "Done. Fan speed reporting is back to the stock (broken) acpi-fan driver."
echo
