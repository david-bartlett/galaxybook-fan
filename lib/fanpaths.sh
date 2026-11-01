# shellcheck shell=bash disable=SC2034  # the scripts that source this file use these
# =============================================================================
# galaxybook-fan - names and paths, shared by install.sh, uninstall.sh, the
# galaxybook-fan command and the login check, so they always agree.
#
# Two layouts (PLAN.md §10):
#   clone    installed by install.sh from a clone or the release's source code:
#            scripts in /usr/local, as before
#   package  installed by the rpm / deb / Arch package: everything under /usr
# GBFAN_LAYOUT picks one; without it, a copy of this file inside the package's
# folder means "package", anything else means "clone".
# =============================================================================

PKG_NAME="galaxybook-fan"
MOD_NAME="galaxybook_fan"

if [[ -z "${GBFAN_LAYOUT:-}" ]]; then
    case "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" in
        /usr/lib/galaxybook-fan) GBFAN_LAYOUT=package ;;
        *)                       GBFAN_LAYOUT=clone ;;
    esac
fi

if [[ "$GBFAN_LAYOUT" == package ]]; then
    GBFAN_LIBDIR="/usr/lib/galaxybook-fan"
    GBFAN_CMD="/usr/bin/galaxybook-fan"
    CHECK_SCRIPT="$GBFAN_LIBDIR/samsung-galaxybook-fan-check.sh"
    USER_CHECK_SCRIPT="$GBFAN_LIBDIR/samsung-galaxybook-fan-user-check.sh"
    SYSTEM_UNIT_DIR="/usr/lib/systemd/system"
    USER_UNIT_DIR="/usr/lib/systemd/user"           # enabled for every user (systemctl --global)
    POLKIT_RULE="/usr/share/polkit-1/rules.d/49-samsung-galaxybook-fan-monitor.rules"
    DRACUT_CONF="/usr/lib/dracut/dracut.conf.d/galaxybook-fan.conf"
    # Its own session helper, so it never owns a file another package
    # (fingerprint-fix-sdcp) or a clone install also writes
    SESSION_TARGET_NAME="galaxybook-fan-session.target"
    SESSION_HELPER_TARGET="$USER_UNIT_DIR/$SESSION_TARGET_NAME"
    SESSION_HELPER_SCRIPT="$GBFAN_LIBDIR/session-start.sh"
    SESSION_HELPER_AUTOSTART="/etc/xdg/autostart/galaxybook-fan-session.desktop"
    WRITTEN_BY="the galaxybook-fan package"
else
    GBFAN_LIBDIR="/usr/local/lib/samsung-galaxybook/fan"
    GBFAN_CMD="/usr/local/sbin/galaxybook-fan"
    CHECK_SCRIPT="/usr/local/bin/samsung-galaxybook-fan-check.sh"
    USER_CHECK_SCRIPT="/usr/local/bin/samsung-galaxybook-fan-user-check.sh"
    SYSTEM_UNIT_DIR="/etc/systemd/system"
    USER_UNIT_DIR=""                                # install.sh writes into the user's ~/.config/systemd/user
    POLKIT_RULE="/etc/polkit-1/rules.d/49-samsung-galaxybook-fan-monitor.rules"
    DRACUT_CONF="/etc/dracut.conf.d/galaxybook-fan.conf"
    # Shared with the other Galaxy Book fixes' install.sh (session-helper.d)
    SESSION_TARGET_NAME="samsung-galaxybook-session.target"
    SESSION_HELPER_TARGET="/etc/systemd/user/$SESSION_TARGET_NAME"
    SESSION_HELPER_SCRIPT="/usr/local/bin/samsung-galaxybook-session-start.sh"
    SESSION_HELPER_AUTOSTART="/etc/xdg/autostart/samsung-galaxybook-session.desktop"
    WRITTEN_BY="galaxybook-fan install.sh"
fi
# The DSDT parser, model list, this file and the built check script live in
# GBFAN_LIBDIR (the parser used to be in "PARSER_DIR"; same folder for clone).
PARSER_DIR="$GBFAN_LIBDIR"
PARSER="$GBFAN_LIBDIR/dsdt-fan-config.py"

MODLOAD_CONF="/etc/modules-load.d/${MOD_NAME}.conf"
MODPROBE_CONF="/etc/modprobe.d/${MOD_NAME}.conf"                # old versions only
UDEV_RULE="/etc/udev/rules.d/90-galaxybook-acpi-fan-unbind.rules"  # old versions only
UNBIND_SVC="galaxybook-acpi-fan-unbind.service"
UNBIND_SERVICE="$SYSTEM_UNIT_DIR/$UNBIND_SVC"
DKMS_SIGN_CONF="/etc/dkms/framework.conf.d/${PKG_NAME}-signing.conf"
DKMS_DEFER_CONF="/etc/dkms/framework.conf.d/zz-${PKG_NAME}-defer-initramfs.conf"
# Fedora: share the akmods key and DKMS config with Andy's fixes
AKMODS_CERT="/etc/pki/akmods/certs/public_key.der"
AKMODS_KEY="/etc/pki/akmods/private/private_key.priv"
AKMODS_CONF="/etc/dkms/framework.conf.d/akmods-keys.conf"

# install.sh --force (or GALAXYBOOK_FAN_FORCE=1 for a package) leaves this, so
# DKMS's config step (module/gen-config.sh) also builds on later kernels on a
# model that isn't in the Book 5 list, or firmware that already looks fixed
GBFAN_ETC="/etc/galaxybook-fan"
FORCE_FLAG="$GBFAN_ETC/force"
# 'sudo galaxybook-fan updates off' leaves this: no "new version" notifications
UPDATES_OFF="$GBFAN_ETC/no-update-check"
# The "new version" check: a user timer (60 s after login, then hourly) and
# its script in the library folder (lib/update-check.sh)
UPDATE_CHECK_SVC="galaxybook-fan-update-check.service"
UPDATE_CHECK_TIMER="galaxybook-fan-update-check.timer"
UPDATE_CHECK_SCRIPT="$GBFAN_LIBDIR/update-check.sh"

# Login check
MONITOR_SVC="samsung-galaxybook-fan-monitor.service"
USER_CHECK_SVC="samsung-galaxybook-fan-user-check.service"
USER_CHECK_TIMER="samsung-galaxybook-fan-user-check.timer"
STATE_DIR="/var/lib/samsung-galaxybook"
STATE_FILE="${STATE_DIR}/fan-state"
STATUS_DIR="/run/samsung-galaxybook"
STATUS_FILE="${STATUS_DIR}/fan-status"
SESSION_HELPER_USERS="/etc/samsung-galaxybook/session-helper.d"   # clone installs only

ACPI_FAN_DRV="/sys/bus/platform/drivers/acpi-fan"

# Is the galaxybook-fan package installed? (rpm, deb or pacman) - so install.sh
# and the package never both install the fix
gbfan_package_installed() {
    if command -v rpm >/dev/null 2>&1 && rpm -q "$PKG_NAME" >/dev/null 2>&1; then return 0; fi
    if command -v dpkg-query >/dev/null 2>&1 \
        && [[ "$(dpkg-query -W -f='${db:Status-Status}' "$PKG_NAME" 2>/dev/null)" == installed ]]; then return 0; fi
    if command -v pacman >/dev/null 2>&1 && pacman -Q "$PKG_NAME" >/dev/null 2>&1; then return 0; fi
    return 1
}
