#!/bin/bash
# =============================================================================
# build-check-script.sh - make the single-file check-galaxybook-fan.sh that is
# attached to each release.
#
#   bash tools/build-check-script.sh OUTPUT [VERSION]
#
# Copies tools/check-galaxybook-fan.sh with lib/models.sh and
# lib/dsdt-fan-config.py built in at its "#@EMBED@" line, so the release copy
# runs on its own and makes exactly the checks the installer makes. The
# release workflow runs this; it's also handy for testing.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
out="${1:?Usage: bash tools/build-check-script.sh OUTPUT [VERSION]}"
version="${2:-$(tr -d '[:space:]' < VERSION)}"
delim="GBFAN_PARSER_END_OF_FILE"

src=tools/check-galaxybook-fan.sh
[[ $(grep -c '^#@EMBED@' "$src") -eq 1 ]] || { echo "No single #@EMBED@ line in $src" >&2; exit 1; }
! grep -qx "$delim" lib/dsdt-fan-config.py || { echo "The parser contains $delim" >&2; exit 1; }

{
    sed -n '1,/^#@EMBED@/p' "$src" | sed '$d'
    echo "# ---- built in by tools/build-check-script.sh (galaxybook-fan ${version}) ----"
    echo "GBFAN_EMBEDDED=1"
    echo "GBFAN_VERSION=\"${version}\""
    echo "# lib/models.sh"
    grep -v '^# shellcheck' lib/models.sh
    echo "# lib/dsdt-fan-config.py"
    echo "GBFAN_PARSER=\"\$(cat <<'${delim}'"
    cat lib/dsdt-fan-config.py
    echo "${delim}"
    echo ")\""
    echo "# ---- end of built-in part ----"
    sed -n '/^#@EMBED@/,$p' "$src" | sed '1d'
} > "$out"
chmod 755 "$out"
bash -n "$out"
echo "Wrote $out (galaxybook-fan ${version})"
