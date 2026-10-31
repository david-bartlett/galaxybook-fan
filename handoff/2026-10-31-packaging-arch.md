# Packaging step 5: the Arch package

PR #19 · Claude · 2026-10-31

## What changed
- `packaging/arch/PKGBUILD`: one `arch=('any')` package from the working tree (like fingerprint-fix-sdcp's local `PKGBUILD`), `package()` = `install-files.sh` plus docs and licence. Depends `dkms make gcc acpica python kmod bash systemd polkit libnotify`; headers are optional (each kernel has its own). The two `/etc` files are `backup` files.
- `packaging/arch/galaxybook-fan.install`: `post_install` / `post_upgrade` run `lib/package-scripts.sh configure` (output prefixed `==>`), `pre_remove` runs `remove`, `post_remove` reloads systemd. `GALAXYBOOK_FAN_FORCE=1` writes the force flag. If the running kernel has no headers it names the package (`/usr/lib/modules/$(uname -r)/pkgbase` + `-headers`).
- `packaging/arch/README.md`, `.gitignore` (makepkg's `src/`, `pkg/`, `*.pkg.tar.*`), `packaging/README.md`, PLAN.md (step 5 ✅), CHANGELOG.

## Decisions
- **An install.sh copy: `uninstall.sh` first.** pacman refuses over a same-version copy's `/usr/src/galaxybook-fan-<ver>/` files before running anything (checked on CachyOS; the `/etc` autoload file is a `backup` file, so it doesn't clash). An older copy doesn't clash, and pacman does install (David saw the old "copy still here" warning once): for that, pacman runs nothing before unpacking, so `post_install` / `post_upgrade` run `package-scripts.sh replace-clone`: `gbfan_remove_clone` with `GBFAN_KEEP_VERSION`, which keeps what the package now owns or uses (its `/usr/src/galaxybook-fan-<ver>`, the autoload file, force flag, state) and doesn't rebind acpi-fan; other versions' `/usr/src` folders go. `lib/clone-remove.sh` is now shipped in the package's library folder for this.
- **Found on CachyOS:** after `pacman -R`, `galaxybook_fan` stayed loaded (both fans in `sensors`). Arch's DKMS hook runs `dkms remove` (deleting the `.ko` and running depmod) before `pre_remove`, and `modprobe -r` can't find a module that's no longer in the index. New `gbfan_unload` (`lib/fan-dkms.sh`): `modprobe -r`, else `rmmod`; used everywhere the module is unloaded.
- `uninstall.sh` now names each removed `/usr/src` folder ("Removed /usr/src/galaxybook-fan-0.5.0") instead of "Removed source from /usr/src".
- No Book 5 refusal: pacman ignores `.install` exit codes. `gen-config.sh` refuses the build and `configure` prints its reason.
- Arch's dkms package has pacman hooks (install on `usr/src/*/dkms.conf` and new headers, remove before removal): they build for the other kernels; `configure` builds the running one first and copes with the hook having already removed it on removal.

## Tested
- Here (Ubuntu 24.04, Debian's pacman/makepkg): `makepkg -d` builds the package; contents match the rpm and deb, with `.INSTALL` and `backup`. pacman's install simulated by unpacking it over a simulated install.sh copy and running `post_install`: the copy's files all removed, the package's kept (6 files in `/usr/src`, autoload, state now `package`); an older copy's `/usr/src/galaxybook-fan-0.4.0` removed. `uninstall.sh` and the deb's takeover re-run: unchanged. `bash -n`, shellcheck.
- Not tested: installing with pacman on Arch/CachyOS, the DKMS hooks, CachyOS kernels.

## For the next person
- Step 6 (release workflow): build rpm, deb and the Arch package in CI (an Arch container for `makepkg`), attach them plus a release `PKGBUILD` (from the tarball, like fingerprint-fix-sdcp's `PKGBUILD.release.in`) and `galaxybook-fan.install`, and a per-distro install table on the release page.
