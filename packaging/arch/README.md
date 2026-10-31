# Arch package (CachyOS, Arch, EndeavourOS, …)

`PKGBUILD` packages this repository's working tree (local changes included) as one `any` package. `VERSION` is read from the repository, so nothing here needs editing for a new release. DKMS builds the module on the laptop from its own firmware, as with the rpm and deb.

```bash
cd packaging/arch
makepkg -si                      # build as yourself (no sudo), then pacman installs it
```

Rebuilding the same version: raise `pkgrel` or use `makepkg -sif`.

## Before installing

- **A copy installed with `install.sh` is replaced:** there's no need to run `uninstall.sh` first. pacman runs nothing before unpacking, so `post_install` removes the copy afterwards (the same steps as `uninstall.sh`), keeping the files the package now owns. The rpm and deb do it before unpacking.
- **Kernel headers:** DKMS needs the headers of each kernel it builds for. The install says which package is missing for the running kernel (`linux-headers`, `linux-cachyos-headers`, …); once it's installed, Arch's DKMS hook builds the module automatically.

## What it does

The files are the rpm's and deb's (`packaging/install-files.sh`), and `galaxybook-fan.install` runs the same steps (`lib/package-scripts.sh`): after install or upgrade, build for the running kernel, enable the units and the login check, load the module; before removal, take it all out and give the fan back to `acpi-fan`. Arch's own DKMS hooks also build it for every other installed kernel with headers, and remove it with the package.

pacman ignores the exit status of install scripts, so it can't refuse a laptop that isn't a Galaxy Book 5: there the package installs, but `module/gen-config.sh` refuses to build the module and the install says why. `sudo GALAXYBOOK_FAN_FORCE=1 pacman -U …` builds anyway, as with the rpm and deb.

The two files in `/etc` are `backup` files: kept as `.pacsave` if you changed them.
