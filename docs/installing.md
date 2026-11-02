# Installing with install.sh

[← Back to the README](../README.md)

For other distros, or from a clone. This guide also explains Secure Boot signing, for the packages too.

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
- derives the fan config from the DSDT, as described in [How it works](how-it-works.md#the-fix)
- with Secure Boot on, sorts out module signing (see below)
- installs the module through DKMS, so it rebuilds automatically on kernel updates. On Arch-based distros (CachyOS, Manjaro, EndeavourOS…) it's also installed for every other kernel with headers, such as CachyOS's LTS kernel in the boot menu; on Fedora and Debian-based distros, for the running kernel (DKMS adds it to new kernels as they arrive)
- autoloads it via `/etc/modules-load.d/galaxybook_fan.conf`, which is also a good file for checking whether the fix is installed
- enables `galaxybook-acpi-fan-unbind.service`, which unbinds `acpi-fan` at boot
- installs the [login-time check](compatibility.md#is-the-fix-still-needed) (plus the shared graphical session helper on desktops that need it, such as Xfce), and the `galaxybook-fan` command
- refuses to install if your firmware's `_FST` is already correct, since the stock driver should work then (`--force` overrides)

Re-running `install.sh` over an existing install is fine; there's no need to uninstall first, and every kernel the old install was on gets the new version. It won't run while the package is installed.

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
