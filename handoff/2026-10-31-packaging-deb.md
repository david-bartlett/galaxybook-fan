# Packaging step 4: the deb

PR #18 · Claude · 2026-10-31

## What changed
- `packaging/debian/`: `control`, `rules` (debhelper 13, like fingerprint-fix-sdcp), `copyright`, maintainer scripts, `build.sh`. One `Architecture: all` deb, version `X.Y.Z-N` with no release tag, for Ubuntu 24.04 / 26.04, Mint, Debian 13 and MX 25.
- `preinst` (bash): on `install`, `packaging/pre-script.sh`'s output (Book 5 check, then replacing an install.sh copy), put in by `build.sh` at its `#@PRE_SCRIPT@` line. `postinst configure` / `prerm remove`: `lib/package-scripts.sh`, as the rpm. `postrm`: `daemon-reload`.
- `rules`: `install-files.sh` installs everything; `dh_installsystemd(user)` off (package-scripts.sh enables the units, as with the rpm); `dh_fixperms` skips `/usr/src` so `gen-config.sh` stays executable.
- `lib/clone-remove.sh`: `gbfan_clone_installed` counts only files install.sh alone makes (command, check script, unbind unit in `/etc/systemd/system`, old udev rule, `/usr/local/lib/samsung-galaxybook/fan`). The autoload file and DKMS no longer count: a deb removed without purge leaves the autoload file (a conffile), and reinstalling would have deleted it, which dpkg then doesn't restore.
- `uninstall.sh`'s "package is installed" message names apt and pacman too.

## Tested
- Here (Ubuntu 24.04 container, debhelper 13, DKMS 3.0, no systemd), with `apt install ./…deb`:
  - Non-Samsung: refused, nothing installed, simulated install.sh copy untouched.
  - `GALAXYBOOK_FAN_FORCE=1` over the install.sh copy: removed it, installed; the DKMS build failed (no headers for this container's kernel) and **apt still finished with the package installed and configured** (PLAN.md's open question).
  - Upgrade -1 → -2: no removal step. `apt remove`: config-files state, only the autoload file left. Install again: no "removing the copy" step, autoload file kept. `apt purge`: nothing left.
  - `uninstall.sh` refuses while the deb is installed.
  - Contents match the rpm's; `/etc` files are conffiles; `bash -n` on preinst, `dash -n` on the others; shellcheck on `build.sh`.
- Not tested: on the laptop (Ubuntu's MOK signing, Mint, MX's Liquorix kernels, the login check from the package's user units, the session helper on Xfce).

## For the next person
- Step 5 (Arch): pacman refuses over an install.sh copy's files before any script runs, so the Arch README and release page say `sudo ./uninstall.sh` first; `post_install` warns if a copy is there. `gen-config.sh` is the model gate there.
- Step 6 builds the deb in CI; any one Debian/Ubuntu runner will do.
