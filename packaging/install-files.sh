#!/bin/bash
# =============================================================================
# galaxybook-fan - put the package's files in place (rpm, deb and Arch)
# =============================================================================
#   bash packaging/install-files.sh DESTDIR
#
#   DESTDIR   the package's staging root (%{buildroot}, debian/galaxybook-fan,
#             $pkgdir)
#
# Paths come from lib/fanpaths.sh (package layout), unit and script contents
# from packaging/files/ via render.sh - the same files install.sh installs.
# Each format adds only its own extras (systemd presets, docs).
# =============================================================================
set -euo pipefail
umask 022

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"
[[ $# -eq 1 ]] || { echo "Usage: bash $0 DESTDIR" >&2; exit 2; }
D="$1"
GBFAN_LAYOUT=package
# shellcheck source=../lib/fanpaths.sh
. "$REPO/lib/fanpaths.sh"
VERSION=$(tr -d '[:space:]' < "$REPO/VERSION")

put() { install -d "$D$(dirname "$2")"; bash "$HERE/render.sh" package "$1" > "$D$2"; chmod "${3:-644}" "$D$2"; }

# ── Module source for DKMS (no config header: gen-config.sh writes it) ─────────
SRC="/usr/src/${PKG_NAME}-${VERSION}"
install -Dm644 -t "$D$SRC" "$REPO/module/galaxybook_fan.c" "$REPO/module/Makefile" \
    "$REPO/module/dkms.conf" "$REPO/lib/dsdt-fan-config.py" "$REPO/lib/models.sh"
install -Dm755 "$REPO/module/gen-config.sh" "$D$SRC/gen-config.sh"

# ── The library folder, the command and the package's own scripts ─────────────
install -Dm644 -t "$D$GBFAN_LIBDIR" "$REPO/lib/fanpaths.sh" "$REPO/lib/models.sh" \
    "$REPO/lib/fan-dkms.sh" "$REPO/lib/clone-remove.sh" "$REPO/lib/update.sh" "$REPO/lib/dsdt-fan-config.py" "$REPO/VERSION"
install -Dm755 -t "$D$GBFAN_LIBDIR" "$REPO/lib/samsung-galaxybook-fan-check.sh" \
    "$REPO/lib/galaxybook-fan" "$REPO/lib/package-scripts.sh" "$REPO/lib/update-check.sh" \
    "$REPO/lib/notify-update.sh" "$REPO/lib/notify-dbus.py" "$REPO/lib/update-in-terminal.sh"
bash "$REPO/tools/build-check-script.sh" "$D$GBFAN_LIBDIR/check-galaxybook-fan.sh" "$VERSION" >/dev/null
install -d "$D$(dirname "$GBFAN_CMD")"
ln -sfn "$GBFAN_LIBDIR/galaxybook-fan" "$D$GBFAN_CMD"

# ── Units, login check, session helper, polkit, dracut, autoload ──────────────
put unbind.service.in             "$UNBIND_SERVICE"
put monitor.service.in            "$SYSTEM_UNIT_DIR/$MONITOR_SVC"
put user-check.sh.in              "$USER_CHECK_SCRIPT" 755
put user-check.service.in         "$USER_UNIT_DIR/$USER_CHECK_SVC"
put user-check.timer.in           "$USER_UNIT_DIR/$USER_CHECK_TIMER"
put update-check.service.in       "$USER_UNIT_DIR/$UPDATE_CHECK_SVC"
put update-check.timer.in         "$USER_UNIT_DIR/$UPDATE_CHECK_TIMER"
put polkit-monitor.rules.in       "$POLKIT_RULE"
# Starts graphical-session.target on desktops that don't (Xfce), so the login
# check runs there too; does nothing on KDE Plasma and GNOME.
put session-start.sh.in           "$SESSION_HELPER_SCRIPT" 755
put session.target.in             "$SESSION_HELPER_TARGET"
put session-autostart.desktop.in  "$SESSION_HELPER_AUTOSTART"
put dracut.conf.in                "$DRACUT_CONF"
put modules-load.conf.in          "$MODLOAD_CONF"
