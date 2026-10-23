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
# Usage: sudo ./install.sh [--force]
#   --force   install on a model that isn't in the confirmed list
# ============================================================================
set -uo pipefail

PKG_NAME="galaxybook-fan"
PKG_VERSION="0.1"
MOD_NAME="galaxybook_fan"
SRC_DIR="/usr/src/${PKG_NAME}-${PKG_VERSION}"
MODLOAD_CONF="/etc/modules-load.d/${MOD_NAME}.conf"
MODPROBE_CONF="/etc/modprobe.d/${MOD_NAME}.conf"
UDEV_RULE="/etc/udev/rules.d/90-galaxybook-acpi-fan-unbind.rules"
DKMS_SIGN_CONF="/etc/dkms/framework.conf.d/${PKG_NAME}-signing.conf"
ACPI_FAN_DRV="/sys/bus/platform/drivers/acpi-fan"

CONFIRMED_MODELS=("940XHA")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORCE=0

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        -h|--help) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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

    for m in "${CONFIRMED_MODELS[@]}"; do
        if [[ "$product" == *"$m"* ]]; then
            ok "Model: ${product} (confirmed)"
            return
        fi
    done

    if [[ $FORCE -eq 1 ]]; then
        warn "Model ${product} is not confirmed - continuing because of --force"
        warn "The EC offset (0x87) and RPM table come from the 940XHA DSDT; readings may be wrong"
        FORCED_MODEL=1
    else
        fail "Model ${product} is not confirmed. Check your DSDT matches the 940XHA (_FST reads H_EC.FANS at EC 0x87, FANT = 0x0DAC/0x0EE2/0x1144/0x127A), then re-run with --force"
    fi
}

# ---------------------------------------------------------------------------
# Refuse if the CPIO / DSDT override fix is still active
# ---------------------------------------------------------------------------
check_cpio_fix() {
    if dmesg 2>/dev/null | grep -q "dsdt_fixed.aml"; then
        fail "fanspeed-fix-cpio (DSDT override) is active. Uninstall it and reboot first, otherwise you'll get two fan sensors"
    fi
    if [[ -f /boot/samsung-galaxybook-acpi.img ]]; then
        warn "/boot/samsung-galaxybook-acpi.img exists but isn't loaded this boot - consider uninstalling fanspeed-fix-cpio"
    fi
    ok "No DSDT override active"
}

# ---------------------------------------------------------------------------
# Dependencies: dkms, make, gcc, headers for the running kernel
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
    ok "Build dependencies present"
}

# ---------------------------------------------------------------------------
# Module signing (Secure Boot)
# Pick whichever MOK key is actually enrolled and point DKMS at it.
# ---------------------------------------------------------------------------
is_enrolled() {
    # mokutil --test-key prints "... is already enrolled" for an enrolled key
    [[ -f "$1" ]] && mokutil --test-key "$1" 2>/dev/null | grep -q "already enrolled"
}

setup_signing() {
    if ! command -v mokutil >/dev/null 2>&1 || ! mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
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
install_module() {
    # Remove any previous registration of this package (any version)
    if dkms status -m "$PKG_NAME" 2>/dev/null | grep -q .; then
        info "Removing previous ${PKG_NAME} DKMS install"
        modprobe -r "$MOD_NAME" 2>/dev/null || true
        dkms remove -m "$PKG_NAME" --all >/dev/null 2>&1 || true
    fi
    rm -rf /usr/src/"${PKG_NAME}"-*

    mkdir -p "$SRC_DIR"
    cp "$SCRIPT_DIR"/galaxybook_fan.c "$SCRIPT_DIR"/Makefile "$SCRIPT_DIR"/dkms.conf "$SRC_DIR"/ \
        || fail "Couldn't copy module source to ${SRC_DIR}"

    info "Building with DKMS (this takes a few seconds)"
    dkms add -m "$PKG_NAME" -v "$PKG_VERSION" >/dev/null || fail "dkms add failed"
    if ! dkms install -m "$PKG_NAME" -v "$PKG_VERSION"; then
        fail "dkms install failed - see /var/lib/dkms/${PKG_NAME}/${PKG_VERSION}/build/make.log"
    fi
    ok "DKMS module installed for $(uname -r) (rebuilds automatically on kernel updates)"

    echo "$MOD_NAME" > "$MODLOAD_CONF"
    ok "Autoload: ${MODLOAD_CONF}"

    if [[ "${FORCED_MODEL:-0}" -eq 1 ]]; then
        echo "options ${MOD_NAME} force=1" > "$MODPROBE_CONF"
        ok "force=1 set in ${MODPROBE_CONF}"
    fi
}

# ---------------------------------------------------------------------------
# Unbind stock acpi-fan from the fan device (built-in driver on most distros,
# so blacklisting doesn't work - use a udev rule on the bind event)
# ---------------------------------------------------------------------------
install_unbind() {
    cat > "$UDEV_RULE" <<'EOF'
# Written by galaxybook-fan install.sh.
# Samsung's FAN0._FST is broken (Index without DerefOf), so the stock acpi-fan
# driver only produces AML errors and a dead fan sensor. galaxybook_fan reads
# the EC directly instead. The fan has no ACPI control (_FPS/_FSL), so the
# cooling device acpi-fan registers does nothing - unbinding it loses nothing.
ACTION=="bind", SUBSYSTEM=="platform", DRIVER=="acpi-fan", KERNEL=="PNP0C0B:*", \
  RUN+="/bin/sh -c 'echo %k > /sys/bus/platform/drivers/acpi-fan/unbind'"
EOF
    udevadm control --reload
    ok "udev rule: ${UDEV_RULE}"

    local dev
    for dev in "$ACPI_FAN_DRV"/PNP0C0B:*; do
        [[ -e "$dev" ]] || continue
        echo "$(basename "$dev")" > "$ACPI_FAN_DRV/unbind" 2>/dev/null \
            && ok "Unbound acpi-fan from $(basename "$dev")"
    done
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
        fail "Module loaded but no ${MOD_NAME} hwmon device appeared"
    elif [[ "$rpm" == "read error" ]]; then
        warn "hwmon device present but fan1_input returned an error - EC level out of range?"
    else
        ok "Fan speed: ${rpm} RPM"
    fi
}

check_distro
check_model
check_cpio_fix
install_deps
setup_signing
install_module
install_unbind
verify

echo
ok "Done. Check with: sensors   (or Mission Center / System Monitor)"
echo "    Expected values: 0, 3510, 3820, 4430, 4740 RPM"
echo
