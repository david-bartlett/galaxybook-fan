#!/bin/bash
# =============================================================================
# galaxybook-fan - fill in a file from packaging/files/ for one layout
# =============================================================================
#   bash packaging/render.sh clone|package TEMPLATE   → the file on stdout
#
# Templates name paths as @CHECK_SCRIPT@, @MONITOR_SVC@ and so on; the values
# come from lib/fanpaths.sh, so install.sh (clone) and the packages (package)
# install the same scripts and units, each with its own paths. Same idea as
# fingerprint-fix-sdcp's packaging/render.sh.
# =============================================================================
set -euo pipefail
shopt -u patsub_replacement 2>/dev/null || true     # bash 5.2: keep '&' literal

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ $# -eq 2 && ( "$1" == clone || "$1" == package ) ]] \
    || { echo "Usage: bash $0 clone|package TEMPLATE" >&2; exit 2; }
GBFAN_LAYOUT="$1"
# shellcheck source=../lib/fanpaths.sh
. "$HERE/../lib/fanpaths.sh"
# shellcheck source=../lib/models.sh
. "$HERE/../lib/models.sh"
BOOK5_MODELS_LIST="${BOOK5_MODELS[*]}"
GBFAN_CMD_CLONE="/usr/local/sbin/galaxybook-fan"   # an install.sh copy, for the packages' check
TPL="$HERE/files/$2"
[[ -f "$TPL" ]] || { echo "render.sh: no template $TPL" >&2; exit 1; }

VARS=(PKG_NAME MOD_NAME WRITTEN_BY CHECK_SCRIPT USER_CHECK_SCRIPT MONITOR_SVC
      USER_CHECK_SVC USER_CHECK_TIMER STATE_FILE STATUS_FILE MODLOAD_CONF
      SESSION_TARGET_NAME SESSION_HELPER_SCRIPT GBFAN_LIBDIR GBFAN_CMD
      BOOK5_MODELS_LIST FORCE_FLAG GBFAN_CMD_CLONE UPDATES_OFF UPDATE_CHECK_SVC
      UPDATE_CHECK_TIMER UPDATE_CHECK_SCRIPT)

text="$(<"$TPL")"
for v in "${VARS[@]}"; do
    text="${text//"@${v}@"/"${!v}"}"
done
if left=$(grep -o '@[A-Z][A-Z_]*@' <<< "$text" | sort -u | tr '\n' ' ') && [[ -n "$left" ]]; then
    echo "render.sh: $2 still has unknown names: $left" >&2
    exit 1
fi
printf '%s\n' "$text"
