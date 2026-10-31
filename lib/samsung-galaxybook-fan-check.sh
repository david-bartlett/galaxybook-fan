#!/bin/bash
# ============================================================================
# samsung-galaxybook-fan-check.sh - is the galaxybook-fan fix still needed?
#
#   --test-native [--wait SECS]
#       Briefly bind the stock acpi-fan driver and see whether it can now
#       read the fan speed itself (a kernel or BIOS fix). Prints a verdict.
#       The test is only conclusive while the fan is spinning, because the
#       broken _FST code path is only reached then; --wait polls for that.
#
#   --monitor
#       Run by samsung-galaxybook-fan-monitor.service (root) at login when
#       the kernel or BIOS version changed, or the module isn't loaded.
#       Decides what changed and writes a notification for the user check
#       script to show. It never installs or removes anything itself.
#
# Installed to /usr/local/bin by galaxybook-fan's install.sh; also run
# straight from the repo by "install.sh --test-native".
# ============================================================================
set -uo pipefail

MOD_NAME="galaxybook_fan"
ACPI_FAN_DRV="/sys/bus/platform/drivers/acpi-fan"
STATE_DIR="/var/lib/samsung-galaxybook"
STATE_FILE="${STATE_DIR}/fan-state"
STATUS_DIR="/run/samsung-galaxybook"
STATUS_FILE="${STATUS_DIR}/fan-status"
PARSER="/usr/local/lib/samsung-galaxybook/fan/dsdt-fan-config.py"
TITLE="Samsung Galaxy Book — Fan Speed Fix"
TAG="samsung-galaxybook-fan-monitor"

# ---------------------------------------------------------------------------
# Readings
# ---------------------------------------------------------------------------
hwmon_by_name() {   # $1 = hwmon name -> path of its hwmon dir (first match)
    local h
    for h in /sys/class/hwmon/hwmon*; do
        [[ "$(cat "$h/name" 2>/dev/null)" == "$1" ]] && { echo "$h"; return 0; }
    done
    return 1
}

our_rpm() {         # our module's current reading, or nothing
    local h
    h="$(hwmon_by_name "$MOD_NAME")" || return 1
    cat "$h/fan1_input" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Native test
# Prints one of:
#   works      - acpi-fan read a running fan's speed: the fix isn't needed
#   broken     - acpi-fan still can't read it: the fix is still needed
#   fan-off    - fan wasn't spinning, so the test proves nothing
#   no-device  - no PNP0C0B fan device / acpi-fan driver on this system
# ---------------------------------------------------------------------------
native_test() {
    local wait_secs="${1:-0}" ours="" bound=() dev name h val rc verdict

    [[ -d "$ACPI_FAN_DRV" ]] || { echo no-device; return; }
    compgen -G "/sys/bus/platform/devices/PNP0C0B:*" >/dev/null || { echo no-device; return; }

    # Wait (if asked) for our module to report a spinning fan
    if [[ -d /sys/module/$MOD_NAME ]]; then
        local i
        for ((i = 0; i <= wait_secs; i++)); do
            ours="$(our_rpm || true)"
            [[ "$ours" =~ ^[0-9]+$ && "$ours" -gt 0 ]] && break
            [[ $i -lt $wait_secs ]] && sleep 1
        done
    fi

    # Bind acpi-fan to any fan device it isn't bound to
    for dev in /sys/bus/platform/devices/PNP0C0B:*; do
        name="$(basename "$dev")"
        [[ -e "$ACPI_FAN_DRV/$name" ]] && continue
        if echo "$name" > "$ACPI_FAN_DRV/bind" 2>/dev/null; then
            bound+=("$name")
        fi
    done
    sleep 1

    val=""; rc=1
    if h="$(hwmon_by_name acpi_fan)"; then
        val="$(cat "$h/fan1_input" 2>/dev/null)"; rc=$?
    fi

    # Put things back the way they were
    for name in "${bound[@]}"; do
        echo "$name" > "$ACPI_FAN_DRV/unbind" 2>/dev/null || true
    done

    if [[ $rc -ne 0 || ! "$val" =~ ^[0-9]+$ ]]; then
        verdict=broken        # bind/probe failed, no hwmon, or read error
    elif [[ "$val" -gt 0 ]]; then
        verdict=works
    elif [[ "$ours" =~ ^[0-9]+$ && "$ours" -gt 0 ]]; then
        verdict=broken        # says 0 while our module sees it spinning
    else
        verdict=fan-off
    fi
    echo "$verdict"
}

# ---------------------------------------------------------------------------
# Does the current DSDT's _FST still have the bug?  fixed | broken | unknown
# ---------------------------------------------------------------------------
dsdt_fst_status() {
    local work out
    command -v iasl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 \
        && [[ -f "$PARSER" ]] || { echo unknown; return; }
    work="$(mktemp -d)" || { echo unknown; return; }
    if cp /sys/firmware/acpi/tables/DSDT "$work/dsdt.dat" 2>/dev/null \
            && (cd "$work" && iasl -d dsdt.dat >/dev/null 2>&1) \
            && out="$(python3 -I "$PARSER" --dsl "$work/dsdt.dsl" --status 2>/dev/null)"; then
        echo "$out"
    else
        echo unknown
    fi
    rm -rf "$work"
}

# ---------------------------------------------------------------------------
# Monitor
# ---------------------------------------------------------------------------
notify_user() {     # icon title message - format shared with the other fixes
    local icon="$1" title="$2" msg="$3" tmp
    logger -t "$TAG" "$title: $msg"
    mkdir -p "$STATUS_DIR" && chmod 755 "$STATUS_DIR"
    tmp="$(mktemp "${STATUS_DIR}/.fan-status.XXXXXX")" || return 0
    printf '%s\n%s\n%s\n' "$icon" "$title" "$msg" > "$tmp"
    chmod 644 "$tmp"
    mv -f "$tmp" "$STATUS_FILE"
}

record_state() {
    mkdir -p "$STATE_DIR"
    {
        echo "KVER=$(uname -r)"
        echo "BIOS=$(cat /sys/class/dmi/id/bios_version 2>/dev/null)"
        echo "INSTALL_DIR=${INSTALL_DIR:-}"
    } > "$STATE_FILE.tmp" && chmod 644 "$STATE_FILE.tmp" && mv -f "$STATE_FILE.tmp" "$STATE_FILE"
}

monitor() {
    local cur_k cur_b fst verdict where
    rm -f "$STATUS_FILE"
    [[ -f "/etc/modules-load.d/${MOD_NAME}.conf" ]] || exit 0    # fix not installed

    KVER="" BIOS="" INSTALL_DIR=""
    # shellcheck disable=SC1090
    [[ -f "$STATE_FILE" ]] && source "$STATE_FILE"
    cur_k="$(uname -r)"
    cur_b="$(cat /sys/class/dmi/id/bios_version 2>/dev/null)"
    where="${INSTALL_DIR:-extras/galaxybook-fan}"

    # 1. BIOS changed: look at the new firmware's _FST
    if [[ "$cur_b" != "$BIOS" ]]; then
        fst="$(dsdt_fst_status)"
        logger -t "$TAG" "BIOS changed (${BIOS:-none} -> $cur_b): _FST is $fst"
        case "$fst" in
            fixed)
                notify_user dialog-information "$TITLE" \
                    "Your BIOS update ($cur_b) fixed Samsung's fan status method, so the fan speed should now work without this fix. Run 'sudo ./uninstall.sh' in $where to remove it."
                record_state ;;
            broken)
                if [[ -d /sys/module/$MOD_NAME ]]; then
                    logger -t "$TAG" "module still loaded (DSDT unchanged) - nothing to do"
                    record_state
                else
                    # The module refuses to load with a changed DSDT. Keep
                    # reminding at each login until the installer is re-run.
                    notify_user dialog-warning "$TITLE" \
                        "Your BIOS was updated ($cur_b), so the fan speed fix is paused until it's re-derived for the new firmware. Run 'sudo ./install.sh' in $where."
                fi ;;
            *)
                notify_user dialog-warning "$TITLE" \
                    "Your BIOS update ($cur_b) changed the fan firmware in a way this fix doesn't recognise. Run 'sudo ./install.sh --test-native' in $where to see whether fan speed now works on its own."
                record_state ;;
        esac
        return
    fi

    # 2. Module should be loaded on every kernel
    if [[ ! -d /sys/module/$MOD_NAME ]]; then
        notify_user dialog-error "$TITLE" \
            "The fan speed fix isn't active on kernel $cur_k - the DKMS build may have failed, or (with Secure Boot) its signing key isn't enrolled. Run 'sudo ./install.sh' in $where."
        return
    fi

    # 3. New kernel: has it started handling the fan natively?
    if [[ "$cur_k" != "$KVER" ]]; then
        verdict="$(native_test 60)"   # wait up to a minute for the fan to spin
        logger -t "$TAG" "kernel changed (${KVER:-none} -> $cur_k): native acpi-fan test: $verdict"
        case "$verdict" in
            works)
                notify_user dialog-information "$TITLE" \
                    "Kernel $cur_k now reads the fan speed natively, so this fix is no longer needed. Run 'sudo ./uninstall.sh' in $where to remove it."
                record_state ;;
            broken|no-device)
                record_state ;;
            fan-off)
                # Inconclusive - don't record, so the check runs again next login
                logger -t "$TAG" "fan stayed off, so the test was inconclusive - will retry next login" ;;
        esac
    fi
}

# ---------------------------------------------------------------------------
case "${1:-}" in
    --monitor)
        [[ $EUID -eq 0 ]] || { echo "Run as root" >&2; exit 1; }
        monitor ;;
    --test-native)
        [[ $EUID -eq 0 ]] || { echo "Run as root" >&2; exit 1; }
        wait=0
        [[ "${2:-}" == "--wait" ]] && wait="${3:-0}"
        native_test "$wait" ;;
    --record-state)
        [[ $EUID -eq 0 ]] || { echo "Run as root" >&2; exit 1; }
        INSTALL_DIR="${2:-}" record_state ;;
    *)
        echo "Usage: $0 --test-native [--wait SECS] | --monitor | --record-state [INSTALL_DIR]" >&2
        exit 2 ;;
esac
