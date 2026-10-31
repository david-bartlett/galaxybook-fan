# Changelog

<!-- Release pages: lines that start with a bold headline, "- **Own repository:** …",
     are listed under What's new; the whole section is under "Full changelog" (collapsed).
     Bold lines: short, so What's new stays brief.
     Plain lines: the full detail, shown only in Full changelog.
     Every release, even a small one: at least one bold line. -->

## Unreleased

- **Stays on screen on GNOME:** the new-version notification now stays until you close or click it, as it does on other desktops
- GNOME ignores "keep it open" for normal notifications and moves them to its list after a few seconds, so on GNOME (only) it's sent as critical, like fingerprint-fix-sdcp's. Hover over it to see the whole text and the buttons

- **Update now and What's new on GNOME:** the buttons now work there too, and clicking the notification opens the release page
- On Ubuntu 26.04 `notify-send` dropped the buttons (*Actions are not supported*), although GNOME shows them. On GNOME the notification is now sent straight to GNOME instead (`notify-dbus.py`, with PyGObject, which the packages recommend); without it, it's the plain notification with the command and link

## 0.8.4 — 2026-10-31

- **The new module is really installed:** on Mint 22 and Ubuntu 24.04, an upgrade could leave the old version's module file in place, so `dkms status` said *Diff between built and installed module*
- That DKMS keeps a file it takes for the same module and marks the new version installed anyway. The install (and `galaxybook-fan rebuild`) now spots that warning and installs the new module over it

## 0.8.3 — 2026-10-31

- **Easier to read help:** `galaxybook-fan --help` lists the commands in a table, with what each one does beside it
- 80 columns wide, commands in bold on a terminal (plain when piped). `updates on` / `off` (with `sudo`) and `updates status` (without) now have a row each, and the help says the check runs every 6 hours, not daily. The README and the release page have the same table, collapsed

## 0.8.2 — 2026-10-31

- **Quicker to hear about a fix:** the new-version check asks GitHub every 6 hours instead of once a day, so an urgent release is noticed the same day
- Still one notification per version, however often it looks

- **Only complete releases are announced:** a new release is only announced once its packages and `SHA256SUMS` are attached, so `sudo galaxybook-fan update` can always install it
- The release workflow now creates each release as a draft, attaches the files and only then publishes it, so a release never appears without them
- The check also looks for this system's package in the release's `SHA256SUMS`; if it isn't there yet it says nothing and looks again an hour later. `galaxybook-fan updates check` says the release isn't ready yet instead of announcing it

- **Upgrading the deb:** the old version no longer lingers in DKMS after a deb upgrade, and `galaxybook-fan status` shows the version you have
- apt deletes the old version's source before the new package sets itself up, and DKMS (seen on Mint 22 and Ubuntu 26.04) then couldn't remove the old version, so `dkms status` showed *Could not locate dkms.conf* and `galaxybook-fan status` said the old version, built for no kernel. The upgrade now removes what's left of it, which also tidies a copy upgraded before this
- Other kernels the old version was still installed for (MX had two) get the new version too, where their headers are installed
- On Debian 13 and MX, DKMS refused to install the new module over the old version's file (*already installed (unversioned module)*), so the old module stayed in use: the old file is now removed first

## 0.8.1 — 2026-10-31

- **What's new keeps Update now:** pressing *What's new* on the new-version notification opens the release page and leaves the notification there, so *Update now* is still one click away
- Desktops close a notification when one of its buttons is pressed, so after the page opens it's shown again, a moment later so it appears after the browser window. *Update now* or closing it ends it

- **Click it on GNOME:** GNOME usually shows no buttons, so clicking the new-version notification itself opens the release page, and the notification says so
- Only on GNOME (including Ubuntu's), so KDE, Cinnamon, MATE and Xfce keep just their two buttons. A click opens *What's new*, not *Update now*, so a stray one never opens a terminal asking for your password

## 0.8.0 — 2026-10-31

- **Update now:** where the desktop shows notification buttons (KDE, Cinnamon, Xfce…), the new-version notification has **Update now**, which opens a terminal running `sudo galaxybook-fan update`, and **What's new**, which opens the release page
- `galaxybook-fan updates check` (no sudo) looks for a new version straight away and, if there is one, shows the same notification
- *What's new* is offered only where the link can be opened (`xdg-open`, or `gio open`); the packages recommend `xdg-utils`. *Update now* is offered only where a terminal can be found
- The terminal is the desktop's own (its default where set, e.g. Konsole on KDE, Ptyxis or GNOME Terminal on GNOME, xfce4-terminal on Xfce); it closes by itself after a successful update. GNOME shows the same text without buttons. The notification you see is drawn by the version you have, so the buttons appear from the release after this one

- **No log-out needed:** installing or upgrading the package starts the new-version check straight away for everyone logged in, and removing it stops it
- Before, `systemctl --global enable` only took effect at each user's next login, so the check didn't run until then; removal also stops both timers in running sessions
- The new-version notification puts the command and the release link on separate lines (on KDE they ran together and looked like one command), and uses the standard `system-software-update` icon (the one it used is missing from some icon themes, e.g. KDE's Breeze showed a blank page)

## 0.7.0 — 2026-10-31

- **New versions:** galaxybook-fan tells you once when a newer release is out, and `sudo galaxybook-fan update` installs it
- Looked for 30 seconds after login and hourly while you stay logged in, on GitHub at most once a day, waiting up to 2 minutes for the network at login; told once per version, and nothing is said when GitHub can't be reached. The notification has no buttons, so it's the same on GNOME and KDE: it gives the command and the release's link
- `sudo galaxybook-fan update` downloads your distro's package from the newest release, checks it against the release's `SHA256SUMS` and installs it with `dnf`, `apt` or `pacman` (which ask first, as usual). A copy installed with `install.sh` is told how to update it instead
- `sudo galaxybook-fan updates off` / `on` turns the notifications off and on; `galaxybook-fan status` shows which. The packages now need `curl`

## 0.6.2 — 2026-10-31

- **Safer when the module isn't loaded:** the stock `acpi-fan` driver is only switched off while galaxybook-fan's module is loaded and reading the fan
- At boot, `galaxybook-acpi-fan-unbind.service` now runs after the module has loaded, and only if it has. The packages, `install.sh` and `galaxybook-fan rebuild` do the same, and give the fan back to `acpi-fan` when the module doesn't load. Before, it was switched off whatever happened, so where the stock driver works (the Arch package on an earlier Galaxy Book, where pacman can't refuse to install; the old DSDT override; firmware that's fixed) there was no fan sensor at all

- **Old DSDT override:** galaxybook-fan says when the laptop boots with a replacement DSDT, such as the old `fanspeed-fix-cpio`, instead of calling the firmware "already fixed"
- The kernel log shows the override (`Table Upgrade: override [DSDT…]`). DKMS's config step, `install.sh`, `check-galaxybook-fan.sh` and the login check all stop there and say to remove the override, reboot and run `sudo galaxybook-fan rebuild`

- **Missing kernel headers:** the install and `galaxybook-fan rebuild` name the package to add for the running kernel (`linux-headers-…` on Ubuntu, Debian and MX, `kernel-devel-…` on Fedora, `<kernel>-headers` on Arch)
- README: not for immutable distros (Silverblue, Bazzite, SteamOS), and remove the old `fanspeed-fix-cpio` first


- **README:** installing from the release's packages now comes straight after the check, and the rest is up to date with the packages
- What the packages do is described where it differs from `install.sh` (the DSDT check, Secure Boot, the initramfs, removal), the *Tested on* table has a column for the package tested on each distro, and *Files* lists the packaging scripts and is collapsed

## 0.6.1 — 2026-10-31

- **Fedora package:** galaxybook-fan can be built and installed as an rpm (`bash packaging/rpm/build.sh`, then `sudo dnf install ./packaging/out/galaxybook-fan-*.noarch.rpm`)
- One `noarch` rpm for Fedora 44 and 45: DKMS builds the module on the laptop, as with `install.sh`. It refuses anything that isn't a Galaxy Book 5 (`GALAXYBOOK_FAN_FORCE=1` overrides). A failed build doesn't fail the install: it says why, and `sudo galaxybook-fan rebuild` builds it once sorted. With Secure Boot on and the key not enrolled, it gives the `mokutil` command. `sudo dnf remove galaxybook-fan` removes everything
- Moving from an `install.sh` copy to the package hides the stock `acpi_fan` sensor straight away: the package re-runs the unbind service instead of only enabling it, and `uninstall.sh` now stops the service as well as removing it (it stayed "active", so the package's install didn't re-run it and `sensors` showed two fans until a reboot)
- The package's install output starts with "checking the module for …", then says whether DKMS built it or it was already built (it used to say "building" even when nothing needed building)
- The units, scripts and polkit rule now come from shared templates (`packaging/files/`), so `install.sh` and the packages install the same files; `install.sh`'s output is unchanged

- **Switching to the package:** installing it over a copy made with `install.sh` removes that copy first, so there's no need to run `uninstall.sh` beforehand
- The package's pre-install step runs the same removal steps as `uninstall.sh` (now shared, `lib/clone-remove.sh`), after the Galaxy Book 5 check, so a refused install still changes nothing. It says which folder the old copy came from; that folder isn't used by the package and can be kept or deleted. If `galaxybook_fan` can't be unloaded, nothing is changed and it asks you to close anything reading the fan or reboot. Arch needs `sudo ./uninstall.sh` first: pacman refuses over the copy's module source before any script runs
- `uninstall.sh` works as before; it no longer prints systemd's errors when systemd isn't running

- **Ubuntu, Mint, Debian and MX package:** galaxybook-fan can be built and installed as a `.deb` (`bash packaging/debian/build.sh`, then `sudo apt install ./packaging/out/galaxybook-fan_*_all.deb`)
- One `Architecture: all` deb for Ubuntu 24.04 and 26.04, Linux Mint, Debian 13 and MX Linux 25: DKMS builds the module on the laptop, as with the rpm. It does what the rpm does: Galaxy Book 5 only (`GALAXYBOOK_FAN_FORCE=1` overrides), replaces a copy installed with `install.sh`, never fails the install over a failed build, and `sudo apt remove galaxybook-fan` removes everything (`purge` also removes the autoload file)
- Installing the deb again after `apt remove` (without purge) keeps its autoload file: the check for an `install.sh` copy now counts only files `install.sh` alone makes, so a removed deb's leftover file isn't taken for one
- `uninstall.sh` names apt and pacman as well as dnf when it finds the package installed

- **Arch and CachyOS package:** galaxybook-fan can be built and installed with `cd packaging/arch && makepkg -si`
- One `any` package: DKMS builds the module on the laptop, and Arch's DKMS hooks build it for every installed kernel with headers. The install names the headers package to add if the running kernel's are missing (e.g. `linux-cachyos-headers`). On anything but a Galaxy Book 5 it installs but doesn't build the module, and says why (`GALAXYBOOK_FAN_FORCE=1` builds anyway). Remove a copy installed with `install.sh` first (`sudo ./uninstall.sh`): pacman won't install over its module source (an older copy is removed just after installing). `sudo pacman -R galaxybook-fan` removes everything
- Removing the package or running `uninstall.sh` unloads the module even when its file has already gone (`rmmod` when `modprobe -r` can't find it): on Arch, the DKMS hook deletes the file before the package's removal step, so `galaxybook_fan` stayed loaded and `sensors` showed both fans until a reboot

- **Packages on the release page:** each release has the Fedora `.rpm`, the Ubuntu / Debian `.deb` and the Arch package, built by GitHub, with a table of which to download and the one command to install it
- The release workflow builds the three packages (`fedora:45`, `debian:13`, `archlinux:base-devel`) and attaches them with a `PKGBUILD` to build the release on Arch instead, `galaxybook-fan.install`, `check-galaxybook-fan.sh` and `SHA256SUMS`. On every pull request it builds them as downloadable artifacts, so they can be tested before a release
- The rpm is named `galaxybook-fan-X.Y.Z-1.noarch.rpm`, without `.fc45`: the same file is for Fedora 44 and 45
- README: install from the release's packages first; `install.sh` stays for other distros

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
