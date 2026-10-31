# shellcheck shell=bash
# =============================================================================
# galaxybook-fan - which laptops it's for. The one place this list lives:
# install.sh sources it, and check-galaxybook-fan.sh has a copy built in at
# release time (tools/build-check-script.sh). The packages will use it too
# (PLAN.md §10).
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

# gbfan_in_list MODEL LIST... - true if MODEL is one of LIST
gbfan_in_list() {
    local want="$1" m; shift
    for m in "$@"; do [[ "$m" == "$want" ]] && return 0; done
    return 1
}
