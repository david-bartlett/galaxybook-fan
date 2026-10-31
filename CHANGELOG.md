# Changelog

<!-- Release pages: lines that start with a bold headline, "- **Own repository:** …",
     are listed under What's new; the whole section is under "Full changelog" (collapsed).
     Bold lines: short, so What's new stays brief.
     Plain lines: the full detail, shown only in Full changelog.
     Every release, even a small one: at least one bold line. -->

## Unreleased

- **Fedora package:** galaxybook-fan can be built and installed as an rpm (`bash packaging/rpm/build.sh`, then `sudo dnf install ./packaging/out/galaxybook-fan-*.noarch.rpm`)
- One `noarch` rpm for Fedora 44 and 45: DKMS builds the module on the laptop, as with `install.sh`. It refuses anything that isn't a Galaxy Book 5 (`GALAXYBOOK_FAN_FORCE=1` overrides). A failed build doesn't fail the install: it says why, and `sudo galaxybook-fan rebuild` builds it once sorted. With Secure Boot on and the key not enrolled, it gives the `mokutil` command. `sudo dnf remove galaxybook-fan` removes everything
- Moving from an `install.sh` copy to the package hides the stock `acpi_fan` sensor straight away: the package re-runs the unbind service instead of only enabling it, and `uninstall.sh` now stops the service as well as removing it (it stayed "active", so the package's install didn't re-run it and `sensors` showed two fans until a reboot)
- The package's install output starts with "checking the module for …", then says whether DKMS built it or it was already built (it used to say "building" even when nothing needed building)
- The units, scripts and polkit rule now come from shared templates (`packaging/files/`), so `install.sh` and the packages install the same files; `install.sh`'s output is unchanged

- **Switching to the package:** installing it over a copy made with `install.sh` removes that copy first, so there's no need to run `uninstall.sh` beforehand
- The package's pre-install step runs the same removal steps as `uninstall.sh` (now shared, `lib/clone-remove.sh`), after the Galaxy Book 5 check, so a refused install still changes nothing. It says which folder the old copy came from; that folder isn't used by the package and can be kept or deleted. If `galaxybook_fan` can't be unloaded, nothing is changed and it asks you to close anything reading the fan or reboot. The Arch package does the same just after installing
- `uninstall.sh` works as before; it no longer prints systemd's errors when systemd isn't running

- **Ubuntu, Mint, Debian and MX package:** galaxybook-fan can be built and installed as a `.deb` (`bash packaging/debian/build.sh`, then `sudo apt install ./packaging/out/galaxybook-fan_*_all.deb`)
- One `Architecture: all` deb for Ubuntu 24.04 and 26.04, Linux Mint, Debian 13 and MX Linux 25: DKMS builds the module on the laptop, as with the rpm. It does what the rpm does: Galaxy Book 5 only (`GALAXYBOOK_FAN_FORCE=1` overrides), replaces a copy installed with `install.sh`, never fails the install over a failed build, and `sudo apt remove galaxybook-fan` removes everything (`purge` also removes the autoload file)
- Installing the deb again after `apt remove` (without purge) keeps its autoload file: the check for an `install.sh` copy now counts only files `install.sh` alone makes, so a removed deb's leftover file isn't taken for one
- `uninstall.sh` names apt and pacman as well as dnf when it finds the package installed

- **Arch and CachyOS package:** galaxybook-fan can be built and installed with `cd packaging/arch && makepkg -si`
- One `any` package: DKMS builds the module on the laptop, and Arch's DKMS hooks build it for every installed kernel with headers. The install names the headers package to add if the running kernel's are missing (e.g. `linux-cachyos-headers`). On anything but a Galaxy Book 5 it installs but doesn't build the module, and says why (`GALAXYBOOK_FAN_FORCE=1` builds anyway). Like the rpm and deb it replaces a copy installed with `install.sh` (just after installing, keeping the package's own files). `sudo pacman -R galaxybook-fan` removes everything

## 0.5.0 — 2026-10-31

- **`galaxybook-fan` command:** `galaxybook-fan status`, `sudo galaxybook-fan check`, `sudo galaxybook-fan rebuild` (after a BIOS update) and `sudo galaxybook-fan test-native`
- After a BIOS update you no longer need the folder you installed from: the notification says to run `sudo galaxybook-fan rebuild`, which rebuilds the module for the new firmware on every kernel it's built for. `status` shows the version, kernels, how it was installed and the fan speed now
- DKMS now writes the module's config from the laptop's DSDT itself, before every build (`module/gen-config.sh`, DKMS `PRE_BUILD`), with the same checks as the installer: Galaxy Book 5 only (unless installed with `--force`), and never for firmware it doesn't recognise. A refused build says why
- Names, paths and DKMS steps are shared by the installer, `uninstall.sh`, the command and the login check (`lib/fanpaths.sh`, `lib/fan-dkms.sh`), ready for the rpm, deb and Arch packages. `install.sh` won't run while the package is installed
- Re-run `sudo ./install.sh` once to get the command; nothing else changes for an existing install
- The command also works straight from a clone before installing (`sudo ./lib/galaxybook-fan check`)
- The check shows the distro's own name where its os-release names the base distro: MX Linux shows as "MX … (based on Debian GNU/Linux 13 (trixie))"
- Tested on Fedora 45, Ubuntu 26.04, Linux Mint 22.3, MX Linux 25.3 and CachyOS: install, the check and `galaxybook-fan status` / `rebuild` (README's *Tested on* table, now collapsible)

- **Running the check:** the README and release page also show the `chmod +x` way, for running `check-galaxybook-fan.sh` with `./`
- A downloaded file can't be run with `./` until it's made executable, so `./check-galaxybook-fan.sh` was refused; `sudo bash check-galaxybook-fan.sh` always works

## 0.4.0 — 2026-10-31

- **Will it work on my laptop?** `check-galaxybook-fan.sh` checks your model and firmware before you install anything; it's attached to every release and linked at the top of the README
- Read-only, one file: run `sudo bash check-galaxybook-fan.sh`. It makes the same firmware checks as the installer and says whether galaxybook-fan will work, and whether your model is already confirmed. On a model that isn't confirmed yet, with the fix installed and the fan spinning, it prints a short report to post as a *Works on my model* issue
- README: a *Confirmed working* table at the top (the 940XHA so far). Issue forms for *Works on my model* and bug reports
- The model lists are in one place, `lib/models.sh`, used by `install.sh` and the check. The installer now says "confirmed working" instead of "tested"

- **Tidier repository:** the module's files are in `module/` and the installer's helpers in `lib/`; `install.sh` and `uninstall.sh` stay at the top
- `module/`: `galaxybook_fan.c`, `galaxybook_fan_config.h`, `Makefile`, `dkms.conf`. `lib/`: `dsdt-fan-config.py`, `samsung-galaxybook-fan-check.sh`. Nothing changes in what gets installed or where, so there's no need to reinstall
- `LICENSE`: GNU GPL version 2, the licence the module already declared

## 0.3.0 — 2026-10-31

- **Own repository:** galaxybook-fan has moved out of samsung-galaxybook-fixes into its own repository, with its full history
- It used to be `extras/galaxybook-fan` in [samsung-galaxybook-fixes](https://github.com/david-bartlett/samsung-galaxybook-fixes), which now only has a README pointing here. Already installed from there? Run this repository's `install.sh` once, so the notifications after a BIOS or kernel update tell you to run `install.sh` and `uninstall.sh` in this folder instead of the old one
- The version is now three numbers (`0.2.0`, was `0.2`), in a new `VERSION` file that the release tool keeps in step with `dkms.conf` and `install.sh`. Re-running `install.sh` replaces the old DKMS version, as before
- `PLAN.md`, `AGENTS.md` and `handoff/` for contributors
- Release pages: how to install from the source code, *What's new* and the full changelog, made by a release workflow when a version is tagged

## 0.2 — 2026-10-24

- **Fan speed on the Galaxy Book 5:** a small DKMS module reads the fan speed that Samsung's broken `_FST` method can't report on Linux
- First version, developed in `extras/galaxybook-fan` of samsung-galaxybook-fixes: the module, the installer that derives the EC field and RPM table from the machine's own DSDT, the `acpi-fan` unbind service, Secure Boot signing, and the login-time check that notices a kernel or BIOS update. Tested on the Galaxy Book 5 Pro (940XHA) with Fedora 45, Ubuntu 26.04, Linux Mint 27, MX Linux 25 and CachyOS
