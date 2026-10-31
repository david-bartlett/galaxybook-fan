#!/bin/bash
# =============================================================================
# galaxybook-fan - build the .deb from this checkout
# =============================================================================
#   bash packaging/debian/build.sh [REVISION]    (REVISION: Debian revision, default 1)
#
# Packages the checkout as it is now (tracked and new files, not ignored ones).
# One .deb (Architecture: all) for Ubuntu 24.04 / 26.04, Mint, Debian 13 and
# MX 25: it ships the module's source and DKMS builds it on the laptop, so
# nothing in it depends on the release it was built on. Written to
# packaging/out/.
# Needs: sudo apt install build-essential debhelper
# =============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="$REPO/packaging/out"
WORK="$OUT/debbuild"
VERSION=$(tr -d '[:space:]' < "$REPO/VERSION")
DEBVER="$VERSION-${1:-1}"

if ! command -v dpkg-buildpackage >/dev/null || ! command -v dh >/dev/null; then
    echo "dpkg-buildpackage or debhelper not found: sudo apt install build-essential debhelper" >&2
    exit 1
fi
rm -rf "$WORK"
mkdir -p "$WORK"

# Source tree: the files git knows about (tracked or new), as they are now,
# with this folder as debian/
TREE="$WORK/galaxybook-fan-$VERSION"
mkdir -p "$TREE"
( cd "$REPO" && git ls-files -co --exclude-standard -z | grep -zv '^packaging/out/' \
    | tar --null -T - -cf - ) | tar -xf - -C "$TREE"
mkdir -p "$TREE/debian"
cp -a "$HERE"/{control,rules,copyright,source} "$HERE"/galaxybook-fan.* "$TREE/debian/"

# The pre-install step (Galaxy Book 5 check, replacing an install.sh copy)
# goes in at preinst's #@PRE_SCRIPT@ line
bash "$REPO/packaging/pre-script.sh" > "$WORK/pre.sh"
sed -i -e "/^#@PRE_SCRIPT@\$/{r $WORK/pre.sh" -e 'd}' "$TREE/debian/galaxybook-fan.preinst"

cat > "$TREE/debian/changelog" <<EOF
galaxybook-fan ($DEBVER) unstable; urgency=medium

  * galaxybook-fan $VERSION.
    See /usr/share/doc/galaxybook-fan/CHANGELOG.md.gz.

 -- David Bartlett <22402006+david-bartlett@users.noreply.github.com>  $(date -R)
EOF

( cd "$TREE" && dpkg-buildpackage -b -us -uc )
for f in "$WORK"/*.deb; do
    cp "$f" "$OUT/"
    echo "Built: $OUT/$(basename "$f")"
done
