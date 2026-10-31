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

# The registered version, e.g. 0.4.0 (empty if none)
gbfan_dkms_version() {
    local d
    for d in /var/lib/dkms/"$PKG_NAME"/*/; do
        d="$(basename "$d")"
        [[ "$d" =~ ^[0-9][0-9.]*$ ]] && { echo "$d"; return 0; }
    done
    return 1
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
