# galaxybook-fan

Fan speed reporting for the Samsung Galaxy Book 5 on Linux, without a DSDT override.

## Will it work on my laptop?

Download **[check-galaxybook-fan.sh](https://github.com/david-bartlett/galaxybook-fan/releases/latest/download/check-galaxybook-fan.sh)** and run it. It only reads, and installs or changes nothing:

```bash
sudo bash check-galaxybook-fan.sh
```

or make it executable first, then run it with `./`:

```bash
chmod +x check-galaxybook-fan.sh
sudo ./check-galaxybook-fan.sh
```

It checks your model and reads your laptop's own firmware the same way the fix does, then says whether galaxybook-fan will work. If your model isn't confirmed yet, install the fix and run the check again: when the fan speed shows, it gives you a short report to post as a **[Works on my model](https://github.com/david-bartlett/galaxybook-fan/issues/new?template=works_on.yml)** issue, so your model can be added below.

**Confirmed working:**

| Model | Laptop |
|---|---|
| `940XHA` | Galaxy Book 5 Pro 14" |

Not confirmed yet, but expected to work (the check tells you): `960XHA`, `960QHA`, `750XHD`, `754XHD`, `750QHA`, `754QHA`.

## Install

From the **[latest release](https://github.com/david-bartlett/galaxybook-fan/releases/latest)**, download your distro's file and install it:

| Distro | Command |
| --- | --- |
| **Fedora 44, 45** | `sudo dnf install ./galaxybook-fan-*.noarch.rpm` |
| **Ubuntu 24.04, 26.04, Mint, Debian 13, MX 25** | `sudo apt install ./galaxybook-fan_*_all.deb` |
| **Arch, CachyOS, EndeavourOS** | `sudo pacman -U ./galaxybook-fan-*-any.pkg.tar.zst` (or `makepkg -si` with the release's `PKGBUILD` and `galaxybook-fan.install`) |

The packages do what `install.sh` does (below), with no questions: DKMS builds the module on your laptop from its own firmware, for every kernel with headers. They refuse anything that isn't a Galaxy Book 5 (on Arch the module just isn't built, and the install says why). A copy installed with `install.sh` is replaced by the rpm and deb; on Arch, run `sudo ./uninstall.sh` in its folder first. Remove the package with `sudo dnf remove`, `sudo apt remove` or `sudo pacman -R galaxybook-fan`. Details: [packaging/README.md](packaging/README.md). Other distros, or from a clone: [install.sh](#installing-with-installsh).

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
- `_FST` contains any statement outside the known shape (extra maths, another EC read, `Case (Package …)`, `Default`, loops, calls…)
- the EC field isn't defined exactly once, is wider than 8 bits, or is in anything other than an EmbeddedControl, SystemMemory or SystemIO region
- the RPM table is missing, defined more than once, the wrong length, or gives a speed outside 500–20000 RPM
- the laptop boots with a **replacement DSDT** (an ACPI table override loaded from the initramfs, such as the old `fanspeed-fix-cpio`): the table in memory is then the override, not the laptop's own firmware. Remove the override and reboot, then `sudo galaxybook-fan rebuild`

`sudo galaxybook-fan check` (or `sudo ./install.sh --check`) shows why. `install.sh` also saves the disassembled DSDT to `/tmp/galaxybook-fan-dsdt.dsl`, and refuses to install.

The module also checks itself at load time, and refuses to load unless both of these match what the config was generated from:

- the DMI product name
- the DSDT's OEM ID, table ID and revision

So after a **BIOS update** the fan sensor disappears, and you're told to run `sudo galaxybook-fan rebuild`, instead of a changed `_FST` or RPM table producing wrong readings. At load it also checks that the field exists and can be read.

## Is the fix still needed?

The fix adds a login-time check, the same pattern as fingerprint-fix-sdcp and fnkeys-fix-book5. Ten seconds after login, a user timer checks whether the kernel or BIOS version has changed since the last check, or whether the module isn't loaded. If so, it starts a root monitor service (allowed by a polkit rule), which works out what happened and notifies you:

| What changed | What the monitor does | You'll be told |
|---|---|---|
| BIOS update that fixed `_FST` (the table lookup now uses `DerefOf`) | Parses the new DSDT | The fix is no longer needed, so uninstall it |
| BIOS update, `_FST` still broken | Module has paused itself (DSDT changed) | Run `sudo galaxybook-fan rebuild` to rebuild it for the new firmware (repeated at each login until you do) |
| BIOS update that rewrote `_FST` beyond recognition | — | Run `sudo galaxybook-fan test-native` to check |
| New kernel, module not loaded | — | The DKMS build probably failed (or the signing key isn't enrolled); run `sudo galaxybook-fan rebuild` |
| New kernel | Briefly binds the stock `acpi-fan` driver while the fan is spinning and reads it | If it works: the kernel now handles the fan, so uninstall it |

The native test is only conclusive while the fan is running, because the broken code path is only reached then. The monitor waits up to a minute for that. If the fan stays off, it quietly tries again at the next login.

Nothing is installed or removed automatically: the notifications tell you what to run.

### The `galaxybook-fan` command

Installed with the fix:

```bash
galaxybook-fan status            # what's installed, which kernels, the fan speed now
sudo galaxybook-fan check        # will it work on this laptop? (read-only)
sudo galaxybook-fan rebuild      # after a BIOS update: read the new firmware, rebuild the module
sudo galaxybook-fan test-native  # can the stock driver read the fan by itself now?
sudo galaxybook-fan update       # install the newest release's package
galaxybook-fan updates off|on    # "new version" notifications (sudo for off/on)
```

### New versions

30 seconds after login, and every hour while you stay logged in, the fix looks on GitHub for a newer release (at most once a day; at login it waits up to 2 minutes for the network), and tells you once per version: *galaxybook-fan X.Y.Z is available … To update: `sudo galaxybook-fan update`*. That command downloads your distro's package from the release, checks it against the release's `SHA256SUMS` and installs it with `dnf`, `apt` or `pacman`, which asks before installing as usual. Nothing is installed without you running it. A copy installed with `install.sh` is told how to update it instead (`git pull`, then `sudo ./install.sh`). Nothing is said when GitHub can't be reached. Turn the notifications off with `sudo galaxybook-fan updates off`.

## Supported hardware and kernels

- **Samsung Galaxy Book 5 series only:** `940XHA`, `960XHA`, `960QHA`, `750XHD`, `754XHD`, `750QHA`, `754QHA` (the same list as fnkeys-fix-book5, matched with or without an `NP` prefix). Tested on the 940XHA. On the other Book 5 models, the DSDT check confirms the firmware has the same bug before anything is installed.
- Other Samsung models are refused. Earlier Galaxy Books report fan speed with the stock kernel driver, whose `_FST`-only fan support was written and tested on a Book2 Pro. `galaxybook-fan check` and `test-native` still work on them, and `install.sh --force` (or `GALAXYBOOK_FAN_FORCE=1` with a package) overrides.
- Non-Samsung machines are always refused.
- **Kernel 6.8 or newer**, with its headers: DKMS builds the module for each kernel. If they're missing, the install and `galaxybook-fan rebuild` name the package to add (e.g. `linux-headers-$(uname -r)`, `kernel-devel-$(uname -r)`, `linux-cachyos-headers`). The module builds cleanly against 6.8, 6.11, 6.14, 6.17 and 7.0.
- **Not for immutable distros** (Fedora Silverblue / Kinoite, Bazzite, SteamOS): DKMS can't build modules there.
- **Replaces the old `fanspeed-fix-cpio`** DSDT override: remove that first (see *Guards*).

### Tested on

Fedora 45, Ubuntu 26.04, Linux Mint 22.3, MX Linux 25.3 and CachyOS, on a Galaxy Book 5 Pro (940XHA, BIOS P10VAJ.390.260522.02, DSDT `SECCSD LH43STAR 0x01072009`).

<details>
<summary>Test results per distro</summary>

Tested on 31 October 2026: the check, the `galaxybook-fan` command, `install.sh` and the packages (Fedora's rpm, the deb on Ubuntu, Mint and MX, the Arch package on CachyOS). Each package was installed over an `install.sh` copy, upgraded, rebooted (the fan still read, with no login notification) and removed; Fedora then upgraded to the 0.6.1 release's own rpm. `--test-native` and the login check's notifications were last tested on 23 October 2026 with 0.2.

| Distro | Kernel | Desktop | Secure Boot signing | Check | Install | Package | `galaxybook-fan` status / rebuild | `--test-native` | Login check | Uninstall |
|---|---|---|---|---|---|---|---|---|---|---|
| Fedora 45 | 7.2.14 | KDE Plasma | akmods key (enrolled) | ✓ | ✓ | ✓ rpm | ✓ | ✓ | ✓ | ✓ |
| Ubuntu 26.04.1 LTS | 7.0.0-42 | GNOME | Ubuntu MOK key (enrolled) | ✓ | ✓ | ✓ deb | ✓ | ✓ | ✓ | ✓ |
| Linux Mint 22.3 | 7.0.0-38 | Cinnamon | MOK key (enrolled) | ✓ | ✓ | ✓ deb | ✓ | ✓² | ✓² | ✓ |
| MX Linux 25.3 (systemd boot) | 7.2.11 Liquorix (and 7.2.10, 7.2.6) | Xfce (session helper) | Secure Boot off | ✓ | ✓ | ✓ deb | ✓ (rebuilt all 3 kernels) | ✓ | ✓ after a reboot¹ | ✓ |
| CachyOS (Limine) | 7.3.0-4 (and 6.18.55 LTS) | KDE Plasma | Secure Boot off | ✓ | ✓ | ✓ Arch | ✓ | ✓ | ✓ | ✓ |

`--test-native` passing means it correctly reported that the stock `acpi-fan` driver still can't read the fan, so the fix is needed. The firmware bug is the same on every distro.

¹ On MX, a plain log-out and log-in doesn't re-run the login check while Xfce's Print Queue Applet (`system-config-printer`) keeps the old session open. This doesn't matter in practice, because the check only has work to do after a kernel or BIOS update, and those come with a reboot. Turning the applet off under Session and Startup → Application Autostart makes log-outs end cleanly.

² Tested on Linux Mint 27 (beta) with 0.2, before that install was replaced by 22.3.

</details>

Not yet tested on real hardware: the "signing key not enrolled" path (the `mokutil --import` prompt and MokManager after the reboot), and Book 5 models other than the 940XHA.

## Installing with install.sh

Any distro with `dnf`, `apt` or `pacman`.

From the release's **Source code (tar.gz)**, or a clone:

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
- installs the login-time check described above (plus the shared graphical session helper on desktops that need it, such as Xfce), and the `galaxybook-fan` command
- refuses to install if your firmware's `_FST` is already correct, since the stock driver should work then (`--force` overrides)

Re-running `install.sh` over an existing install is fine; there's no need to uninstall first. It won't run while the package is installed.

## Initramfs

`galaxybook_fan` loads after boot from `modules-load.d`, so it never needs to be in the initramfs. Some distros (Fedora) set DKMS's `post_transaction` to rebuild **every** kernel's initramfs after each DKMS operation, which takes a minute or two. Like fnkeys-fix-book5, `install.sh`, `uninstall.sh`, the `galaxybook-fan` command and the packages suspend that for their own DKMS steps with a temporary drop-in (`/etc/dkms/framework.conf.d/zz-galaxybook-fan-defer-initramfs.conf`), which a trap removes when the script exits, even on failure. DKMS's own setting is never changed. On dracut systems, `galaxybook-fan.conf` (`omit_drivers`; in `/etc/dracut.conf.d/` from `install.sh`, `/usr/lib/dracut/dracut.conf.d/` from a package) also keeps the module out of future initramfs images. If an old copy is already in the running kernel's initramfs, only that one image is rebuilt.

## Secure Boot signing

**The packages** never ask anything: DKMS signs with the key it's set up for (Fedora's akmods key once `install.sh` from one of the fixes has set it up, Ubuntu's MOK key, or DKMS's own), and if that key isn't enrolled the install prints the `mokutil --import` command to run once, then the reboot steps below.

**`install.sh`** goes further. It works out the key DKMS will actually sign with, the same way DKMS does: `/etc/dkms/framework.conf`, then every `/etc/dkms/framework.conf.d/*.conf` in order, falling back to DKMS's own `/var/lib/dkms/mok.*`. That covers Fedora's akmods key (`akmods-keys.conf`), Ubuntu's shim key and plain DKMS keys. On Fedora with nothing configured it uses the akmods key and writes the same `akmods-keys.conf` as Andy's webcam-fix-book5, so all the fixes share one key and one enrolment (that file is shared, so `uninstall.sh` leaves it alone). It only adds its own drop-in (`galaxybook-fan-signing.conf`) when it has to point DKMS somewhere else. After building, it checks that DKMS really signed the module.

| Key state | What happens |
|---|---|
| Enrolled (the configured key, or any standard one) | Signed and loaded straight away |
| Imported but waiting for the next boot | Built and signed anyway; reboot and finish the MokManager screen, and the module loads automatically |
| Exists but not enrolled (e.g. a BIOS update wiped NVRAM) | Offers `mokutil --import` (you set a one-time password), then builds and signs; same reboot step |
| Missing | Generated first (`kmodgenca` for akmods, `update-secureboot-policy` on Ubuntu, otherwise `openssl` like DKMS), then as above |

At the MokManager screen after the reboot: **Enroll MOK → Continue → Yes →** type the password **→ Reboot**. There's nothing to re-run afterwards.

## Uninstall

The package: `sudo dnf remove galaxybook-fan`, `sudo apt remove galaxybook-fan` or `sudo pacman -R galaxybook-fan`. A copy installed with `install.sh`:

```bash
sudo ./uninstall.sh
```

Either removes everything that was added and rebinds `acpi-fan`. No reboot is needed.

## Files

<details>
<summary>What each file in this repository is for</summary>

| File | Purpose |
|---|---|
| `install.sh` / `uninstall.sh` | as above |
| `module/gen-config.sh` | DKMS's `PRE_BUILD`: writes the module's config from this machine's DSDT before every build |
| `lib/galaxybook-fan` | the `galaxybook-fan` command |
| `packaging/` | the rpm, deb and Arch packaging, and the units and scripts shared by `install.sh` and the packages ([packaging/README.md](packaging/README.md)) |
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
