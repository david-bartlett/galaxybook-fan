#!/bin/bash
# =============================================================================
# gen-config.sh - DKMS PRE_BUILD for galaxybook-fan (module/dkms.conf).
#
# Runs before every DKMS build (install, rebuild, each new kernel), in DKMS's
# copy of the source: reads this machine's DSDT and writes
# galaxybook_fan_config.h for it, with the same parser and checks as
# install.sh (dsdt-fan-config.py and models.sh, copied next to this file).
#
# Some DKMS versions ignore a PRE_BUILD's exit status, so on any problem this
# writes a config header containing only an #error with the reason: the build
# then fails whatever DKMS does, and the reason is in DKMS's make.log
# (/var/lib/dkms/galaxybook-fan/<version>/build/make.log).
#
# Refuses (unless /etc/galaxybook-fan/force exists, left by install.sh --force
# or a package installed with GALAXYBOOK_FAN_FORCE=1):
#   - a laptop that isn't a Samsung Galaxy Book 5 (lib/models.sh)
#   - firmware whose fan method is already correct (the stock driver works)
# Always refuses firmware whose fan method it doesn't recognise, and a DSDT
# replaced at boot by an ACPI override (its own firmware can't be read then).
#
# GBFAN_DSDT and GBFAN_DMI override /sys/firmware/acpi/tables/DSDT and
# /sys/class/dmi/id, for testing without the laptop.
# =============================================================================
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$HERE/galaxybook_fan_config.h"
DSDT="${GBFAN_DSDT:-/sys/firmware/acpi/tables/DSDT}"
DMI="${GBFAN_DMI:-/sys/class/dmi/id}"
FORCE_FLAG="/etc/galaxybook-fan/force"
WORK=""
trap '[[ -n "$WORK" ]] && rm -rf "$WORK"' EXIT

refuse() {
    local msg="${1//\"/\'}"
    msg="${msg//\\/\/}"
    printf '/* Written by gen-config.sh: no config for this machine. */\n#error "galaxybook-fan: %s"\n' "$msg" > "$OUT"
    echo "galaxybook-fan: $1" >&2
    exit 1
}

FORCE=0
[[ -e "$FORCE_FLAG" ]] && FORCE=1

[[ -f "$HERE/models.sh" && -f "$HERE/dsdt-fan-config.py" ]] \
    || refuse "models.sh or dsdt-fan-config.py missing from the DKMS source"
# shellcheck source=../lib/models.sh
source "$HERE/models.sh"

vendor="$(cat "$DMI/sys_vendor" 2>/dev/null || true)"
product="$(cat "$DMI/product_name" 2>/dev/null || true)"
model="$(gbfan_model "$product")"

if [[ "${vendor^^}" != *SAMSUNG* ]]; then
    [[ $FORCE -eq 1 ]] || refuse "not a Samsung laptop (${vendor:-unknown vendor})"
elif ! gbfan_in_list "$model" "${BOOK5_MODELS[@]}"; then
    [[ $FORCE -eq 1 ]] || refuse "${product:-this model} is not a Galaxy Book 5 (install with --force to build anyway)"
fi

gbfan_dsdt_overridden && refuse "$GBFAN_OVERRIDE_MSG"

command -v iasl    >/dev/null 2>&1 || refuse "iasl not found (install acpica-tools, or acpica on Arch)"
command -v python3 >/dev/null 2>&1 || refuse "python3 not found"
[[ -r "$DSDT" ]] || refuse "can't read the DSDT ($DSDT)"

WORK="$(mktemp -d)" || refuse "mktemp failed"
cp "$DSDT" "$WORK/dsdt.dat" || refuse "couldn't copy the DSDT"
(cd "$WORK" && iasl -d dsdt.dat >iasl.log 2>&1) && [[ -s "$WORK/dsdt.dsl" ]] \
    || refuse "iasl couldn't disassemble the DSDT"

if ! summary="$(python3 -I "$HERE/dsdt-fan-config.py" --dsl "$WORK/dsdt.dsl" \
        --product "$product" --out "$WORK/config.h" 2>&1)"; then
    refuse "this firmware's fan method isn't one galaxybook-fan knows ($(tail -1 <<< "$summary"))"
fi
if [[ "$summary" == *"fix not needed"* && $FORCE -eq 0 ]]; then
    refuse "this firmware's fan method is already correct - the stock acpi-fan driver should work, so the fix isn't needed"
fi

mv -f "$WORK/config.h" "$OUT" || refuse "couldn't write ${OUT}"
echo "galaxybook-fan: config generated from this machine's DSDT:"
sed 's/^/  /' <<< "$summary"
