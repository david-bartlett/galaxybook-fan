# galaxybook-fan

Fan speed reporting for Samsung Galaxy Book laptops on Linux, without a DSDT override.

## The problem

Samsung's fan `_FST` method (e.g. `\_SB.PC00.LPCB.FAN0._FST`) does:

```
Local1 = FANT [Local0]      // Index reference, no DerefOf()
Local1 += 0x0A
```

Windows' AML interpreter tolerates this. ACPICA doesn't, so whenever the fan is spinning `_FST` aborts with `AE_AML_OPERAND_TYPE`, and the stock `acpi-fan` driver reports an I/O error instead of a speed.

## The fix

`galaxybook_fan` is a small DKMS hwmon module that reads the same EC field `_FST` reads (`H_EC.FANS`) by asking ACPI for its value. The firmware performs the read exactly as it would for `_FST`, through whichever region the field lives in and with its own locking. The module then applies `_FST`'s level remap and RPM table itself, so only the broken table lookup is bypassed.

Nothing is hardcoded per model. The installer disassembles **this machine's own DSDT** and `dsdt-fan-config.py` works out:

- which EC field `_FST` reads, and that it's defined exactly once in a plain readable region (the 940XHA reads it through `ECR`, a SystemMemory window onto the EC's RAM)
- how `_FST` remaps the raw value to a fan level (its `Switch`/`Case` table)
- the RPM table (`FANT`) and offset

The results are baked into `galaxybook_fan_config.h` before DKMS builds the module.

On the Galaxy Book 5 Pro (940XHA) that gives:

| `FANS` value | Fan speed |
|---|---|
| 0 | 0 RPM (off) |
| 1 | 3510 RPM |
| 2 | 3820 RPM |
| 3, 4 | 4430 RPM |
| 5 | 4740 RPM |

These are Samsung's own table values, so the speed is stepped, exactly as Windows reports it. The EC doesn't expose a measured RPM.

The installer also enables `galaxybook-acpi-fan-unbind.service`, which unbinds the stock `acpi-fan` driver early in boot. That removes the dead "Fan 0" sensor and the AML errors in dmesg. The fan has no ACPI control methods, so the cooling device `acpi-fan` registers does nothing anyway.

Nothing is added to the boot chain: there's no DSDT override and no initrd change, so a BIOS update can't make the laptop unbootable.

## Guards

`dsdt-fan-config.py` never guesses. It refuses, and nothing is installed, if:

- there isn't exactly one `PNP0C0B` fan device with an `_FST` method
- `_FST` contains any statement outside the known shape (extra maths, another EC read, `Case (Package …)`, `Default`, loops, calls…)
- the EC field isn't defined exactly once, is wider than 8 bits, or is in anything other than an EmbeddedControl, SystemMemory or SystemIO region
- the RPM table is missing, defined more than once, the wrong length, or gives a speed outside 500–20000 RPM

On failure, the disassembled DSDT is saved to `/tmp/galaxybook-fan-dsdt.dsl` so you can see why.

The module also checks itself at load time, and refuses to load unless both of these match what the config was generated from:

- the DMI product name
- the DSDT's OEM ID, table ID and revision

So after a **BIOS update** the fan sensor disappears, and dmesg tells you to re-run `install.sh`, instead of a changed `_FST` or RPM table producing wrong readings. At load it also checks that the field exists and can be read.

## Is the fix still needed?

The installer adds a login-time check, the same pattern as fingerprint-fix-sdcp and fnkeys-fix-book5. Ten seconds after login, a user timer checks whether the kernel or BIOS version has changed since the last check, or whether the module isn't loaded. If so, it starts a root monitor service (allowed by a polkit rule), which works out what happened and notifies you:

| What changed | What the monitor does | You'll be told |
|---|---|---|
| BIOS update that fixed `_FST` (the table lookup now uses `DerefOf`) | Parses the new DSDT | The fix is no longer needed; run `uninstall.sh` |
| BIOS update, `_FST` still broken | Module has paused itself (DSDT changed) | Re-run `install.sh` to re-derive for the new firmware (repeated at each login until you do) |
| BIOS update that rewrote `_FST` beyond recognition | — | Run `install.sh --test-native` to check |
| New kernel, module not loaded | — | The DKMS build probably failed; re-run `install.sh` |
| New kernel | Briefly binds the stock `acpi-fan` driver while the fan is spinning and reads it | If it works: the kernel now handles the fan, so run `uninstall.sh` |

The native test is only conclusive while the fan is running, because the broken code path is only reached then. The monitor waits up to a minute for that. If the fan stays off, it quietly tries again at the next login.

Nothing is installed or removed automatically: the notifications tell you what to run. You can run the same native test yourself at any time:

```bash
sudo ./install.sh --test-native
```

## Supported hardware and kernels

- **Samsung Galaxy Book 5 series only:** `940XHA`, `960XHA`, `960QHA`, `750XHD`, `754XHD`, `750QHA`, `754QHA` (the same list as fnkeys-fix-book5, matched with or without an `NP` prefix). Tested on the 940XHA. On the other Book 5 models, the DSDT check confirms the firmware has the same bug before anything is installed.
- Other Samsung models are refused. Earlier Galaxy Books report fan speed with the stock kernel driver, whose `_FST`-only fan support was written and tested on a Book2 Pro. `--check` and `--test-native` still work on them, and `--force` overrides.
- Non-Samsung machines are always refused.
- **Kernel 6.8 or newer.** The module builds cleanly against 6.8, 6.11, 6.14, 6.17 and 7.0.

### Tested on

All tests were on a Galaxy Book 5 Pro (940XHA, BIOS P10VAJ.390.260522.02, DSDT `SECCSD LH43STAR 0x01072009`), October 2026:

| Distro | Kernel | Desktop | Secure Boot signing | `--check` | Install | `--test-native` | Login check | Uninstall |
|---|---|---|---|---|---|---|---|---|
| Fedora 45 | 7.2.12 | KDE Plasma | akmods key (enrolled) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Ubuntu 26.04.1 LTS | 7.0.0 | GNOME | Ubuntu shim key (enrolled) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Linux Mint 27 (beta) | 7.0.0 | Cinnamon | Ubuntu shim key (enrolled) | ✓ | ✓ | ✓ | ✓ | ✓ |
| MX Linux 25.2 (systemd boot) | 7.2.10 Liquorix | Xfce (session helper) | Secure Boot off | ✓ | ✓ | ✓ | ✓ after a reboot¹ | ✓ |
| CachyOS | 7.2.9 | KDE Plasma | Secure Boot off | ✓ | ✓ | ✓ | ✓ | ✓ |

`--test-native` passing means it correctly reported that the stock `acpi-fan` driver still can't read the fan, so the fix is needed. The firmware bug is the same on every distro.

¹ On MX, a plain log-out and log-in doesn't re-run the login check while Xfce's Print Queue Applet (`system-config-printer`) keeps the old session open. This doesn't matter in practice, because the check only has work to do after a kernel or BIOS update, and those come with a reboot. Turning the applet off under Session and Startup → Application Autostart makes log-outs end cleanly.

Not yet tested on real hardware: the "signing key not enrolled" path (the `mokutil --import` prompt and MokManager after the reboot), and Book 5 models other than the 940XHA.

## Install

```bash
sudo ./install.sh --check    # derive and show the config from your DSDT, install nothing
sudo ./install.sh            # confirmed models (940XHA)
sudo ./install.sh --force    # other models, once --check output looks right
```

The installer:
- installs whatever's missing of: `iasl` (acpica), `python3`, `dkms`, `make`, `gcc`, the kernel headers, `mokutil` (EFI systems), polkit and `notify-send` (the last two can be absent on minimal Debian installs)
- warns if your user isn't in the `wheel` or `sudo` group, because the login check's polkit rule only lets those groups start its monitor
- derives the fan config from the DSDT, as described above
- with Secure Boot on, sorts out module signing (see below)
- installs the module through DKMS, so it rebuilds automatically on kernel updates
- autoloads it via `/etc/modules-load.d/galaxybook_fan.conf`, which is also a good file for checking whether the fix is installed
- enables `galaxybook-acpi-fan-unbind.service`, which unbinds `acpi-fan` at boot
- installs the login-time check described above (plus the shared graphical session helper on desktops that need it, such as Xfce)
- refuses to install if your firmware's `_FST` is already correct, since the stock driver should work then (`--force` overrides)

Re-running `install.sh` over an existing install is fine; there's no need to uninstall first.

### Initramfs

`galaxybook_fan` loads after boot from `modules-load.d`, so it never needs to be in the initramfs. Some distros (Fedora) set DKMS's `post_transaction` to rebuild **every** kernel's initramfs after each DKMS operation, which takes a minute or two. Like fnkeys-fix-book5, both scripts suspend that for their own DKMS steps with a temporary drop-in (`/etc/dkms/framework.conf.d/zz-galaxybook-fan-defer-initramfs.conf`), which a trap removes when the script exits, even on failure. DKMS's own setting is never changed. On dracut systems, `/etc/dracut.conf.d/galaxybook-fan.conf` (`omit_drivers`) also keeps the module out of future initramfs images. If an old copy is already in the running kernel's initramfs, only that one image is rebuilt.

### Secure Boot signing

The installer works out the key DKMS will actually sign with, the same way DKMS does: `/etc/dkms/framework.conf`, then every `/etc/dkms/framework.conf.d/*.conf` in order, falling back to DKMS's own `/var/lib/dkms/mok.*`. That covers Fedora's akmods key (`akmods-keys.conf`), Ubuntu's shim key and plain DKMS keys. On Fedora with nothing configured it uses the akmods key and writes the same `akmods-keys.conf` as Andy's webcam-fix-book5, so all the fixes share one key and one enrolment (that file is shared, so `uninstall.sh` leaves it alone). It only adds its own drop-in (`galaxybook-fan-signing.conf`) when it has to point DKMS somewhere else. After building, it checks that DKMS really signed the module.

| Key state | What happens |
|---|---|
| Enrolled (the configured key, or any standard one) | Signed and loaded straight away |
| Imported but waiting for the next boot | Built and signed anyway; reboot and finish the MokManager screen, and the module loads automatically |
| Exists but not enrolled (e.g. a BIOS update wiped NVRAM) | Offers `mokutil --import` (you set a one-time password), then builds and signs; same reboot step |
| Missing | Generated first (`kmodgenca` for akmods, `update-secureboot-policy` on Ubuntu, otherwise `openssl` like DKMS), then as above |

At the MokManager screen after the reboot: **Enroll MOK → Continue → Yes →** type the password **→ Reboot**. There's no need to re-run the installer afterwards.

## Uninstall

```bash
sudo ./uninstall.sh
```

This removes everything the installer added and rebinds `acpi-fan`. No reboot is needed.

## Files

| File | Purpose |
|---|---|
| `install.sh` / `uninstall.sh` | as above |
| `module/galaxybook_fan.c` | the module |
| `module/galaxybook_fan_config.h` | default config (940XHA), so the module builds standalone; the installer replaces it in `/usr/src` |
| `module/Makefile`, `module/dkms.conf` | the module's build and DKMS definition |
| `lib/dsdt-fan-config.py` | derives and validates the config from a disassembled DSDT; `--status` reports whether `_FST` still has the bug |
| `lib/samsung-galaxybook-fan-check.sh` | the native test and the login-time monitor logic |
| `VERSION` | the release version (David's release tool keeps `module/dkms.conf` and `install.sh` in step with it) |
| `CHANGELOG.md` | what changed in each release |
| `PLAN.md`, `AGENTS.md`, `handoff/` | how the project works and how to contribute (changes go in as pull requests) |
