# Packaging steps 2 and 3: shared templates and the rpm

PR #15 · Claude · 2026-10-31

## What changed
- `packaging/files/*.in` + `packaging/render.sh clone|package`: the unbind and monitor services, the login check (script, service, timer), polkit rule, session helper (target, script, autostart), dracut and autoload files. `install.sh` renders them (`put_rendered`) instead of its own heredocs.
- `lib/fanpaths.sh`: package-layout paths (`/usr/lib/systemd/...`, `/usr/share/polkit-1/...`, `/usr/lib/dracut/...`) and the package's own session helper names (`galaxybook-fan-session.*`).
- `packaging/install-files.sh DESTDIR` (every format), `lib/package-scripts.sh configure|remove` (every format), `packaging/files/pkg-pre.sh.in` (Book 5 check before the first install, model list from `lib/models.sh`), `packaging/rpm/` (spec, `build.sh`), `packaging/README.md`.

## Tested
- `install.sh`'s rendered files compared with its old heredocs: 8 of 10 identical, 2 differ in a comment only.
- rpm built with rpmbuild 4.18 (on Ubuntu, `--nodeps`) and installed with `rpm` there: refuses a non-Samsung with the reason and installs nothing; with `GALAXYBOOK_FAN_FORCE=1` installs, records `INSTALL_METHOD=package` and the force flag, explains a failed build; `/usr/bin/galaxybook-fan status` works; DKMS build for a 6.8 kernel from a fake 940XHA DSDT; upgrade 0.5.0-1 → 0.5.0-2 keeps the build; `rpm -e` removes the module, DKMS registration, files, state and force flag.
- **Found and fixed:** an apostrophe inside `${…:-…}` in the pre-install check broke bash (Fedora's `/bin/sh`) but not dash (where it was first tested): every Fedora install would have failed. Templates are now checked with both shells; AGENTS.md says so.
- Not tested: on Fedora itself (dnf, Fedora's DKMS and kernel-install hook, Secure Boot with the akmods key), the login check from the package's user units, the session helper on Xfce.

## For the next person
- Step 4 (deb) and 5 (Arch) reuse `install-files.sh`, `package-scripts.sh` and `pkg-pre.sh.in`. pacman ignores `.install` exit codes, so on Arch `gen-config.sh` is the real gate.
- Fedora's DKMS key: unless akmods' `akmods-keys.conf` is set up (install.sh does that), DKMS uses its own `/var/lib/dkms/mok.pub`, which may not be enrolled; the package then prints the `mokutil --import` command.
