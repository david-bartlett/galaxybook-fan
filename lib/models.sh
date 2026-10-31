# shellcheck shell=bash
# =============================================================================
# galaxybook-fan - which laptops it's for. The one place this list lives:
# install.sh, DKMS's gen-config.sh, the packages' pre-install step and the
# login monitor source it, and check-galaxybook-fan.sh has a copy built in at
# release time (tools/build-check-script.sh). Also the DSDT-override check,
# for the same reason: it has to reach all of those.
#
# BOOK5_MODELS     the Galaxy Book 5 series (same list as fnkeys-fix-book5).
#                  The DSDT check still decides for each machine.
# CONFIRMED_MODELS models someone has run the fix on and reported working.
#                  When a "Works on my model" issue confirms a new one, add it
#                  here AND to the confirmed-models table in README.md.
# =============================================================================

BOOK5_MODELS=("940XHA" "960XHA" "960QHA" "750XHD" "754XHD" "750QHA" "754QHA")
CONFIRMED_MODELS=("940XHA")

# The model as these lists spell it: upper-case, without a leading "NP"
# (the DMI product name is e.g. "940XHA" or "NP940XHA").
gbfan_model() {
    local m="${1^^}"
    printf '%s\n' "${m#NP}"
}

# Is this laptop booting with a replacement DSDT - an ACPI table override
# loaded from the initramfs, such as the old fanspeed-fix-cpio? Then
# /sys/firmware/acpi/tables/DSDT is that replacement (usually with _FST
# already patched), not the laptop's own firmware, so nothing here can tell
# what the firmware does: the parser would call it "already fixed". The
# kernel logs "ACPI: Table Upgrade: override [DSDT-...]" at boot.
# GBFAN_KLOG: a file to read instead of the kernel log, for testing.
gbfan_dsdt_overridden() {
    local log
    if [[ -n "${GBFAN_KLOG:-}" ]]; then
        log="$(cat "$GBFAN_KLOG" 2>/dev/null)"
    else
        log="$( { journalctl -k -b -o cat; dmesg; } 2>/dev/null )"
    fi
    [[ "$log" == *"Table Upgrade: override [DSDT"* ]]
}
GBFAN_OVERRIDE_MSG="this laptop boots with a replacement DSDT (an ACPI table override, such as the old fanspeed-fix-cpio), so its own firmware can't be read. Remove the override and reboot, then run: sudo galaxybook-fan rebuild"

# gbfan_in_list MODEL LIST... - true if MODEL is one of LIST
gbfan_in_list() {
    local want="$1" m; shift
    for m in "$@"; do [[ "$m" == "$want" ]] && return 0; done
    return 1
}
