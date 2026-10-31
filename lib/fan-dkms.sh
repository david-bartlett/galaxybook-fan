# shellcheck shell=bash
# =============================================================================
# galaxybook-fan - DKMS helpers shared by install.sh, uninstall.sh and the
# galaxybook-fan command. Source lib/fanpaths.sh first; needs info/warn.
# =============================================================================

# Every registered version, removed in the module/version form current DKMS
# expects. /var/lib/dkms/<pkg>/<version> holds one dir per version.
gbfan_dkms_remove_all() {
    local d v
    [[ -d /var/lib/dkms/$PKG_NAME ]] || return 0
    for d in /var/lib/dkms/"$PKG_NAME"/*/; do
        v="$(basename "$d")"
        [[ -L "${d%/}" || "$v" == kernel-* || "$v" == "source" || "$v" == "*" ]] && continue
        info "Removing ${PKG_NAME}/${v} from DKMS"
        dkms remove "${PKG_NAME}/${v}" --all || true
    done
    # Anything DKMS couldn't remove (half-added tree, etc.)
    rm -rf /var/lib/dkms/"$PKG_NAME"
}

# Unload galaxybook_fan if it's loaded. modprobe -r looks the module up in
# the kernel's module index, so it fails once the module's file is gone -
# Arch's DKMS hook removes it from DKMS before the package's own removal step
# runs - while rmmod only needs the loaded module. Returns 1 if it stays loaded.
gbfan_unload() {
    [[ -d /sys/module/$MOD_NAME ]] || return 0
    modprobe -r "$MOD_NAME" 2>/dev/null || rmmod "$MOD_NAME" 2>/dev/null
    [[ ! -d /sys/module/$MOD_NAME ]]
}

# The stock acpi-fan driver and the fan: unbound only while galaxybook_fan is
# loaded and reading it, bound again otherwise. Where the stock driver works
# (an earlier Galaxy Book, firmware that's fixed, a DSDT override) and our
# module isn't loaded, unbinding it would leave no fan sensor at all.
# galaxybook-acpi-fan-unbind.service follows the same rule at boot.
gbfan_unbind_acpi_fan() {
    local dev
    [[ -d /sys/module/$MOD_NAME ]] || return 1
    for dev in "$ACPI_FAN_DRV"/PNP0C0B:*; do
        [[ -e "$dev" ]] || continue
        echo "$(basename "$dev")" > "$ACPI_FAN_DRV/unbind" 2>/dev/null || true
    done
}
gbfan_bind_acpi_fan() {
    local dev name
    for dev in /sys/bus/platform/devices/PNP0C0B:*; do
        [[ -e "$dev" ]] || continue
        name="$(basename "$dev")"
        [[ -e "$ACPI_FAN_DRV/$name" ]] || echo "$name" > "$ACPI_FAN_DRV/bind" 2>/dev/null || true
    done
}

# How to install the headers DKMS needs for KERNEL (empty if unknown): each
# distro names them after the kernel; on Arch each kernel package records its
# own name (linux, linux-lts, linux-cachyos, ...) in its module folder.
gbfan_headers_cmd() {
    local k="$1" base
    if [[ -r "/usr/lib/modules/$k/pkgbase" ]] && command -v pacman >/dev/null 2>&1; then
        base="$(cat "/usr/lib/modules/$k/pkgbase")"
        echo "sudo pacman -S ${base}-headers"
    elif command -v dpkg-query >/dev/null 2>&1; then
        echo "sudo apt install linux-headers-$k"
    elif command -v dnf >/dev/null 2>&1; then
        echo "sudo dnf install kernel-devel-$k"
    fi
}
gbfan_has_headers() { [[ -e "/lib/modules/$1/build" ]]; }

# Some distros (Fedora) rebuild every kernel's initramfs after each DKMS
# operation (post_transaction). galaxybook_fan is never in the initramfs, so
# suspend that for our own DKMS steps; gbfan_dkms_resume_initramfs (run it from
# an EXIT trap) puts DKMS's own setting back.
gbfan_dkms_defer_initramfs() {
    if grep -qs '^[[:space:]]*post_transaction=' /etc/dkms/framework.conf \
            || grep -rqs '^[[:space:]]*post_transaction=' /etc/dkms/framework.conf.d/; then
        mkdir -p "$(dirname "$DKMS_DEFER_CONF")"
        echo 'post_transaction=""' > "$DKMS_DEFER_CONF"
        info "DKMS's initramfs rebuild suspended while building (galaxybook_fan isn't in the initramfs)"
    fi
}
gbfan_dkms_resume_initramfs() { rm -f "$DKMS_DEFER_CONF"; }

# The registered version, e.g. 0.4.0 (empty if none): the installed copy's
# own (its VERSION file) when DKMS has it, else the newest DKMS lists - not
# just the first, which could be an old one left behind
gbfan_dkms_version() {
    local d v="" list=()
    [[ -r "${GBFAN_LIBDIR:-}/VERSION" ]] && v="$(tr -d '[:space:]' < "$GBFAN_LIBDIR/VERSION")"
    [[ -n "$v" && -d /var/lib/dkms/$PKG_NAME/$v ]] && { echo "$v"; return 0; }
    for d in /var/lib/dkms/"$PKG_NAME"/*/; do
        d="$(basename "$d")"
        [[ "$d" =~ ^[0-9][0-9.]*$ ]] && list+=("$d")
    done
    (( ${#list[@]} )) || return 1
    printf '%s\n' "${list[@]}" | sort -V | tail -1
}

# gbfan_dkms_forget VERSION - if DKMS couldn't remove VERSION (its source in
# /usr/src already gone), take its entry out of /var/lib/dkms by hand, with
# the kernel-* links that point into it
gbfan_dkms_forget() {
    local v="$1" l
    [[ -n "$v" && -d /var/lib/dkms/$PKG_NAME/$v ]] || return 0
    for l in /var/lib/dkms/"$PKG_NAME"/kernel-*; do
        [[ -L "$l" && "$(readlink "$l")" == *"$v/"* ]] && rm -f "$l"
    done
    rm -rf "/var/lib/dkms/$PKG_NAME/$v"
}

# Kernels galaxybook_fan is currently built for
gbfan_dkms_kernels() {
    local v="$1"
    dkms status -m "$PKG_NAME" -v "$v" 2>/dev/null \
        | sed -n -E 's#^[^,]*, *([^,]*), *[^:]*: *(built|installed).*#\1#p' | sort -u
}

# Why a build failed: module/gen-config.sh puts its reason in an #error line,
# which ends up in DKMS's make.log
gbfan_dkms_build_reason() {
    local v="$1" log
    log="/var/lib/dkms/${PKG_NAME}/${v}/build/make.log"
    [[ -f "$log" ]] || return 1
    grep -o 'galaxybook-fan: [^"]*' "$log" | head -1
}

# Build and install VERSION for KERNEL from scratch, so module/gen-config.sh
# reads the firmware again (after a BIOS update). Returns dkms's status.
gbfan_dkms_rebuild_kernel() {
    local v="$1" k="$2"
    dkms remove -m "$PKG_NAME" -v "$v" -k "$k" >/dev/null 2>&1 || true
    [[ -d /var/lib/dkms/$PKG_NAME/$v ]] || dkms add -m "$PKG_NAME" -v "$v" >/dev/null || return 1
    dkms install -m "$PKG_NAME" -v "$v" -k "$k"
}
