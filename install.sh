#!/bin/bash
# ============================================================================
# galaxybook-fan - install
#
# Fan speed reporting for Samsung Galaxy Book 5 laptops via a small DKMS hwmon
# module that reads the EC's fan level field through ACPI, the same way the
# firmware's _FST method does, and applies _FST's RPM table itself.
#
# No DSDT override and nothing added to the boot chain. Also unbinds the
# stock acpi-fan driver from the fan device, because Samsung's _FST method is
# broken (missing DerefOf) and acpi-fan only ever produces I/O errors, AML
# errors in dmesg and a dead "Fan 0" in monitors.
#
# The EC location and RPM table aren't hardcoded: they're derived from this
# machine's own DSDT (dsdt-fan-config.py), validated, and baked into the
# module's config header. The module also refuses to load if the DSDT later
# changes (BIOS update) until this installer has been re-run.
#
# It also installs a login-time check (the same pattern as fingerprint-fix-sdcp
# and fnkeys-fix-book5): after a kernel or BIOS update it tests whether the
# fix is still needed and notifies you if not, or if it needs re-running.
#
# Usage: sudo ./install.sh [--check] [--test-native] [--force]
#   --check         derive and show the fan config from the DSDT, install nothing
#   --test-native   test whether the stock acpi-fan driver now works by itself
#   --force         install on a Samsung that isn't a Galaxy Book 5, or when
#                   the firmware already looks fixed
# ============================================================================
set -uo pipefail

PKG_NAME="galaxybook-fan"
PKG_VERSION="0.2.0"   # keep in step with VERSION and dkms.conf (the release tool sets all three)
MOD_NAME="galaxybook_fan"
SRC_DIR="/usr/src/${PKG_NAME}-${PKG_VERSION}"
MODLOAD_CONF="/etc/modules-load.d/${MOD_NAME}.conf"
MODPROBE_CONF="/etc/modprobe.d/${MOD_NAME}.conf"
UDEV_RULE="/etc/udev/rules.d/90-galaxybook-acpi-fan-unbind.rules"   # old versions only
UNBIND_SERVICE="/etc/systemd/system/galaxybook-acpi-fan-unbind.service"
DKMS_SIGN_CONF="/etc/dkms/framework.conf.d/${PKG_NAME}-signing.conf"
# Temporary, while this script runs DKMS (see defer_initramfs) - sorts last
DKMS_DEFER_CONF="/etc/dkms/framework.conf.d/zz-${PKG_NAME}-defer-initramfs.conf"
# Keeps galaxybook_fan out of dracut initramfs images (see keep_out_of_initramfs)
DRACUT_CONF="/etc/dracut.conf.d/${PKG_NAME}.conf"
# Fedora: share the akmods key and DKMS config with Andy's fixes (same file,
# same format as webcam-fix-book5), so there's only ever one key to enrol
AKMODS_CERT="/etc/pki/akmods/certs/public_key.der"
AKMODS_KEY="/etc/pki/akmods/private/private_key.priv"
AKMODS_CONF="/etc/dkms/framework.conf.d/akmods-keys.conf"

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

# Galaxy Book 5 series - the same list as fnkeys-fix-book5. TESTED_MODELS
# have been run on real hardware; the rest of the series is expected to share
# the firmware bug, and the DSDT check decides for each machine anyway.
BOOK5_MODELS=("940XHA" "960XHA" "960QHA" "750XHD" "754XHD" "750QHA" "754QHA")
TESTED_MODELS=("940XHA")
# Oldest kernel the module has been build-tested against (6.8 to 7.0 all build
# cleanly); anything able to run a Lunar Lake Book 5 is newer than this.
MIN_KERNEL_MAJOR=6
MIN_KERNEL_MINOR=8
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORCE=0
CHECK_ONLY=0
TEST_NATIVE=0
WORK_DIR=""

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  {
    echo -e "${RED}[FAIL]${NC}  $*"
    if [[ ${CHECK_ONLY:-0} -eq 1 ]]; then
        echo
        echo -e "${RED}[FAIL]${NC}  Check failed - galaxybook-fan can't be installed on this machine (see above)."
        echo
    fi
    exit 1
}

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
check_kernel() {
    local kver major minor
    kver="$(uname -r)"
    major="${kver%%.*}"; minor="${kver#*.}"; minor="${minor%%.*}"
    if ! [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ ]]; then
        warn "Couldn't parse the kernel version '${kver}' - carrying on"
        return
    fi
    if (( major < MIN_KERNEL_MAJOR || (major == MIN_KERNEL_MAJOR && minor < MIN_KERNEL_MINOR) )); then
        fail "Kernel ${kver} is too old - galaxybook-fan needs ${MIN_KERNEL_MAJOR}.${MIN_KERNEL_MINOR} or newer"
    fi
    ok "Kernel: ${kver}"
}

check_model() {
    local vendor product model m
    vendor="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
    product="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"

    if [[ "${vendor^^}" != *SAMSUNG* ]]; then
        fail "Not a Samsung laptop (vendor: '${vendor}') - galaxybook-fan is for Samsung Galaxy Book 5 laptops only"
    fi
    [[ -n "$product" ]] || fail "Couldn't read the DMI product name"
    PRODUCT="$product"

    # Same normalisation as fnkeys-fix-book5: upper-case, drop a leading "NP"
    model="${product^^}"; model="${model#NP}"

    BOOK5=0
    for m in "${BOOK5_MODELS[@]}"; do
        [[ "$model" == "$m" ]] && BOOK5=1
    done

    if [[ $BOOK5 -eq 1 ]]; then
        local tested=0
        for m in "${TESTED_MODELS[@]}"; do [[ "$model" == "$m" ]] && tested=1; done
        if [[ $tested -eq 1 ]]; then
            ok "Model: ${product} (Galaxy Book 5, tested)"
        else
            ok "Model: ${product} (Galaxy Book 5)"
            info "Not tested on this model yet - the DSDT check below confirms it has the same firmware bug"
        fi
        return
    fi

    # Not a Book 5. Earlier Galaxy Books' fan speed works with the stock driver
    # (the kernel's _FST-only fan support was written and tested on a Book2 Pro),
    # so this fix isn't meant for them. --check is read-only, so allow it.
    if [[ $FORCE -eq 1 ]]; then
        warn "Model: ${product} is not a Galaxy Book 5 - continuing because of --force"
    elif [[ $CHECK_ONLY -eq 1 || $TEST_NATIVE -eq 1 ]]; then
        warn "Model: ${product} is not a Galaxy Book 5 (checking only)"
    else
        warn "Model: ${product} is not a Galaxy Book 5 - galaxybook-fan is for the Book 5 series only."
        warn "Earlier Galaxy Books report fan speed with the stock kernel driver."
        warn "To check this machine anyway: sudo ./install.sh --check   (or --test-native)"
        fail "Not installed (use --force to override)"
    fi
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
        PARSE_PKGS_INSTALLED="${pkgs[*]}"
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
cleanup() {
    [[ -n "$WORK_DIR" ]] && rm -rf "$WORK_DIR"
    rm -f "$DKMS_DEFER_CONF"      # always put DKMS's post_transaction back
}
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

    FIRMWARE_FIXED=0
    if [[ "$summary" == *"fix not needed"* ]]; then
        FIRMWARE_FIXED=1
        warn "This firmware's _FST already dereferences its table correctly, so the stock"
        warn "acpi-fan driver should report fan speed without this fix."
        warn "Check with: sudo ./install.sh --test-native"
        if [[ $CHECK_ONLY -eq 0 && $FORCE -eq 0 ]]; then
            fail "Not installed (use --force to install anyway)"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Dependencies: dkms, make, gcc, headers for the running kernel; mokutil for
# Secure Boot signing; polkit and notify-send for the login check (both can be
# missing on minimal Debian installs)
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
            command -v pkcheck >/dev/null 2>&1 || pkgs+=(polkit)
            [[ -d /sys/firmware/efi ]] && ! command -v mokutil >/dev/null 2>&1 && pkgs+=(mokutil)
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
            command -v pkcheck >/dev/null 2>&1 || pkgs+=(polkitd)
            [[ -d /sys/firmware/efi ]] && ! command -v mokutil >/dev/null 2>&1 && pkgs+=(mokutil)
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
            command -v pkcheck >/dev/null 2>&1 || pkgs+=(polkit)
            [[ -d /sys/firmware/efi ]] && ! command -v mokutil >/dev/null 2>&1 && pkgs+=(mokutil)
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
    command -v pkcheck >/dev/null 2>&1 \
        || warn "polkit still missing - the login check won't be able to start its monitor"
    ok "Build dependencies present"
}

# ---------------------------------------------------------------------------
# Module signing (Secure Boot)
# Pick whichever MOK key is actually enrolled and point DKMS at it.
# ---------------------------------------------------------------------------
secure_boot_on() {
    # Read the EFI variable directly so a missing mokutil can't make us think
    # Secure Boot is off (and build an unsigned module that won't load).
    # Layout: 4 bytes of attributes, then 1 data byte (1 = enabled).
    local var=/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d0-aa0d-00e098032b8c
    if [[ -r "$var" ]]; then
        [[ "$(od -An -t u1 -j 4 -N 1 "$var" 2>/dev/null | tr -d ' ')" == "1" ]]
        return
    fi
    local sb=""
    command -v mokutil >/dev/null 2>&1 && sb="$(mokutil --sb-state 2>/dev/null || true)"
    [[ "$sb" == *"SecureBoot enabled"* ]]
}

# mokutil --test-key exits 1 when a key IS enrolled, so match its output rather
# than its status (and don't pipe it into grep -q: under pipefail that fails).
key_state() {   # cert -> enrolled | pending | not-enrolled | missing
    local out
    [[ -f "$1" ]] || { echo missing; return; }
    out="$(mokutil --test-key "$1" 2>&1 || true)"
    case "$out" in
        *"already enrolled"*)   echo enrolled ;;
        *"enrollment request"*) echo pending ;;     # imported, waiting for reboot
        *)                      echo not-enrolled ;;
    esac
}

# The key pair DKMS will really use: framework.conf, then framework.conf.d/*.conf
# in glob order (DKMS sources them the same way, so later files win), skipping
# our own drop-in. Without any setting DKMS uses its default pair.
dkms_effective_key() {
    local f k="" c="" v kver
    kver="$(uname -r)"
    for f in /etc/dkms/framework.conf /etc/dkms/framework.conf.d/*.conf; do
        [[ -f "$f" && "$f" != "$DKMS_SIGN_CONF" ]] || continue
        v="$(sed -n 's/^[[:space:]]*mok_signing_key=//p' "$f" | tail -1 | tr -d "\"'")"
        [[ -n "$v" ]] && k="$v"
        v="$(sed -n 's/^[[:space:]]*mok_certificate=//p' "$f" | tail -1 | tr -d "\"'")"
        [[ -n "$v" ]] && c="$v"
    done
    k="${k:-/var/lib/dkms/mok.key}"; c="${c:-/var/lib/dkms/mok.pub}"
    # shellcheck disable=SC2016
    echo "${c//'$kernelver'/$kver}|${k//'$kernelver'/$kver}"
}

# Point DKMS at cert/key - via our own drop-in only if that isn't already
# what the existing config says. For the akmods key, use the shared
# akmods-keys.conf that Andy's fixes also write.
use_key() {
    local cert="$1" key="$2" eff
    if [[ "$cert" == "$AKMODS_CERT" && "$key" == "$AKMODS_KEY" && ! -f "$AKMODS_CONF" ]]; then
        mkdir -p "$(dirname "$AKMODS_CONF")"
        printf '%s\n' "# Fedora akmods MOK key for Secure Boot module signing" \
            "mok_signing_key=${AKMODS_KEY}" "mok_certificate=${AKMODS_CERT}" > "$AKMODS_CONF"
        info "DKMS configured to sign with the akmods key (${AKMODS_CONF})"
    fi
    eff="$(dkms_effective_key)"
    if [[ "$eff" == "${cert}|${key}" ]]; then
        if [[ -f "$DKMS_SIGN_CONF" ]]; then
            rm -f "$DKMS_SIGN_CONF"
            info "Removed ${DKMS_SIGN_CONF} - your DKMS config already uses this key"
        fi
        return
    fi
    mkdir -p "$(dirname "$DKMS_SIGN_CONF")"
    cat > "$DKMS_SIGN_CONF" <<EOF
# Written by ${PKG_NAME} install.sh - points DKMS at the MOK key below.
# Removed by ${PKG_NAME} uninstall.sh.
mok_signing_key="${key}"
mok_certificate="${cert}"
EOF
    info "DKMS pointed at ${cert} (${DKMS_SIGN_CONF})"
}

generate_key() {
    local cert="$1" key="$2"
    if [[ "$cert" == "$AKMODS_CERT" ]]; then
        if ! command -v kmodgenca >/dev/null 2>&1; then
            info "Installing akmods (provides kmodgenca, Fedora's module signing key tool)"
            dnf install -y akmods kmodtool >/dev/null || fail "Couldn't install akmods"
        fi
        info "Generating the akmods signing key (kmodgenca)"
        kmodgenca -a >/dev/null || fail "kmodgenca failed"
    elif [[ "$cert" == /var/lib/shim-signed/* ]] && command -v update-secureboot-policy >/dev/null 2>&1; then
        info "Generating Ubuntu's MOK signing key"
        update-secureboot-policy --new-key >/dev/null || fail "update-secureboot-policy --new-key failed"
    else
        command -v openssl >/dev/null 2>&1 || fail "openssl is needed to generate a signing key"
        info "Generating a module signing key at ${cert}"
        mkdir -p "$(dirname "$cert")" "$(dirname "$key")"
        openssl req -new -x509 -nodes -days 36500 -newkey rsa:2048 \
            -subj "/CN=DKMS module signing key ($(hostname))/" \
            -keyout "$key" -outform DER -out "$cert" >/dev/null 2>&1 \
            || fail "openssl couldn't generate the key"
        chmod 600 "$key"
    fi
    [[ -f "$cert" && -f "$key" ]] || fail "Key generation didn't produce ${cert} and ${key}"
}

MOK_PENDING=0     # module can't load until a key is enrolled
MOK_QUEUED=0      # ...and the enrolment request is already queued for next boot
MOK_CERT=""
setup_signing() {
    if ! secure_boot_on; then
        info "Secure Boot is off - module signing not needed"
        return
    fi
    command -v mokutil >/dev/null 2>&1 \
        || fail "Secure Boot is on but mokutil isn't installed - it's needed to check your signing key"
    info "Secure Boot is on - checking the module signing key"

    local eff eff_cert eff_key c cert key st
    eff="$(dkms_effective_key)"; eff_cert="${eff%%|*}"; eff_key="${eff##*|}"

    # Standard key pairs: what DKMS is configured with first, then the usual ones
    local candidates=(
        "$eff"
        "/etc/pki/akmods/certs/public_key.der|/etc/pki/akmods/private/private_key.priv"
        "/var/lib/shim-signed/mok/MOK.der|/var/lib/shim-signed/mok/MOK.priv"
        "/var/lib/dkms/mok.pub|/var/lib/dkms/mok.key"
    )

    # 1. An enrolled key - the normal case
    for c in "${candidates[@]}"; do
        cert="${c%%|*}"; key="${c##*|}"
        [[ -f "$key" && "$(key_state "$cert")" == enrolled ]] || continue
        use_key "$cert" "$key"
        ok "Signing with ${cert} (enrolled)"
        return
    done

    # 2. A key already imported, waiting for the MokManager step at next boot
    for c in "${candidates[@]}"; do
        cert="${c%%|*}"; key="${c##*|}"
        [[ -f "$key" && "$(key_state "$cert")" == pending ]] || continue
        use_key "$cert" "$key"
        warn "Signing with ${cert}, which is waiting to be enrolled at the next boot."
        MOK_PENDING=1; MOK_QUEUED=1; MOK_CERT="$cert"
        return
    done

    # 3. Nothing enrolled: use the key DKMS is configured for, creating it if
    #    needed. On Fedora with nothing configured, use the akmods key rather
    #    than DKMS's own, as Andy's fixes do - one key, one enrolment.
    cert="$eff_cert"; key="$eff_key"
    if [[ "$PKG_MGR" == dnf && "$eff" == "/var/lib/dkms/mok.pub|/var/lib/dkms/mok.key" ]]; then
        cert="$AKMODS_CERT"; key="$AKMODS_KEY"
    fi
    if [[ ! -f "$cert" || ! -f "$key" ]]; then
        generate_key "$cert" "$key"
    fi
    use_key "$cert" "$key"
    st="$(key_state "$cert")"
    warn "Secure Boot is on, but ${cert} isn't enrolled in your firmware yet, so"
    warn "the module can't load until it is. (A BIOS update can also clear enrolled keys.)"

    local answer="n"
    if [[ -t 0 ]]; then
        read -r -p "        Import it now with mokutil? You'll set a one-time password. [Y/n] " answer
        answer="${answer:-y}"
    fi
    if [[ "$answer" =~ ^[Yy] ]] && mokutil --import "$cert"; then
        st="$(key_state "$cert")"
    fi
    if [[ "$st" == pending ]]; then
        ok "Key queued for enrolment"
        MOK_QUEUED=1
    else
        warn "Not imported - see the end of the install for what to do."
    fi
    MOK_PENDING=1; MOK_CERT="$cert"
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
        info "Removing ${PKG_NAME}/${v} from DKMS"
        dkms remove "${PKG_NAME}/${v}" --all || true
    done
    # Anything DKMS couldn't remove (half-added tree, etc.)
    rm -rf /var/lib/dkms/"$PKG_NAME"
}

# ---------------------------------------------------------------------------
# Initramfs handling - same approach as fnkeys-fix-book5.
# Some distros (Fedora) set post_transaction in DKMS's config to rebuild every
# kernel's initramfs after each DKMS operation, which takes minutes. This
# module is never in the initramfs (it loads later via modules-load.d), so
# suspend that for this script's own DKMS steps; the EXIT trap removes the
# drop-in again even if the script fails. DKMS's own setting is untouched.
# ---------------------------------------------------------------------------
defer_initramfs() {
    if grep -qs '^[[:space:]]*post_transaction=' /etc/dkms/framework.conf \
            || grep -rqs '^[[:space:]]*post_transaction=' /etc/dkms/framework.conf.d/; then
        mkdir -p "$(dirname "$DKMS_DEFER_CONF")"
        echo 'post_transaction=""' > "$DKMS_DEFER_CONF"
        info "DKMS's initramfs rebuild suspended while installing (galaxybook_fan isn't in the initramfs)"
    fi
}

# Tell dracut never to pack this module into an initramfs. Otherwise dracut's
# host-only mode can include it if it's loaded when a new initramfs is built,
# and then a later reinstall would leave a stale copy there - which is exactly
# what deferring the rebuild above relies on not happening.
keep_out_of_initramfs() {
    command -v dracut >/dev/null 2>&1 || return 0
    mkdir -p "$(dirname "$DRACUT_CONF")"
    cat > "$DRACUT_CONF" <<EOF
# Written by ${PKG_NAME} install.sh - galaxybook_fan loads from modules-load.d
# after boot and must never be in the initramfs. Removed by uninstall.sh.
omit_drivers+=" ${MOD_NAME} "
EOF
}

# If an older install did end up in this kernel's initramfs, rebuild just this
# kernel's image so the stale copy goes (one kernel, not --regenerate-all).
refresh_initramfs_if_needed() {
    local kver img
    kver="$(uname -r)"
    if command -v lsinitrd >/dev/null 2>&1; then
        img="$(lsinitrd --kver "$kver" 2>/dev/null || true)"
        if [[ "$img" == *"/${MOD_NAME}.ko"* ]]; then
            info "Removing an old ${MOD_NAME} copy from the initramfs (this kernel only)"
            dracut --force --kver "$kver" >/dev/null 2>&1 || warn "dracut failed - run: sudo dracut --force"
        fi
    elif command -v lsinitramfs >/dev/null 2>&1; then
        img="$(lsinitramfs "/boot/initrd.img-${kver}" 2>/dev/null || true)"
        if [[ "$img" == *"/${MOD_NAME}.ko"* ]]; then
            info "Removing an old ${MOD_NAME} copy from the initramfs (this kernel only)"
            update-initramfs -u -k "$kver" >/dev/null 2>&1 || warn "update-initramfs failed - run: sudo update-initramfs -u"
        fi
    fi
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
        # With a key that isn't enrolled yet, DKMS's own modprobe fails even
        # though the module was built, signed and installed fine.
        local st
        st="$(dkms status -m "$PKG_NAME" -v "$PKG_VERSION" -k "$(uname -r)" 2>/dev/null || true)"
        if [[ $MOK_PENDING -eq 1 && "$st" == *installed* ]]; then
            info "Module installed; it can't load until the signing key is enrolled (expected)"
        else
            fail "dkms install failed - see /var/lib/dkms/${PKG_NAME}/${PKG_VERSION}/build/make.log"
        fi
    fi
    ok "DKMS module installed for $(uname -r) (rebuilds automatically on kernel updates)"

    # With Secure Boot on, make sure DKMS really signed it - an unsigned module
    # would only show up later as a confusing load failure
    if secure_boot_on; then
        local path signer=""
        path="$(modinfo -n "$MOD_NAME" 2>/dev/null || true)"
        [[ -n "$path" ]] || fail "Can't find the installed ${MOD_NAME} module to check its signature"
        signer="$(modinfo -F signer "$path" 2>/dev/null || true)"
        [[ -n "$signer" ]] || fail "DKMS built ${MOD_NAME} without signing it, so it won't load with Secure Boot - check the mok_ settings in /etc/dkms/framework.conf.d/"
        ok "Module signed (${signer})"
    fi

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
# Same pattern as fingerprint-fix-sdcp and fnkeys-fix-book5: a user timer fires
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

    mkdir -p "$(dirname "$POLKIT_RULE")"
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

    if ! id -nG "$user" | tr ' ' '\n' | grep -qxE 'wheel|sudo'; then
        warn "${user} isn't in the wheel or sudo group, so the login check can't start its"
        warn "monitor without a password. Add them with: usermod -aG wheel ${user}  (sudo on Debian/Ubuntu)"
    fi

    # runuser (util-linux) rather than sudo, which minimal Debian installs lack
    _fan_user_systemctl() {
        runuser -u "$user" -- env \
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
    if [[ $MOK_PENDING -eq 1 ]]; then
        warn "Skipping the load test - the module will load after the key is enrolled and you reboot."
        return
    fi
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

# ---------------------------------------------------------------------------
# --check summary: can this machine use the fix, and what would install do?
# Read-only - signing state is only reported, never changed.
# ---------------------------------------------------------------------------
check_verdict() {
    local sb_line="" eff cert st
    if secure_boot_on; then
        if command -v mokutil >/dev/null 2>&1; then
            eff="$(dkms_effective_key)"; cert="${eff%%|*}"
            # Same choice setup_signing makes: Fedora uses the akmods key
            [[ "$PKG_MGR" == dnf && "$eff" == "/var/lib/dkms/mok.pub|/var/lib/dkms/mok.key" ]] && cert="$AKMODS_CERT"
            st="$(key_state "$cert")"
            case "$st" in
                enrolled) sb_line="Secure Boot on - module will be signed with ${cert} (enrolled)" ;;
                pending)  sb_line="Secure Boot on - ${cert} is waiting to be enrolled at the next boot" ;;
                missing)  sb_line="Secure Boot on - no signing key yet; install will create one and ask to enrol it (one reboot)" ;;
                *)        sb_line="Secure Boot on - ${cert} isn't enrolled; install will ask to enrol it (one reboot)" ;;
            esac
        else
            sb_line="Secure Boot on - install will set up a signing key (mokutil will be installed)"
        fi
    else
        sb_line="Secure Boot off - no module signing needed"
    fi

    echo
    echo "=============================================="
    if [[ ${FIRMWARE_FIXED:-0} -eq 1 ]]; then
        ok "Check passed, but this fix isn't needed: the firmware's _FST is already correct."
        echo "    Confirm the stock driver works with: sudo ./install.sh --test-native"
    elif [[ ${BOOK5:-0} -eq 0 ]]; then
        warn "Check passed: the firmware has the bug this fix works around,"
        warn "but ${PRODUCT} isn't a Galaxy Book 5, so installing needs --force:"
        echo "    sudo ./install.sh --force"
    else
        ok "Check passed - galaxybook-fan can be installed on this machine."
        if [[ -f "$MODLOAD_CONF" ]]; then
            echo "    It's already installed; re-running install.sh will update it:"
        else
            echo "    To install:"
        fi
        echo "    sudo ./install.sh"
    fi
    echo "    ${sb_line}"
    if [[ -n "${PARSE_PKGS_INSTALLED:-}" ]]; then
        echo "    Only ${PARSE_PKGS_INSTALLED} was installed (needed to read the DSDT); nothing else changed."
    else
        echo "    Nothing was installed or changed."
    fi
    echo "=============================================="
    echo
}

check_distro

# The unbind service and the login check are systemd units. Some distros offer
# a non-systemd boot option (e.g. MX Linux's SysVinit), where they would never
# run - same guard as the other Galaxy Book fixes. --check and --test-native
# only read things, so they still work there.
if [[ ! -d /run/systemd/system && $CHECK_ONLY -eq 0 && $TEST_NATIVE -eq 0 ]]; then
    fail "systemd is not running (e.g. MX Linux booted with SysVinit). galaxybook-fan needs systemd - reboot, choose the systemd boot option and run this installer again."
fi

if [[ $TEST_NATIVE -eq 1 ]]; then
    [[ -x "$SCRIPT_DIR/samsung-galaxybook-fan-check.sh" ]] || chmod +x "$SCRIPT_DIR/samsung-galaxybook-fan-check.sh"
    info "Testing whether the stock acpi-fan driver can read the fan by itself."
    if [[ -d /sys/module/$MOD_NAME ]]; then
        info "The test needs the fan spinning - waiting up to 2 minutes."
        info "If it's quiet, load the CPU in another terminal, e.g.: timeout 180 openssl speed -multi \$(nproc) rsa4096"
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

check_kernel
check_model
ensure_parse_tools
derive_config

if [[ $CHECK_ONLY -eq 1 ]]; then
    check_verdict
    exit 0
fi

install_deps
setup_signing
defer_initramfs
keep_out_of_initramfs
install_module
refresh_initramfs_if_needed
install_unbind
install_monitor
verify

echo
if [[ $MOK_PENDING -eq 1 ]]; then
    # Say this last, so the DKMS output above doesn't bury it
    warn "Installed - but the fan module can't load until your signing key is enrolled."
    echo
    if [[ $MOK_QUEUED -eq 0 ]]; then
        echo "    1. Queue the key for enrolment (you'll choose a one-time password):"
        echo "         sudo mokutil --import ${MOK_CERT}"
        echo "    2. Reboot. At the blue MokManager screen choose:"
    else
        echo "    1. Reboot now. At the blue MokManager screen choose:"
    fi
    echo "         Enroll MOK -> Continue -> Yes -> type that password -> Reboot"
    echo "    The fan sensor then appears by itself - no need to re-run this installer."
    echo "    Expected values afterwards: ${EXPECTED_SPEEDS:-see above}"
else
    ok "Done. Check with: sensors   (or Mission Center / System Monitor)"
    echo "    Expected values: ${EXPECTED_SPEEDS:-see above}"
    echo "    After a BIOS update, re-run this installer - the module won't load until you do."
fi
echo
