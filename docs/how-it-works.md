# How it works

[← Back to the README](../README.md)

What's wrong with the firmware, how the fix gets round it, when it refuses to build, and what each file is for.

## The problem

Samsung's fan `_FST` method (e.g. `\_SB.PC00.LPCB.FAN0._FST`) does:

```
Local1 = FANT [Local0]      // Index reference, no DerefOf()
Local1 += 0x0A
```

Windows' AML interpreter tolerates this. ACPICA doesn't, so whenever the fan is spinning `_FST` aborts with `AE_AML_OPERAND_TYPE`, and the stock `acpi-fan` driver reports an I/O error instead of a speed.

## The fix

`galaxybook_fan` is a small DKMS hwmon module that reads the same EC field `_FST` reads (`H_EC.FANS`) by asking ACPI for its value. The firmware performs the read exactly as it would for `_FST`, through whichever region the field lives in and with its own locking. The module then applies `_FST`'s level remap and RPM table itself, so only the broken table lookup is bypassed.

Nothing is hardcoded per model. Before every build, DKMS runs `module/gen-config.sh`, which disassembles **this machine's own DSDT** and has `dsdt-fan-config.py` work out:

- which EC field `_FST` reads, and that it's defined exactly once in a plain readable region (the 940XHA reads it through `ECR`, a SystemMemory window onto the EC's RAM)
- how `_FST` remaps the raw value to a fan level (its `Switch`/`Case` table)
- the RPM table (`FANT`) and offset

The results go into `galaxybook_fan_config.h` for that build, so each new kernel, and a rebuild after a BIOS update, uses the firmware as it is then.

On the Galaxy Book 5 Pro (940XHA) that gives:

| `FANS` value | Fan speed |
|---|---|
| 0 | 0 RPM (off) |
| 1 | 3510 RPM |
| 2 | 3820 RPM |
| 3, 4 | 4430 RPM |
| 5 | 4740 RPM |

These are Samsung's own table values, so the speed is stepped, exactly as Windows reports it. The EC doesn't expose a measured RPM.

The fix also enables `galaxybook-acpi-fan-unbind.service`, which unbinds the stock `acpi-fan` driver early in boot, **only once `galaxybook_fan` has loaded**. That removes the dead "Fan 0" sensor and the AML errors in dmesg. When the module isn't loaded (not built, waiting for its signing key, a laptop it refused), the fan stays with the stock driver, in case that works there. The fan has no ACPI control methods, so the cooling device `acpi-fan` registers does nothing anyway.

Nothing is added to the boot chain: there's no DSDT override and no initrd change, so a BIOS update can't make the laptop unbootable.

## Guards

`dsdt-fan-config.py` never guesses. It refuses, and the module isn't built, if:

- there isn't exactly one `PNP0C0B` fan device with an `_FST` method
- `_FST` contains any statement outside the known shape (extra maths, another EC read, `Case (Package …)`, `Default`, loops, calls…), or its statements aren't in the known order (a statement repeated or moved), or it stores anywhere but the speed and level slots of the package it returns (into the RPM table, another package, or over the speed once it's set), or that package isn't a plain `Package` of its own (an `Alias` makes it, or the table, another name for something else), or either isn't declared in the fan device itself (a table in a parent or a nested device could be a different object from the one `_FST` reads)
- the EC field isn't defined exactly once, is wider than 8 bits, or is in anything other than an EmbeddedControl, SystemMemory or SystemIO region
- the RPM table is missing, defined more than once, the wrong length, or gives a speed outside 500–20000 RPM
- the laptop boots with a **replacement DSDT** (an ACPI table override loaded from the initramfs, such as the old `fanspeed-fix-cpio`): the table in memory is then the override, not the laptop's own firmware. Remove the override and reboot, then `sudo galaxybook-fan rebuild`

`sudo galaxybook-fan check` (or `sudo ./install.sh --check`) shows why. `install.sh` also saves the disassembled DSDT to `/tmp/galaxybook-fan-dsdt.dsl`, and refuses to install.

The module also checks itself at load time, and refuses to load unless both of these match what the config was generated from:

- the DMI product name
- the DSDT's OEM ID, table ID and revision

So after a **BIOS update** the fan sensor disappears, and you're told to run `sudo galaxybook-fan rebuild`, instead of a changed `_FST` or RPM table producing wrong readings. At load it also checks that the field exists and can be read.

## Initramfs

`galaxybook_fan` loads after boot from `modules-load.d`, so it never needs to be in the initramfs. Some distros (Fedora) set DKMS's `post_transaction` to rebuild **every** kernel's initramfs after each DKMS operation, which takes a minute or two. Like fnkeys-fix-book5, `install.sh`, `uninstall.sh`, the `galaxybook-fan` command and the packages suspend that for their own DKMS steps with a temporary drop-in (`/etc/dkms/framework.conf.d/zz-galaxybook-fan-defer-initramfs.conf`), which a trap removes when the script exits, even on failure. DKMS's own setting is never changed. On dracut systems, `galaxybook-fan.conf` (`omit_drivers`; in `/etc/dracut.conf.d/` from `install.sh`, `/usr/lib/dracut/dracut.conf.d/` from a package) also keeps the module out of future initramfs images. If an old copy is already in the running kernel's initramfs, only that one image is rebuilt.

## Files

<details>
<summary>What each file in this repository is for</summary>

| File | Purpose |
|---|---|
| `install.sh` / `uninstall.sh` | [install](installing.md) and [remove](../README.md#uninstall) the fix |
| `module/gen-config.sh` | DKMS's `PRE_BUILD`: writes the module's config from this machine's DSDT before every build |
| `lib/galaxybook-fan` | the `galaxybook-fan` command |
| `packaging/` | the rpm, deb and Arch packaging, and the units and scripts shared by `install.sh` and the packages ([packaging/README.md](../packaging/README.md)) |
| `lib/package-scripts.sh` | what every package runs after installing and before removing |
| `lib/clone-remove.sh` | removes a copy installed with `install.sh` (`uninstall.sh`, and the packages when they replace one) |
| `.github/workflows/release.yml` | builds the packages on every pull request, and for a release attaches them with the check script |
| `lib/fanpaths.sh`, `lib/fan-dkms.sh` | names, paths and DKMS steps shared by `install.sh`, `uninstall.sh`, the packages, the command and the login check |
| `tools/check-galaxybook-fan.sh` | the read-only "will it work on my laptop?" check; each release attaches a single-file copy built by `tools/build-check-script.sh` |
| `lib/models.sh` | the Galaxy Book 5 models, and the ones confirmed working |
| `LICENSE` | GPL-2.0, the same licence as the module |
| `module/galaxybook_fan.c` | the module |
| `module/galaxybook_fan_config.h` | default config (940XHA), so the module builds by hand from the repository; never copied to `/usr/src`, where `gen-config.sh` writes one for each build |
| `module/Makefile`, `module/dkms.conf` | the module's build and DKMS definition |
| `lib/dsdt-fan-config.py` | derives and validates the config from a disassembled DSDT; `--status` reports whether `_FST` still has the bug |
| `lib/samsung-galaxybook-fan-check.sh` | the native test and the login-time monitor logic |
| `VERSION` | the release version (David's release tool keeps `module/dkms.conf` and `install.sh` in step with it) |
| `CHANGELOG.md` | what changed in each release |
| `PLAN.md`, `AGENTS.md`, `handoff/` | how the project works and how to contribute (changes go in as pull requests) |

</details>
