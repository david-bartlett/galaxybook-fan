#!/bin/bash
# =============================================================================
# check-galaxybook-fan.sh - will galaxybook-fan work on this laptop?
#
#   sudo bash check-galaxybook-fan.sh
#   (or: chmod +x check-galaxybook-fan.sh && sudo ./check-galaxybook-fan.sh -
#   a downloaded file can't be run with ./ until it's made executable)
#
# Read-only: installs nothing and changes nothing, with or without the fix
# installed. It checks the laptop model, reads this machine's own firmware
# (the DSDT) the same way the installer does, and says:
#   - whether galaxybook-fan is for this laptop and should work
#   - whether your model is already confirmed (then there's nothing to report)
#   - if the fix is installed, not yet confirmed and reading the fan: a report
#     to paste into a "Works on my model" issue
#
# Needs root (only root can read the DSDT), python3 and iasl (acpica-tools).
#
# The release's copy is a single file: tools/build-check-script.sh builds it
# with lib/models.sh and lib/dsdt-fan-config.py built in. Run from a clone,
# this script uses those two files directly.
# =============================================================================
set -uo pipefail

REPO_URL="https://github.com/david-bartlett/galaxybook-fan"
WORKS_URL="$REPO_URL/issues/new?template=works_on.yml"
BUG_URL="$REPO_URL/issues/new?template=bug_report.yml"

if [[ -t 1 ]]; then
    B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; C=$'\e[36m'; N=$'\e[0m'
else
    B=""; G=""; Y=""; R=""; C=""; N=""
fi
ok()   { echo "${G}[ OK ]${N}  $*"; }
info() { echo "${C}[INFO]${N}  $*"; }
warn() { echo "${Y}[WARN]${N}  $*"; }
bad()  { echo "${R}[ NO ]${N}  $*"; }
rule() { echo "=============================================="; }

#@EMBED@ (tools/build-check-script.sh puts lib/models.sh and the parser here)

WORK_DIR=""
cleanup() { [[ -n "$WORK_DIR" ]] && rm -rf "$WORK_DIR"; }
trap cleanup EXIT

# The model lists and the parser: built in (release copy) or from the clone
if [[ "${GBFAN_EMBEDDED:-0}" != 1 ]]; then
    HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
    # shellcheck source=../lib/models.sh
    source "$HERE/../lib/models.sh" 2>/dev/null \
        || { echo "lib/models.sh not found - run the release's check-galaxybook-fan.sh, or this one from a clone"; exit 2; }
    PARSER_SRC="$HERE/../lib/dsdt-fan-config.py"
fi

rule
echo "  ${B}Will galaxybook-fan work on this laptop?${N}"
echo "  (read-only check - nothing is installed or changed)"
rule
echo

if [[ $EUID -ne 0 ]]; then
    echo "Run it with sudo - only root can read the laptop's firmware tables:"
    echo "  sudo bash $(basename "$0")"
    exit 2
fi

# --- 1. the laptop ------------------------------------------------------------
VENDOR="$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || true)"
PRODUCT="$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)"
BIOS="$(cat /sys/class/dmi/id/bios_version 2>/dev/null || true)"
MODEL="$(gbfan_model "$PRODUCT")"
# The distro's name. Some distros keep their base's name in os-release (MX
# Linux says "Debian GNU/Linux 13 (trixie)"), but their own in lsb-release:
# when the two IDs differ, show "MX 25.1 Infinity (based on Debian …)".
distro_name() {
    local pretty id lsb_id lsb_desc
    pretty="$(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-}")"
    id="$(. /etc/os-release 2>/dev/null && echo "${ID:-}")"
    if [[ -r /etc/lsb-release ]]; then
        lsb_id="$(sed -n 's/^DISTRIB_ID=//p' /etc/lsb-release | tr -d '"' | head -1)"
        lsb_desc="$(sed -n 's/^DISTRIB_DESCRIPTION=//p' /etc/lsb-release | tr -d '"' | head -1)"
        if [[ -n "$lsb_id" && -n "$lsb_desc" && "${lsb_id,,}" != "${id,,}" ]]; then
            echo "${lsb_desc}${pretty:+ (based on ${pretty})}"
            return
        fi
    fi
    echo "${pretty:-unknown}"
}
DISTRO="$(distro_name)"
KERNEL="$(uname -r)"

info "Laptop: ${VENDOR:-unknown} ${PRODUCT:-unknown} (BIOS ${BIOS:-unknown})"
info "System: ${DISTRO}, kernel ${KERNEL}"

if [[ "${VENDOR^^}" != *SAMSUNG* ]]; then
    bad "Not a Samsung laptop - galaxybook-fan is for the Samsung Galaxy Book 5 only."
    exit 1
fi
BOOK5=0; CONFIRMED=0
gbfan_in_list "$MODEL" "${BOOK5_MODELS[@]}" && BOOK5=1
gbfan_in_list "$MODEL" "${CONFIRMED_MODELS[@]}" && CONFIRMED=1
if [[ $BOOK5 -eq 1 && $CONFIRMED -eq 1 ]]; then
    ok "Galaxy Book 5 (${MODEL}) - confirmed working"
elif [[ $BOOK5 -eq 1 ]]; then
    ok "Galaxy Book 5 (${MODEL}) - not confirmed yet"
else
    warn "${PRODUCT} isn't a Galaxy Book 5. Earlier Galaxy Books report fan speed"
    warn "with the stock kernel driver; checking the firmware anyway."
fi

# --- 2. the tools ---------------------------------------------------------------
missing=()
command -v python3 >/dev/null 2>&1 || missing+=(python3)
command -v iasl    >/dev/null 2>&1 || missing+=(iasl)
if [[ ${#missing[@]} -gt 0 ]]; then
    bad "Missing: ${missing[*]} - needed to read the firmware. Install, then run this again:"
    if   command -v dnf    >/dev/null 2>&1; then echo "  sudo dnf install acpica-tools python3"
    elif command -v apt    >/dev/null 2>&1; then echo "  sudo apt install acpica-tools python3"
    elif command -v pacman >/dev/null 2>&1; then echo "  sudo pacman -S acpica python"
    else echo "  (the package with 'iasl' is usually acpica-tools or acpica)"; fi
    exit 2
fi

# --- 3. the firmware --------------------------------------------------------------
WORK_DIR="$(mktemp -d)" || { bad "mktemp failed"; exit 2; }
if [[ "${GBFAN_EMBEDDED:-0}" == 1 ]]; then
    PARSER_SRC="$WORK_DIR/dsdt-fan-config.py"
    printf '%s\n' "$GBFAN_PARSER" > "$PARSER_SRC"
fi
if ! cp /sys/firmware/acpi/tables/DSDT "$WORK_DIR/dsdt.dat" 2>/dev/null; then
    bad "Couldn't read /sys/firmware/acpi/tables/DSDT"
    exit 2
fi
info "Reading the firmware's fan method (DSDT)"
if ! (cd "$WORK_DIR" && iasl -d dsdt.dat >iasl.log 2>&1) || [[ ! -s "$WORK_DIR/dsdt.dsl" ]]; then
    tail -5 "$WORK_DIR/iasl.log"
    bad "iasl couldn't disassemble the DSDT"
    exit 2
fi
SUMMARY="$(python3 -I "$PARSER_SRC" --dsl "$WORK_DIR/dsdt.dsl" --product "$PRODUCT" 2>&1)"
PARSE_RC=$?
echo "$SUMMARY" | sed 's/^/        /'
echo

# --- 4. is the fix installed, and reading the fan? -------------------------------
INSTALLED=""; RPM=""
if [[ -f /etc/modules-load.d/galaxybook_fan.conf ]]; then
    INSTALLED="$(ls -d /usr/src/galaxybook-fan-* 2>/dev/null | sed -n 's|.*/galaxybook-fan-||p' | head -1)"
    INSTALLED="${INSTALLED:-yes}"
fi
for h in /sys/class/hwmon/hwmon*; do
    [[ "$(cat "$h/name" 2>/dev/null)" == galaxybook_fan ]] || continue
    RPM="$(cat "$h/fan1_input" 2>/dev/null || true)"
done

# --- 5. verdict -------------------------------------------------------------------
rule
if [[ $PARSE_RC -ne 0 ]]; then
    bad "This firmware's fan method isn't one galaxybook-fan knows, so it would"
    bad "refuse to install. Nothing is wrong with your laptop."
    [[ $BOOK5 -eq 1 ]] && echo "  It's a Galaxy Book 5, so please report it (paste everything above): $BUG_URL"
    rule; exit 1
fi
if [[ "$SUMMARY" == *"fix not needed"* ]]; then
    ok "Your firmware's fan method is already correct: the stock kernel driver"
    ok "should show the fan speed, so you don't need galaxybook-fan."
    rule; exit 0
fi
if [[ $BOOK5 -eq 0 ]]; then
    warn "The firmware has the bug galaxybook-fan works around, but this isn't a"
    warn "Galaxy Book 5, so the installer and packages won't install it."
    echo "  Please tell us (paste everything above): $BUG_URL"
    rule; exit 1
fi

ok "${B}galaxybook-fan should work on this laptop.${N}"
if [[ $CONFIRMED -eq 1 ]]; then
    ok "Your model (${MODEL}) is already confirmed - no need to report it."
    [[ -n "$INSTALLED" ]] && info "Installed: galaxybook-fan ${INSTALLED}${RPM:+, fan reading ${RPM} RPM now}"
    rule; exit 0
fi

if [[ -z "$INSTALLED" ]]; then
    info "Your model (${MODEL}) isn't confirmed yet. Install galaxybook-fan, then run"
    info "this check again: if the fan speed shows, it gives you a report to post."
    rule; exit 0
fi
if [[ -z "$RPM" ]]; then
    warn "galaxybook-fan ${INSTALLED} is installed but the fan sensor isn't there."
    warn "Check 'sudo dmesg | grep galaxybook_fan', and please report it: $BUG_URL"
    rule; exit 1
fi

if [[ "$RPM" == 0 ]]; then
    info "galaxybook-fan ${INSTALLED} is installed; the fan is off right now (0 RPM)."
    info "Load the CPU for a minute so the fan spins, e.g. in another terminal:"
    info "  timeout 60 openssl speed -multi \$(nproc) rsa4096"
    info "and run this check again while it's busy, so the report shows a real reading."
    rule; exit 0
fi
ok "Installed and reading the fan: ${RPM} RPM."
echo
echo "  ${B}Your model isn't confirmed yet - please report it, so it can be added.${N}"
echo "  Open: $WORKS_URL"
echo "  and paste this:"
echo
echo '```'
echo "Model:       ${PRODUCT} (BIOS ${BIOS})"
echo "Fix:         galaxybook-fan ${INSTALLED}, fan reading ${RPM} RPM"
echo "Distro:      ${DISTRO}, kernel ${KERNEL}"
echo "$SUMMARY"
echo '```'
rule
exit 0
