# Packages

galaxybook-fan is being packaged as an `.rpm` (Fedora), a `.deb` (Ubuntu, Mint, Debian 13 / MX 25) and an Arch package (PLAN.md §10). `install.sh` stays for other distros and for testing. **Done so far: the rpm and the deb.**

Each format is **one package, architecture-independent**: it ships the module's source and DKMS builds it on the laptop, with its config made from that laptop's DSDT (`module/gen-config.sh`). So one `.rpm` serves Fedora 44 and 45, and one `.deb` serves Ubuntu 24.04 / 26.04, Mint, Debian 13 and MX 25.

| Folder / file | What it is |
| --- | --- |
| `files/` + `render.sh` | the units, scripts, polkit rule, session helper, dracut and autoload files, **shared with `install.sh`**: `bash packaging/render.sh clone|package FILE` fills in the paths from `lib/fanpaths.sh` |
| `pre-script.sh` | builds the step run before the first install (rpm `%pre`, deb `preinst`; bash): the "Galaxy Book 5 only" check (`files/pkg-pre.sh.in`, model list from `lib/models.sh`), then removing a copy installed with `install.sh` (`../lib/clone-remove.sh`, the same steps as `uninstall.sh`) |
| `install-files.sh` | puts the package's files in a staging folder (every format) |
| `../lib/package-scripts.sh` | `configure` after install/upgrade, `remove` before removal (every format) |
| `rpm/` | `galaxybook-fan.spec` and `build.sh` |
| `debian/` | `control`, `rules`, maintainer scripts and `build.sh` (debhelper, like fingerprint-fix-sdcp); `build.sh` puts `pre-script.sh`'s output into `preinst` |

## Where a package puts things

| What | Where |
| --- | --- |
| Module source for DKMS | `/usr/src/galaxybook-fan-<version>/` |
| Library folder, scripts | `/usr/lib/galaxybook-fan/` |
| The command | `/usr/bin/galaxybook-fan` (a link into the library folder) |
| Units | `/usr/lib/systemd/system/` (unbind, monitor), `/usr/lib/systemd/user/` (login check timer and service, `galaxybook-fan-session.target`) |
| Polkit rule | `/usr/share/polkit-1/rules.d/49-samsung-galaxybook-fan-monitor.rules` |
| Keep out of the initramfs | `/usr/lib/dracut/dracut.conf.d/galaxybook-fan.conf` |
| Autoload, session helper autostart | `/etc/modules-load.d/galaxybook_fan.conf`, `/etc/xdg/autostart/galaxybook-fan-session.desktop` |

The session helper uses its own names (`galaxybook-fan-session.*`), not the `samsung-galaxybook-session.*` files `install.sh` shares with the other fixes, so it never owns a file another package (fingerprint-fix-sdcp) also installs.

## What the package does

- **Before the first install** (rpm `%pre` with `$1 = 1`, deb `preinst install`): refuses anything that isn't a Galaxy Book 5, changing nothing (`GALAXYBOOK_FAN_FORCE=1` overrides and writes `/etc/galaxybook-fan/force`). Then, if a copy installed with `install.sh` is there, removes it with `uninstall.sh`'s own steps and carries on (if `galaxybook_fan` can't be unloaded it stops, changing nothing). On Arch, pacman stops before any script when the files are already there, so run `sudo ./uninstall.sh` first.
- **After install or upgrade** (`package-scripts.sh configure`: rpm `%post`, deb `postinst configure`): removes other DKMS versions, builds this one for the running kernel (DKMS builds new kernels itself), enables the unbind service and the login check timer for every user, loads the module, and records the state (`INSTALL_METHOD=package`). With Secure Boot on and the signing key not enrolled, it prints the `mokutil --import` command. **A failed build never fails the install**: it says why, and `sudo galaxybook-fan rebuild` builds it once sorted.
- **Before removal, never on upgrade** (`package-scripts.sh remove`: rpm `%preun` with `$1 = 0`, deb `prerm remove`). A deb removed without purge keeps its two files in `/etc` (dpkg conffiles); `apt purge` removes them: unloads and removes the module from DKMS, disables the units, gives the fan back to `acpi-fan`, removes the state and force flag.

## Building one locally

Each build packages this checkout as it is now (tracked and new files) and writes to `packaging/out/`. The version is `VERSION`; give a higher release number to test an upgrade (`build.sh 2`).

```bash
# Fedora
sudo dnf install rpm-build systemd-rpm-macros
bash packaging/rpm/build.sh
sudo dnf install ./packaging/out/galaxybook-fan-*.noarch.rpm
galaxybook-fan status
sudo dnf remove galaxybook-fan

# Ubuntu, Mint, Debian, MX
sudo apt install build-essential debhelper
bash packaging/debian/build.sh
sudo apt install ./packaging/out/galaxybook-fan_*_all.deb
galaxybook-fan status
sudo apt remove galaxybook-fan          # or purge, to remove its /etc files too
```

Build as your normal user (no sudo). A copy installed with `install.sh` is removed by the rpm or deb before it installs; there's no need to run `uninstall.sh` first.
