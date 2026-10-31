#!/bin/bash
# =============================================================================
# galaxybook-fan - build the .rpm from this checkout
# =============================================================================
#   bash packaging/rpm/build.sh [RELEASE]      (RELEASE: rpm Release number, default 1)
#
# Packages the checkout as it is now (tracked and new files, not ignored ones).
# The .rpm (noarch: one for Fedora 44 and 45) is written to packaging/out/.
# Needs: sudo dnf install rpm-build systemd-rpm-macros
# =============================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
OUT="$REPO/packaging/out"
TOP="$OUT/rpmbuild"
VERSION=$(tr -d '[:space:]' < "$REPO/VERSION")

command -v rpmbuild >/dev/null || { echo "rpmbuild not found: sudo dnf install rpm-build systemd-rpm-macros" >&2; exit 1; }
rm -rf "$TOP"
mkdir -p "$TOP/SOURCES"
# Source tarball: the files git knows about (tracked or new), as they are now
( cd "$REPO" && git ls-files -co --exclude-standard -z \
    | tar --null -T - --transform "s,^,galaxybook-fan-${VERSION}/," -czf "$TOP/SOURCES/galaxybook-fan-${VERSION}.tar.gz" )
bash "$REPO/packaging/pre-script.sh" > "$TOP/SOURCES/pre.sh"

# shellcheck disable=SC2086  # RPMBUILD_OPTS: extra rpmbuild options, word-split on purpose
rpmbuild -bb ${RPMBUILD_OPTS:-} --define "_topdir $TOP" \
    --define "gbver $VERSION" --define "rel ${1:-1}" --define "prescript $TOP/SOURCES/pre.sh" \
    "$HERE/galaxybook-fan.spec"
for f in "$TOP"/RPMS/*/*.rpm; do
    cp "$f" "$OUT/"
    echo "Built: $OUT/$(basename "$f")"
done
