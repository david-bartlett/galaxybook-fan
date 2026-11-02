# Compatibility and updates

[← Back to the README](../README.md)

How the fix tells you when it's no longer needed, how you hear about new versions, and which laptops, kernels and distros it works on.

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

## New versions

A minute after login, and every hour while you stay logged in, the fix looks on GitHub for a newer release (at login it always asks; it waits up to 2 minutes for the network), and once its packages are attached, tells you once per version: *galaxybook-fan X.Y.Z is available*, with **Update now**, which opens a terminal running `sudo galaxybook-fan update`, and **What's new** opens the release page. It stays on screen until you close it; on GNOME it stays on screen too (hover over it for the whole text and the buttons), and clicking it opens the release page. That command downloads your distro's package from the release, checks it against the release's `SHA256SUMS` and installs it with `dnf`, `apt` or `pacman`, which asks before installing as usual. Nothing is installed without you running it. A copy installed with `install.sh` is told how to update it instead (`git pull`, then `sudo ./install.sh`). Nothing is said when GitHub can't be reached. Turn the notifications off with `sudo galaxybook-fan updates off`.

## Supported hardware and kernels

- **Samsung Galaxy Book 5 series only:** `940XHA`, `960XHA`, `960QHA`, `750XHD`, `754XHD`, `750QHA`, `754QHA` (the same list as fnkeys-fix-book5, matched with or without an `NP` prefix). Tested on the 940XHA. On the other Book 5 models, the DSDT check confirms the firmware has the same bug before anything is installed.
- Other Samsung models are refused. Earlier Galaxy Books report fan speed with the stock kernel driver, whose `_FST`-only fan support was written and tested on a Book2 Pro. `galaxybook-fan check` and `test-native` still work on them, and `install.sh --force` (or `GALAXYBOOK_FAN_FORCE=1` with a package) overrides.
- Non-Samsung machines are always refused.
- **Kernel 6.8 or newer**, with its headers: DKMS builds the module for each kernel. If they're missing, the install and `galaxybook-fan rebuild` name the package to add (e.g. `linux-headers-$(uname -r)`, `kernel-devel-$(uname -r)`, `linux-cachyos-headers`). The module builds cleanly against 6.8, 6.11, 6.14, 6.17 and 7.0.
- **Not for immutable distros** (Fedora Silverblue / Kinoite, Bazzite, SteamOS): DKMS can't build modules there.
- **Replaces the old `fanspeed-fix-cpio`** DSDT override: remove that first (see [Guards](how-it-works.md#guards)).

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
