# Packaging step 5: the Arch package

PR #19 · Claude · 2026-10-31

## What changed
- `packaging/arch/PKGBUILD`: one `arch=('any')` package from the working tree (like fingerprint-fix-sdcp's local `PKGBUILD`), `package()` = `install-files.sh` plus docs and licence. Depends `dkms make gcc acpica python kmod bash systemd polkit libnotify`; headers are optional (each kernel has its own). The two `/etc` files are `backup` files.
- `packaging/arch/galaxybook-fan.install`: `post_install` / `post_upgrade` run `lib/package-scripts.sh configure` (output prefixed `==>`), `pre_remove` runs `remove`, `post_remove` reloads systemd. `GALAXYBOOK_FAN_FORCE=1` writes the force flag. If the running kernel has no headers it names the package (`/usr/lib/modules/$(uname -r)/pkgbase` + `-headers`).
- `packaging/arch/README.md`, `.gitignore` (makepkg's `src/`, `pkg/`, `*.pkg.tar.*`), `packaging/README.md`, PLAN.md (step 5 ✅), CHANGELOG.

## Decisions
- No takeover of an install.sh copy: both own `/etc/modules-load.d/galaxybook_fan.conf` and `/usr/src/galaxybook-fan-<ver>/`, so pacman stops with "exists in filesystem" before any script. The README says `sudo ./uninstall.sh` first (as fingerprint-fix-sdcp); `post_install` warns if a copy is somehow still there.
- No Book 5 refusal: pacman ignores `.install` exit codes. `gen-config.sh` refuses the build and `configure` prints its reason.
- Arch's dkms package has pacman hooks (install on `usr/src/*/dkms.conf` and new headers, remove before removal): they build for the other kernels; `configure` builds the running one first and copes with the hook having already removed it on removal.

## Tested
- Here (Ubuntu 24.04, Debian's pacman/makepkg): `makepkg -d` builds `galaxybook-fan-0.5.0-1-any.pkg.tar.zst`; contents match the rpm and deb, with `.INSTALL`; `.install` functions run against a stub `package-scripts.sh` (headers hint, force flag); `bash -n`, shellcheck.
- Not tested: installing with pacman on Arch/CachyOS, the DKMS hooks, CachyOS kernels.

## For the next person
- Step 6 (release workflow): build rpm, deb and the Arch package in CI (an Arch container for `makepkg`), attach them plus a release `PKGBUILD` (from the tarball, like fingerprint-fix-sdcp's `PKGBUILD.release.in`) and `galaxybook-fan.install`, and a per-distro install table on the release page.
