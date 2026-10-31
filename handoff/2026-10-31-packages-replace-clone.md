# Packages replace an install.sh copy

PR #17 · Claude · 2026-10-31

## What changed
- `lib/clone-remove.sh`: `uninstall.sh`'s removal steps as `gbfan_remove_clone` (and `gbfan_clone_installed`). `uninstall.sh` now calls it; what it removes and prints is the same.
- `packaging/pre-script.sh` builds the packages' pre-install step: `lib/fanpaths.sh` (clone layout), `lib/fan-dkms.sh`, `lib/clone-remove.sh`, then `files/pkg-pre.sh.in`. It runs in bash (rpm `%pre -p /bin/bash`; the deb's `preinst` will be `#!/bin/bash`).
- `pkg-pre.sh.in`: the Book 5 check first (a refusal changes nothing), then, if an install.sh copy is there, remove it and carry on, instead of refusing. If `galaxybook_fan` can't be unloaded it stops before changing anything. `GALAXYBOOK_FAN_FORCE=1` writes the force flag after the removal.

## Why
- David hit the old refusal ("already installed with install.sh") when he first installed the rpm on Fedora. fingerprint-fix-sdcp's rpm and deb remove an install.sh copy themselves; galaxybook-fan now does too. install.sh never left a cleanup script on the system, so the steps are built into the package rather than run from the old copy: that also covers every existing 0.5.0 install.

## Tested
- Here (Ubuntu 24.04 container, rpm 4.18, DKMS 3.0, no systemd): a simulated install.sh copy (the same files and DKMS registration install.sh makes).
  - New and `main`'s `uninstall.sh` on it: same output (less two systemd errors) and nothing left; run again with nothing installed: fine.
  - rpm on a non-Samsung: refused, copy untouched. With `GALAXYBOOK_FAN_FORCE=1`: copy removed (folder named from the state file), package installed, `INSTALL_METHOD=package`, nothing of the copy left. Upgrade to release 2: no removal step. `rpm -e`: clean.
  - Module that can't be unloaded (a built-in module's name swapped in): exit 1, copy untouched, no force flag.
  - `bash -n` and shellcheck on the scripts and the built pre-install step.
- **Fedora's rpmbuild hung** reading the spec when the new pre-install text was put in with `%(cat …)` (fine with rpm 4.18 here). Now `build.sh` writes it to a file with every `%` doubled and the spec reads it with `%pre -p /bin/bash -f`, the usual way; the built rpm's scriptlet is identical to `pre-script.sh`'s output.
- Not tested: on Fedora with the real module loaded, Secure Boot, systemd and a logged-in user.

## For the next person
- Deb (step 4): `preinst` with `#!/bin/bash`, running `packaging/pre-script.sh`'s output when `$1 = install`.
- Arch (step 5) can't do this: pacman refuses before `pre_install` when files exist. Say `sudo ./uninstall.sh` first in its README and release page; `post_install` warns if a copy is found (as fingerprint-fix-sdcp).
- Any change to removal goes in `lib/clone-remove.sh`; it must work with only bash and the old copy's files on disk.
