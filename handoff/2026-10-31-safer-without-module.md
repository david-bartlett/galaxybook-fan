# Safer when the module isn't loaded

PR #22 · Claude · 2026-10-31

## What changed
- **acpi-fan is only unbound while `galaxybook_fan` is loaded.** The unit runs `After=systemd-modules-load.service` with `ConditionPathIsDirectory=/sys/module/galaxybook_fan`. `package-scripts.sh configure`, `galaxybook-fan rebuild` and `install.sh` (in `verify`, after `modprobe`) unbind only after loading it, and stop the unit and rebind (`gbfan_bind_acpi_fan`) when it doesn't load. New helpers in `lib/fan-dkms.sh`.
- **DSDT override:** `gbfan_dsdt_overridden` + `GBFAN_OVERRIDE_MSG` in `lib/models.sh` (kernel log `Table Upgrade: override [DSDT`, from `journalctl -k -b` and `dmesg`; `GBFAN_KLOG` for tests). Checked by `gen-config.sh` (#error), `install.sh`, the check script and the login monitor (new step 0, sourcing `models.sh` beside `fanpaths.sh`).
- **Headers:** `gbfan_headers_cmd KVER` (pacman pkgbase, apt, dnf). `configure` names the package when the build failed for lack of headers; `rebuild` skips such kernels with the same hint. Arch's own hint in `.install` is gone (configure does it for every format).
- README (unbind only while loaded, override guard, headers, immutable distros, fanspeed-fix-cpio), PLAN.md (§4 map, §9 safety), packaging README, CHANGELOG.

## Why
- David asked what could go wrong with the DKMS approach. The unbind ran even when our module wasn't loaded, so wherever the stock driver works the user lost the fan sensor: the Arch package on a non-Book 5 Samsung (pacman can't refuse), anyone still on the old fanspeed-fix-cpio override (its DSDT looks "fixed", so nothing is built), fixed firmware, `--force`.

## Tested
- Here: `gen-config.sh` with a fake 940XHA DMI and a kernel log with/without the override (refuses with the reason / carries on); the built check script with the override (stops with the message, exit 1); the deb installed (no headers for this kernel: names `linux-headers-<kver>`, apt finishes); the monitor with/without the override; `rebuild` without headers; rpm builds; `bash -n`, `dash -n` on templates, shellcheck.
- Not tested: on the laptop (the unit's ordering and condition at real boot, a real override, a real unbind/rebind), anywhere with a working stock driver.

## For the next person
- Existing installs get the new unit with the package upgrade or `install.sh`.
