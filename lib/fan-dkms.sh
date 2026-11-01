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
# the kernel-* links that point into it (DKMS's "installed for this kernel").
# Prints those kernels, one per line, so the new version can be installed
# for them.
gbfan_dkms_forget() {
    local v="$1" l t
    [[ -n "$v" && -d /var/lib/dkms/$PKG_NAME/$v ]] || return 0
    for l in /var/lib/dkms/"$PKG_NAME"/kernel-*; do
        [[ -L "$l" ]] || continue
        t="$(readlink "$l")"                 # e.g. 0.5.0/7.2.10-2-liquorix-amd64/x86_64
        [[ "$t" == "$v/"* ]] || continue
        t="${t#"$v"/}"; echo "${t%%/*}"
        rm -f "$l"
    done
    rm -rf "/var/lib/dkms/$PKG_NAME/$v"
}

# gbfan_dkms_install VERSION KERNEL - 'dkms install', its output on stdout.
# If DKMS refuses because a galaxybook_fan module file no DKMS version owns
# is already there ("Module <file> already installed (unversioned module)",
# Debian 13's DKMS: an old version DKMS couldn't remove, see
# gbfan_dkms_forget), that file is an old copy of this module: remove it and
# try once more. Looked for in the output whatever DKMS returns: MX's dkms
# wrapper adds every kernel to each install, refuses some and still returns 0
# - so the files can be for other kernels too.
gbfan_dkms_install() {
    local v="$1" k="$2" out rc f dk removed=0
    out="$(dkms install -m "$PKG_NAME" -v "$v" -k "$k" 2>&1)"; rc=$?
    while read -r f; do
        # only this module's own file, in a kernel's module folder
        [[ "$f" == /lib/modules/*/"$MOD_NAME".ko* && -f "$f" ]] || continue
        rm -f "$f" && removed=1
    done < <(sed -n -E 's#.*Module (/lib/modules/[^ ]+) already installed \(unversioned module\).*#\1#p' <<<"$out")
    if (( removed )); then
        out="$(dkms install -m "$PKG_NAME" -v "$v" -k "$k" 2>&1)"; rc=$?
    fi
    # DKMS can record the new version as installed without its module file
    # being in place: DKMS 3.0 (Mint 22, Ubuntu 24.04) keeps an old version's
    # file it takes for the same module ("exactly matches ... will not
    # replace": galaxybook_fan has no version of its own); DKMS 3.2 (Ubuntu
    # 26.04), after the "unversioned module" retry above, recorded it
    # installed and copied nothing, so there was no file at all. 'dkms status'
    # then says "Diff between built and installed module" (3.0) or
    # "Differences between built and installed modules" (3.2). Put the new
    # file in place with --force for each such kernel, and for any it calls
    # installed with no module file there.
    while read -r dk; do
        out+=$'\n'"$(dkms install --force -m "$PKG_NAME" -v "$v" -k "$dk" 2>&1)" || rc=$?
    done < <(gbfan_dkms_not_in_place "$v")
    [[ -n "$out" ]] && printf '%s\n' "$out"
    return $rc
}

# gbfan_dkms_not_in_place VERSION - kernels DKMS calls VERSION installed for
# whose module file isn't really there: its "Diff(erences) between built and
# installed" warning, or no galaxybook_fan module file in the kernel's
# updates/dkms (or extra) folder
gbfan_dkms_not_in_place() {
    local line k f found
    while IFS= read -r line; do
        [[ "$line" =~ ^[^,]*,\ *([^,]+),\ *[^:]*:\ *installed ]] || continue
        k="${BASH_REMATCH[1]}"
        if [[ "$line" =~ Diff(erences)?\ between\ built\ and\ installed ]]; then
            echo "$k"; continue
        fi
        found=0
        for f in /lib/modules/"$k"/updates/dkms/"$MOD_NAME".ko* /lib/modules/"$k"/extra/"$MOD_NAME".ko*; do
            [[ -f "$f" ]] && { found=1; break; }
        done
        (( found )) || echo "$k"
    done < <(dkms status -m "$PKG_NAME" -v "$1" 2>/dev/null) | sort -u
}

# gbfan_dkms_installed_for VERSION KERNEL - is VERSION installed for KERNEL?
gbfan_dkms_installed_for() {
    dkms status -m "$PKG_NAME" -v "$1" -k "$2" 2>/dev/null | grep -q ': installed'
}

# Kernels VERSION is built for but not installed for (e.g. DKMS refused to
# install it over an old version's file)
gbfan_dkms_built_only() {
    dkms status -m "$PKG_NAME" -v "$1" 2>/dev/null \
        | sed -n -E 's#^[^,]*, *([^,]*), *[^:]*: *built( .*)?$#\1#p' | sort -u
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
    gbfan_dkms_install "$v" "$k"
}
