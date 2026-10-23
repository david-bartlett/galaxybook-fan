#!/bin/bash
# ============================================================================
# galaxybook-fan - install
#
# Fan speed reporting for Samsung Galaxy Book laptops via a small DKMS hwmon
# module that reads the fan level straight from the Embedded Controller.
#
# Replaces fanspeed-fix-cpio: no DSDT override, nothing added to the boot
# chain. Also unbinds the stock acpi-fan driver from the fan device, because
# Samsung's _FST method is broken (missing DerefOf) and acpi-fan only ever
# produces I/O errors, AML errors in dmesg and a dead "Fan 0" in monitors.
#
# The EC location and RPM table aren't hardcoded: they're derived from this
# machine's own DSDT (dsdt-fan-config.py), validated, and baked into the
# module's config header. The module also refuses to load if the DSDT later
# changes (BIOS update) until this installer has been re-run.
#
# It also installs a login-time check (the same pattern as fingerprint-fix
# and fnkeys-fix-book5): after a kernel or BIOS update it tests whether the
# fix is still needed and notifies you if not, or if it needs re-running.
#
# Usage: sudo ./install.sh [--check] [--test-native] [--force]
#   --check         derive and show the fan config from the DSDT, install nothing
#   --test-native   test whether the stock acpi-fan driver now works by itself
#   --force         install on a model that isn't in the confirmed list, or
#                   when the firmware already looks fixed
# ============================================================================
set -uo pipefail

PKG_NAME="galaxybook-fan"
PKG_VERSION="0.2"
MOD_NAME="galaxybook_fan"
SRC_DIR="/usr/src/${PKG_NAME}-${PKG_VERSION}"
MODLOAD_CONF="/etc/modules-load.d/${MOD_NAME}.conf"
MODPROBE_CONF="/etc/modprobe.d/${MOD_NAME}.conf"
UDEV_RULE="/etc/udev/rules.d/90-galaxybook-acpi-fan-unbind.rules"   # old versions only
UNBIND_SERVICE="/etc/systemd/system/galaxybook-acpi-fan-unbind.service"
DKMS_SIGN_CONF="/etc/dkms/framework.conf.d/${PKG_NAME}-signing.conf"

# Login-time "still needed?" check - names follow the other Galaxy Book fixes
CHECK_SCRIPT="/usr/local/bin/samsung-galaxybook-fan-check.sh"
USER_CHECK_SCRIPT="/usr/local/bin/samsung-galaxybook-fan-user-check.sh"
PARSER_DIR="/usr/local/lib/samsung-galaxybook/fan"
MONITOR_SVC="samsung-galaxybook-fan-monitor.service"
USER_CHECK_SVC="samsung-galaxybook-fan-user-check.service"
USER_CHECK_TIMER="samsung-galaxybook-fan-user-check.timer"
POLKIT_RULE="/etc/polkit-1/rules.d/49-samsung-galaxybook-fan-monitor.rules"
SESSION_HELPER_TARGET="/etc/systemd/user/samsung-galaxybook-session.target"
SESSION_HELPER_SCRIPT="/usr/local/bin/samsung-galaxybook-session-start.sh"
SESSION_HELPER_AUTOSTART="/etc/xdg/autostart/samsung-galaxybook-session.desktop"
SESSION_HELPER_USERS="/etc/samsung-galaxybook/session-helper.d"
ACPI_FAN_DRV="/sys/bus/platform/drivers/acpi-fan"

CONFIRMED_MODELS=("940XHA")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORCE=0
CHECK_ONLY=0
TEST_NATIVE=0
WORK_DIR=""

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        --check) CHECK_ONLY=1 ;;
        --test-native) TEST_NATIVE=1 ;;
        -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) fail "Unknown option: $arg" ;;
    esac
done

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root: sudo ./install.sh"
    exit 1
fi

echo
echo "=============================================="
echo "  Samsung Galaxy Book fan speed (DKMS) - install"
echo "=============================================="
echo

# ---------------------------------------------------------------------------
# Distro detection
# ---------------------------------------------------------------------------
check_distro() {
    # shellcheck disable=SC1091
    source /etc/os-release
    local id="${ID:-}" like="${ID_LIKE:-}"
    if command -v dnf >/dev/null 2>&1; then
        PKG_MGR="dnf"
    elif command -v apt-get >/dev/null 2>&1; then
        PKG_MGR="apt"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MGR="pacman"
    else
        fail "Unsupported distro (${id} ${like}): need dnf, apt or pacman"
    fi
    info "Distro: ${PRETTY_NAME:-$id} (${PKG_MGR})"
}

# ---------------------------------------------------------------------------
# Model check
# ---------------------------------------------------------------------------
check_model() {
    local vendor product
    vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
    product="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"

    if [[ "$vendor" != *SAMSUNG* ]]; then
        fail "Not a Samsung laptop (vendor: '${vendor}')"
    fi

    [[ -n "$product" ]] || fail "Couldn't read the DMI product name"
    PRODUCT="$product"
    CONFIRMED=0
    for m in "${CONFIRMED_MODELS[@]}"; do
        [[ "$product" == *"$m"* ]] && CONFIRMED=1
    done
    if [[ $CONFIRMED -eq 1 ]]; then
        ok "Model: ${product} (confirmed)"
    else
        warn "Model: ${product} (not confirmed - the DSDT check below decides whether it can work)"
    fi
}

# ---------------------------------------------------------------------------
# Refuse if the CPIO / DSDT override fix is still active
# ---------------------------------------------------------------------------
check_cpio_fix() {
    # Capture first: piping into grep -q can SIGPIPE the writer, which fails
    # the whole test under pipefail even when grep matched.
    local log
    log="$(dmesg 2>/dev/null || true)"
    if [[ "$log" == *"dsdt_fixed.aml"* ]]; then
        fail "fanspeed-fix-cpio (DSDT override) is active. Uninstall it and reboot first, otherwise you'll get two fan sensors"
    fi
    if [[ -f /boot/samsung-galaxybook-acpi.img ]]; then
        warn "/boot/samsung-galaxybook-acpi.img exists but isn't loaded this boot - consider uninstalling fanspeed-fix-cpio"
    fi
    ok "No DSDT override active"
}

# ---------------------------------------------------------------------------
# Tools to read the DSDT: iasl (acpica) and python3
# ---------------------------------------------------------------------------
ensure_parse_tools() {
    local pkgs=()
    case "$PKG_MGR" in
        dnf)    command -v iasl >/dev/null 2>&1 || pkgs+=(acpica-tools)
                command -v python3 >/dev/null 2>&1 || pkgs+=(python3) ;;
        apt)    command -v iasl >/dev/null 2>&1 || pkgs+=(acpica-tools)
                command -v python3 >/dev/null 2>&1 || pkgs+=(python3) ;;
        pacman) command -v iasl >/dev/null 2>&1 || pkgs+=(acpica)
                command -v python3 >/dev/null 2>&1 || pkgs+=(python) ;;
    esac
    if [[ ${#pkgs[@]} -gt 0 ]]; then
        info "Installing: ${pkgs[*]}"
        case "$PKG_MGR" in
            dnf)    dnf install -y "${pkgs[@]}" ;;
            apt)    apt-get update -qq && apt-get install -y "${pkgs[@]}" ;;
            pacman) pacman -S --needed --noconfirm "${pkgs[@]}" ;;
        esac || fail "Package install failed"
    fi
    command -v iasl >/dev/null 2>&1 || fail "iasl not found after install"
    command -v python3 >/dev/null 2>&1 || fail "python3 not found after install"
}

# ---------------------------------------------------------------------------
# Derive the EC location and RPM table from this machine's DSDT
# ---------------------------------------------------------------------------
cleanup() { [[ -n "$WORK_DIR" ]] && rm -rf "$WORK_DIR"; }
trap cleanup EXIT

derive_config() {
    local dsdt=/sys/firmware/acpi/tables/DSDT summary rc
    [[ -r "$dsdt" ]] || fail "Can't read ${dsdt}"
    [[ -f "$SCRIPT_DIR/dsdt-fan-config.py" ]] || fail "dsdt-fan-config.py missing from ${SCRIPT_DIR}"

    WORK_DIR="$(mktemp -d)" || fail "mktemp failed"
    cp "$dsdt" "$WORK_DIR/dsdt.dat" || fail "Couldn't copy the DSDT"
    info "Disassembling the DSDT"
    if ! (cd "$WORK_DIR" && iasl -d dsdt.dat >iasl.log 2>&1) || [[ ! -s "$WORK_DIR/dsdt.dsl" ]]; then
        tail -5 "$WORK_DIR/iasl.log" >&2
        fail "iasl couldn't disassemble the DSDT"
    fi

    summary="$(python3 -I "$SCRIPT_DIR/dsdt-fan-config.py" \
        --dsl "$WORK_DIR/dsdt.dsl" --product "$PRODUCT" \
        --out "$WORK_DIR/galaxybook_fan_config.h" 2>&1)"
    rc=$?
    if [[ $rc -ne 0 ]]; then
        echo "$summary" | sed 's/^/        /' >&2
        cp "$WORK_DIR/dsdt.dsl" /tmp/galaxybook-fan-dsdt.dsl 2>/dev/null \
            && warn "Disassembled DSDT saved to /tmp/galaxybook-fan-dsdt.dsl for inspection"
        fail "This firmware's fan method doesn't match the shape galaxybook-fan supports - nothing installed"
    fi
    ok "Fan config derived from this machine's DSDT:"
    echo "$summary" | sed 's/^/        /'
    EXPECTED_SPEEDS="$(echo "$summary" | sed -n 's/^Speeds: *//p')"

    if [[ "$summary" == *"fix not needed"* ]]; then
        warn "This firmware's _FST already dereferences its table correctly, so the stock"
        warn "acpi-fan driver should report fan speed without this fix."
        warn "Check with: sudo ./install.sh --test-native"
        if [[ $CHECK_ONLY -eq 0 && $FORCE -eq 0 ]]; then
            fail "Not installed (use --force to install anyway)"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Dependencies: dkms, make, gcc, headers for the running kernel, and
# notify-send for the login check (libnotify-bin isn't always on Debian)
# ---------------------------------------------------------------------------
install_deps() {
    local kver pkgs=()
    kver="$(uname -r)"

    case "$PKG_MGR" in
        dnf)
            command -v dkms >/dev/null 2>&1 || pkgs+=(dkms)
            command -v make >/dev/null 2>&1 || pkgs+=(make)
            command -v gcc  >/dev/null 2>&1 || pkgs+=(gcc)
            [[ -d /usr/src/kernels/${kver} ]] || pkgs+=("kernel-devel-${kver}")
            rpm -q dwarves >/dev/null 2>&1 || pkgs+=(dwarves)
            command -v notify-send >/dev/null 2>&1 || pkgs+=(libnotify)
            if [[ ${#pkgs[@]} -gt 0 ]]; then
                info "Installing: ${pkgs[*]}"
                dnf install -y "${pkgs[@]}" || fail "Package install failed"
            fi
            ;;
        apt)
            command -v dkms >/dev/null 2>&1 || pkgs+=(dkms)
            command -v make >/dev/null 2>&1 || pkgs+=(make)
            command -v gcc  >/dev/null 2>&1 || pkgs+=(gcc)
            [[ -d /lib/modules/${kver}/build ]] || pkgs+=("linux-headers-${kver}")
            command -v notify-send >/dev/null 2>&1 || pkgs+=(libnotify-bin)
            if [[ ${#pkgs[@]} -gt 0 ]]; then
                info "Installing: ${pkgs[*]}"
                apt-get update -qq
                apt-get install -y "${pkgs[@]}" || fail "Package install failed"
            fi
            ;;
        pacman)
            command -v dkms >/dev/null 2>&1 || pkgs+=(dkms)
            command -v make >/dev/null 2>&1 || pkgs+=(make)
            command -v gcc  >/dev/null 2>&1 || pkgs+=(gcc)
            command -v notify-send >/dev/null 2>&1 || pkgs+=(libnotify)
            if [[ ! -d /lib/modules/${kver}/build ]]; then
                local kpkg
                kpkg="$(pacman -Qqo "/usr/lib/modules/${kver}/vmlinuz" 2>/dev/null || true)"
                [[ -n "$kpkg" ]] && pkgs+=("${kpkg}-headers") || warn "Couldn't work out the headers package for ${kver}"
            fi
            if [[ ${#pkgs[@]} -gt 0 ]]; then
                info "Installing: ${pkgs[*]}"
                pacman -S --needed --noconfirm "${pkgs[@]}" || fail "Package install failed"
            fi
            ;;
    esac

    [[ -d /lib/modules/${kver}/build ]] || fail "Kernel headers for ${kver} not found"
    command -v notify-send >/dev/null 2>&1 \
        || warn "notify-send still missing - login-check messages will only go to the journal"
    ok "Build dependencies present"
}

# ---------------------------------------------------------------------------
# Module signing (Secure Boot)
# Pick whichever MOK key is actually enrolled and point DKMS at it.
# ---------------------------------------------------------------------------
is_enrolled() {
    # mokutil --test-key prints "... is already enrolled" for an enrolled key,
    # but exits 1 in that case - so capture the output rather than piping it
    # (a pipe would fail under pipefail even when grep matches).
    local out
    [[ -f "$1" ]] || return 1
    out="$(mokutil --test-key "$1" 2>&1 || true)"
    [[ "$out" == *"already enrolled"* ]]
}

setup_signing() {
    local sb=""
    command -v mokutil >/dev/null 2>&1 && sb="$(mokutil --sb-state 2>/dev/null || true)"
    if [[ "$sb" != *"SecureBoot enabled"* ]]; then
        info "Secure Boot is off - module signing not needed"
        return
    fi
    info "Secure Boot is on - checking for an enrolled signing key"

    # Already configured by the user / another fix?
    local cur_key="" cur_cert=""
    if [[ -f /etc/dkms/framework.conf ]]; then
        cur_key="$(grep -E '^\s*mok_signing_key=' /etc/dkms/framework.conf | tail -1 | cut -d= -f2- | tr -d '"' || true)"
        cur_cert="$(grep -E '^\s*mok_certificate=' /etc/dkms/framework.conf | tail -1 | cut -d= -f2- | tr -d '"' || true)"
    fi
    if [[ -n "$cur_key" && -n "$cur_cert" ]] && is_enrolled "$cur_cert"; then
        ok "DKMS already signs with an enrolled key (${cur_cert})"
        return
    fi

    # Candidate key pairs: cert|key
    local candidates=(
        "/var/lib/dkms/mok.pub|/var/lib/dkms/mok.key"
        "/etc/pki/akmods/certs/public_key.der|/etc/pki/akmods/private/private_key.priv"
        "/var/lib/shim-signed/mok/MOK.der|/var/lib/shim-signed/mok/MOK.priv"
    )
    local c cert key
    for c in "${candidates[@]}"; do
        cert="${c%%|*}"; key="${c##*|}"
        if is_enrolled "$cert" && [[ -f "$key" ]]; then
            if [[ "$cert" == "/var/lib/dkms/mok.pub" ]]; then
                ok "DKMS default key is enrolled - nothing to configure"
                return
            fi
            mkdir -p /etc/dkms/framework.conf.d
            cat > "$DKMS_SIGN_CONF" <<EOF
# Written by ${PKG_NAME} install.sh - points DKMS at the enrolled MOK key.
# Removed by ${PKG_NAME} uninstall.sh.
mok_signing_key="${key}"
mok_certificate="${cert}"
EOF
            ok "DKMS will sign with ${cert}"
            return
        fi
    done

    warn "No enrolled MOK key found that DKMS can use."
    warn "Enroll one, reboot through MokManager, then re-run this installer. On Fedora, for example:"
    warn "  sudo mokutil --import /etc/pki/akmods/certs/public_key.der   (run 'sudo kmodgenca' first if it doesn't exist)"
    fail "Can't load an unsigned module with Secure Boot on"
}

# ---------------------------------------------------------------------------
# DKMS build + install
# ---------------------------------------------------------------------------
dkms_remove_all() {
    # Every registered version, removed in the module/version form current
    # DKMS expects. /var/lib/dkms/<pkg>/<version> holds one dir per version.
    local d v
    for d in /var/lib/dkms/"$PKG_NAME"/*/; do
        v="$(basename "$d")"
        [[ -L "${d%/}" || "$v" == kernel-* || "$v" == "source" || "$v" == "*" ]] && continue
        info "Removing ${PKG_NAME}/${v} from DKMS (DKMS may rebuild the initramfs - this can take a minute)"
        dkms remove "${PKG_NAME}/${v}" --all || true
    done
    # Anything DKMS couldn't remove (half-added tree, etc.)
    rm -rf /var/lib/dkms/"$PKG_NAME"
}

install_module() {
    # Remove any previous registration of this package (any version)
    if [[ -d /var/lib/dkms/$PKG_NAME ]]; then
        info "Removing previous ${PKG_NAME} DKMS install"
        modprobe -r "$MOD_NAME" 2>/dev/null || true
        dkms_remove_all
    fi
    rm -rf /usr/src/"${PKG_NAME}"-*

    mkdir -p "$SRC_DIR"
    cp "$SCRIPT_DIR"/galaxybook_fan.c "$SCRIPT_DIR"/Makefile "$SCRIPT_DIR"/dkms.conf "$SRC_DIR"/ \
        || fail "Couldn't copy module source to ${SRC_DIR}"
    # The machine-specific config replaces the repo's 940XHA default
    cp "$WORK_DIR/galaxybook_fan_config.h" "$SRC_DIR"/ \
        || fail "Couldn't copy the generated config to ${SRC_DIR}"

    info "Building with DKMS (this takes a few seconds)"
    dkms add -m "$PKG_NAME" -v "$PKG_VERSION" >/dev/null || fail "dkms add failed"
    if ! dkms install -m "$PKG_NAME" -v "$PKG_VERSION"; then
        fail "dkms install failed - see /var/lib/dkms/${PKG_NAME}/${PKG_VERSION}/build/make.log"
    fi
    ok "DKMS module installed for $(uname -r) (rebuilds automatically on kernel updates)"

    echo "$MOD_NAME" > "$MODLOAD_CONF"
    ok "Autoload: ${MODLOAD_CONF}"

    # Earlier versions set force=1 here; the config now matches this machine
    [[ -f "$MODPROBE_CONF" ]] && rm -f "$MODPROBE_CONF" && info "Removed old ${MODPROBE_CONF}"
}

# ---------------------------------------------------------------------------
# Unbind stock acpi-fan from the fan device.
# acpi-fan is built in on most distros (so it can't be blacklisted) and binds
# before udevd starts; udev RUN programs also get a read-only /sys, so a udev
# rule can't do the unbind. A oneshot systemd service early in boot can.
# ---------------------------------------------------------------------------
install_unbind() {
    # Remove the udev rule from earlier versions of this installer
    if [[ -f "$UDEV_RULE" ]]; then
        rm -f "$UDEV_RULE"
        udevadm control --reload
        ok "Removed old udev rule ${UDEV_RULE}"
    fi

    cat > "$UNBIND_SERVICE" <<'EOF'
# Written by galaxybook-fan install.sh.
# Samsung's FAN0._FST is broken (Index without DerefOf), so the stock acpi-fan
# driver only produces AML errors and a dead fan sensor. galaxybook_fan reads
# the EC directly instead. The fan has no ACPI control (_FPS/_FSL), so the
# cooling device acpi-fan registers does nothing - unbinding it loses nothing.
[Unit]
Description=Unbind acpi-fan from Samsung Galaxy Book fan (broken _FST)
DefaultDependencies=no
Before=sysinit.target
ConditionPathIsDirectory=/sys/bus/platform/drivers/acpi-fan

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'for d in /sys/bus/platform/drivers/acpi-fan/PNP0C0B:*; do [ -e "$$d" ] && echo "$${d##*/}" > /sys/bus/platform/drivers/acpi-fan/unbind; done; true'

[Install]
WantedBy=sysinit.target
EOF
    systemctl daemon-reload
    systemctl enable "$(basename "$UNBIND_SERVICE")" >/dev/null 2>&1 \
        || fail "Couldn't enable $(basename "$UNBIND_SERVICE")"
    ok "Boot-time unbind: $(basename "$UNBIND_SERVICE") (enabled)"

    local dev
    for dev in "$ACPI_FAN_DRV"/PNP0C0B:*; do
        [[ -e "$dev" ]] || continue
        echo "$(basename "$dev")" > "$ACPI_FAN_DRV/unbind" 2>/dev/null \
            && ok "Unbound acpi-fan from $(basename "$dev")"
    done
}

# ---------------------------------------------------------------------------
# Login-time check: is the fix still needed / still active?
# Same pattern as fingerprint-fix and fnkeys-fix-book5: a user timer fires
# 10s after login; if the kernel or BIOS version changed (or the module isn't
# loaded) it starts a root monitor service (allowed by a polkit rule), which
# writes a notification to /run for the user script to show with notify-send.
# ---------------------------------------------------------------------------
install_session_helper() {
    cat > "$SESSION_HELPER_TARGET" << 'SESSTARGETEOF'
[Unit]
Description=Samsung Galaxy Book — graphical session (desktops without systemd session support)
# Started at login by samsung-galaxybook-session-start.sh. Binding to
# graphical-session.target activates it, so units WantedBy= it start as they
# do on KDE Plasma and GNOME.
BindsTo=graphical-session.target
Wants=graphical-session-pre.target
After=graphical-session-pre.target
SESSTARGETEOF
    chmod 644 "$SESSION_HELPER_TARGET"

    cat > "$SESSION_HELPER_SCRIPT" << 'SESSSCRIPTEOF'
#!/bin/bash
# Samsung Galaxy Book — start graphical-session.target on desktops that don't.
# Run from XDG autostart at login. Does nothing if the desktop has already
# started the target itself (KDE Plasma, GNOME).
systemctl --user is-active --quiet graphical-session.target && exit 0
# Pass the session's display variables to the systemd user manager first, so
# services that show notifications or tray icons can reach the desktop.
if command -v dbus-update-activation-environment >/dev/null 2>&1; then
    dbus-update-activation-environment --systemd --all
else
    systemctl --user import-environment DISPLAY XAUTHORITY WAYLAND_DISPLAY \
        XDG_CURRENT_DESKTOP XDG_SESSION_TYPE 2>/dev/null
fi
systemctl --user start samsung-galaxybook-session.target
SESSSCRIPTEOF
    chmod 755 "$SESSION_HELPER_SCRIPT"

    mkdir -p "$(dirname "$SESSION_HELPER_AUTOSTART")"
    cat > "$SESSION_HELPER_AUTOSTART" << SESSDESKTOPEOF
[Desktop Entry]
Type=Application
Name=Samsung Galaxy Book session helper
Comment=Starts systemd graphical-session.target on desktops that do not
Exec=${SESSION_HELPER_SCRIPT}
NoDisplay=true
X-GNOME-Autostart-enabled=true
SESSDESKTOPEOF
    chmod 644 "$SESSION_HELPER_AUTOSTART"

    mkdir -p "$SESSION_HELPER_USERS"
    touch "$SESSION_HELPER_USERS/galaxybook-fan"
}

install_monitor() {
    install -m 755 -o root -g root "$SCRIPT_DIR/samsung-galaxybook-fan-check.sh" "$CHECK_SCRIPT" \
        || fail "Couldn't install ${CHECK_SCRIPT}"
    mkdir -p "$PARSER_DIR"
    install -m 644 -o root -g root "$SCRIPT_DIR/dsdt-fan-config.py" "$PARSER_DIR/" \
        || fail "Couldn't install the DSDT parser to ${PARSER_DIR}"

    cat > "/etc/systemd/system/${MONITOR_SVC}" <<EOF
[Unit]
Description=Samsung Galaxy Book — fan speed fix monitor

[Service]
Type=oneshot
ExecStart=${CHECK_SCRIPT} --monitor
RemainAfterExit=no
StandardOutput=journal
StandardError=journal
EOF
    systemctl daemon-reload

    cat > "$POLKIT_RULE" <<'EOF'
polkit.addRule(function(action, subject) {
    if (action.id == "org.freedesktop.systemd1.manage-units" &&
        action.lookup("unit") == "samsung-galaxybook-fan-monitor.service" &&
        action.lookup("verb") == "start" &&
        (subject.isInGroup("wheel") || subject.isInGroup("sudo"))) {
        return polkit.Result.YES;
    }
});
EOF
    chmod 644 "$POLKIT_RULE"

    cat > "$USER_CHECK_SCRIPT" <<'EOF'
#!/bin/bash
# Samsung Galaxy Book — fan speed fix user check (runs as user)
# Started by samsung-galaxybook-fan-user-check.timer 10 seconds after
# graphical-session.target is reached, so the desktop and notify-send are ready.
# Starts the root monitor only when something changed that it should look at.
STATE_FILE="/var/lib/samsung-galaxybook/fan-state"
STATUS_FILE="/run/samsung-galaxybook/fan-status"

[[ -f /etc/modules-load.d/galaxybook_fan.conf ]] || exit 0

KVER="" BIOS=""
[[ -f "$STATE_FILE" ]] && { KVER="$(sed -n 's/^KVER=//p' "$STATE_FILE")"; BIOS="$(sed -n 's/^BIOS=//p' "$STATE_FILE")"; }
CUR_BIOS="$(cat /sys/class/dmi/id/bios_version 2>/dev/null)"

if [[ "$(uname -r)" == "$KVER" && "$CUR_BIOS" == "$BIOS" && -d /sys/module/galaxybook_fan ]]; then
    exit 0
fi

# Type=oneshot: returns once the monitor has finished writing its status
systemctl start samsung-galaxybook-fan-monitor.service || exit 0

[[ -s "$STATUS_FILE" ]] || exit 0
{ IFS= read -r ICON; IFS= read -r TITLE; IFS= read -r MSG; } < "$STATUS_FILE"
[[ -n "$TITLE" ]] || exit 0

notify-send -t 0 -a "Samsung Galaxy Book Fixes" -i "${ICON:-dialog-information}" "$TITLE" "$MSG" \
    || logger -t samsung-galaxybook-fan-user-check "notify-send failed: $TITLE: $MSG"
EOF
    chown root:root "$USER_CHECK_SCRIPT"
    chmod 755 "$USER_CHECK_SCRIPT"
    ok "Monitor: ${MONITOR_SVC} + polkit rule"

    # Record the kernel/BIOS this install was made for
    "$CHECK_SCRIPT" --record-state "$SCRIPT_DIR" || warn "Couldn't record the install state"

    # User timer for the logged-in user
    local user uid udir
    user="$(loginctl list-sessions --no-legend 2>/dev/null | awk '$4 == "seat0" {print $3}' | head -1)"
    uid="$(id -u "$user" 2>/dev/null)"
    if [[ -z "$user" || -z "$uid" ]]; then
        warn "Could not detect the logged-in user - skipping the login check timer"
        return
    fi
    udir="$(getent passwd "$user" | cut -d: -f6)/.config/systemd/user"

    _fan_user_systemctl() {
        sudo -u "$user" \
            XDG_RUNTIME_DIR="/run/user/${uid}" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus" \
            systemctl --user "$@"
    }

    mkdir -p "$udir"
    cat > "${udir}/${USER_CHECK_SVC}" <<EOF
[Unit]
Description=Samsung Galaxy Book — fan speed fix login check
# Started by ${USER_CHECK_TIMER}; no [Install] section on purpose.

[Service]
Type=oneshot
ExecStart=${USER_CHECK_SCRIPT}
RemainAfterExit=no
EOF
    cat > "${udir}/${USER_CHECK_TIMER}" <<EOF
[Unit]
Description=Samsung Galaxy Book — fan speed fix login check (10s after login)
# PartOf stops the timer at logout so it re-arms on the next login.
PartOf=graphical-session.target
After=graphical-session.target
DefaultDependencies=no

[Timer]
OnActiveSec=10
AccuracySec=1s
Unit=${USER_CHECK_SVC}

[Install]
WantedBy=graphical-session.target
EOF
    chown -R "${user}:$(id -gn "$user")" "$(dirname "$udir")"
    _fan_user_systemctl daemon-reload 2>/dev/null || true
    _fan_user_systemctl enable "${USER_CHECK_TIMER}" >/dev/null 2>&1 \
        && ok "Login check timer enabled for ${user}" \
        || warn "systemctl --user enable failed for ${USER_CHECK_TIMER}"

    # Desktops that don't start graphical-session.target (e.g. Xfce) need the
    # shared helper, or the timer is enabled but never runs.
    if [[ -f "$SESSION_HELPER_TARGET" ]] \
            || ! _fan_user_systemctl is-active --quiet graphical-session.target; then
        install_session_helper
        _fan_user_systemctl daemon-reload 2>/dev/null || true
        ok "Graphical session helper installed - the login check will run at login"
    fi
}

# ---------------------------------------------------------------------------
# Load and verify
# ---------------------------------------------------------------------------
verify() {
    modprobe "$MOD_NAME" || fail "modprobe ${MOD_NAME} failed - check 'dmesg | tail'"

    local h name rpm=""
    for h in /sys/class/hwmon/hwmon*; do
        name="$(cat "$h/name" 2>/dev/null || true)"
        if [[ "$name" == "$MOD_NAME" ]]; then
            rpm="$(cat "$h/fan1_input" 2>/dev/null || echo "read error")"
            break
        fi
    done

    if [[ -z "$rpm" ]]; then
        fail "Module loaded but no ${MOD_NAME} hwmon device appeared - check 'dmesg | grep galaxybook_fan'"
    elif [[ "$rpm" == "read error" ]]; then
        warn "hwmon device present but fan1_input returned an error - EC level out of range?"
    else
        ok "Fan speed: ${rpm} RPM"
    fi
}

check_distro

if [[ $TEST_NATIVE -eq 1 ]]; then
    [[ -x "$SCRIPT_DIR/samsung-galaxybook-fan-check.sh" ]] || chmod +x "$SCRIPT_DIR/samsung-galaxybook-fan-check.sh"
    info "Testing whether the stock acpi-fan driver can read the fan by itself."
    if [[ -d /sys/module/$MOD_NAME ]]; then
        info "The test needs the fan spinning - waiting up to 2 minutes."
        info "If it's quiet, load the CPU in another terminal, e.g.: stress-ng --cpu 8 --timeout 90"
    fi
    case "$("$SCRIPT_DIR/samsung-galaxybook-fan-check.sh" --test-native --wait 120)" in
        works)     ok "The stock driver reads the fan speed - this fix is no longer needed (sudo ./uninstall.sh)" ;;
        broken)    ok "The stock driver still can't read the fan speed - keep this fix" ;;
        fan-off)   warn "The fan wasn't spinning, so the test proved nothing - load the CPU and try again" ;;
        no-device) warn "No ACPI fan device or acpi-fan driver found" ;;
        *)         fail "Native test failed to run" ;;
    esac
    exit 0
fi

check_model
check_cpio_fix
ensure_parse_tools
derive_config

if [[ $CHECK_ONLY -eq 1 ]]; then
    echo
    ok "Check only - nothing installed."
    echo
    exit 0
fi

if [[ $CONFIRMED -eq 0 && $FORCE -eq 0 ]]; then
    warn "The DSDT check passed, but ${PRODUCT} hasn't been confirmed on real hardware."
    warn "If the speeds above look plausible, re-run with --force to install."
    fail "Not installed"
fi

install_deps
setup_signing
install_module
install_unbind
install_monitor
verify

echo
ok "Done. Check with: sensors   (or Mission Center / System Monitor)"
echo "    Expected values: ${EXPECTED_SPEEDS:-see above}"
echo "    After a BIOS update, re-run this installer - the module won't load until you do."
echo
