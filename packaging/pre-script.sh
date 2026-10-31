#!/bin/bash
# =============================================================================
# galaxybook-fan - the packages' pre-install step (rpm %pre, deb preinst)
# =============================================================================
#   bash packaging/pre-script.sh   → the script on stdout (bash)
#
# The package's files aren't on disk when it runs, so everything it needs is
# built in here: the clone-layout paths (lib/fanpaths.sh), the DKMS helpers
# (lib/fan-dkms.sh) and the install.sh copy's removal (lib/clone-remove.sh,
# the same steps uninstall.sh runs), then packaging/files/pkg-pre.sh.in: the
# Galaxy Book 5 check, and replacing an install.sh copy.
# =============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"

strip() { grep -v -e '^# shellcheck' -e '^#!' "$1"; }

echo '# --- galaxybook-fan pre-install (built by packaging/pre-script.sh) ---'
echo 'GBFAN_LAYOUT=clone'
strip "$REPO/lib/fanpaths.sh"
strip "$REPO/lib/fan-dkms.sh"
strip "$REPO/lib/clone-remove.sh"
cat <<'EOS'
info() { echo "galaxybook-fan: $*"; }
ok()   { echo "galaxybook-fan: $*"; }
warn() { echo "galaxybook-fan: WARNING: $*" >&2; }
EOS
bash "$HERE/render.sh" package pkg-pre.sh.in
