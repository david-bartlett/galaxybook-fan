# Install the notification's dependencies

PR #48 · Claude · 2026-11-03

## What changed
- Both PKGBUILDs: `xdg-utils` and `python-gobject` moved from `optdepends` to `depends`.
- `install.sh`: `install_deps` installs `xdg-utils` and Python's GObject bindings on all three package managers if they're missing.
- README: on Arch-based distros, install the kernel's headers first. `docs/installing.md` lists the new dependencies.

## Why
- On a clean EndeavourOS GNOME install, David found the check script needing tools by hand, and asked why the install doesn't bring everything in. A clean install could miss the notification's buttons.

## Tested
- `bash -n install.sh`, and the PKGBUILD's arrays read back in bash. CI builds the Arch package on this PR.
- Not tested: a real install on EndeavourOS.

## For the next person
- The headers stay in `optdepends`. A package can't choose them by kernel, and pacman's install scripts can't run pacman as it holds its lock. `install.sh` does install them, using the same owner-of-vmlinuz lookup as Andy's repo's PR #136, and `package-scripts.sh` names the package when they're missing.
