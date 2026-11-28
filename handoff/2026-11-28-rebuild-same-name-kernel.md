# Rebuild when a release upgrade replaces a kernel with one of the same name

PR #63 · Claude · 2026-11-28

## What changed
- New `packaging/files/kernel-rebuild-hook.in` (POSIX sh): given a kernel, if the installed `galaxybook_fan.ko*` is older (change time) than that kernel's `build/Module.symvers`, runs `dkms install galaxybook-fan/<version> -k <kernel> --force`. `--check [KERNEL]` exits 1 with that command instead.
- Installed on apt distros only, as `/etc/kernel/header_postinst.d/zz-galaxybook-fan` and `/etc/kernel/postinst.d/zz-galaxybook-fan`: by `install.sh` (`install_kernel_hooks`, files) and the deb (`install-files.sh DESTDIR deb` from `debian/rules`: the script in `/usr/lib/galaxybook-fan/kernel-rebuild-hook`, links from `/etc`). Not the rpm or Arch package.
- `lib/clone-remove.sh` removes the files (never a link, i.e. never the deb's); the deb's go with the package.
- `galaxybook-fan status` runs the hook's `--check` for the running kernel and shows the warning and command.
- `render.sh`: `@GBFAN_VERSION@` (from `module/dkms.conf`'s `PACKAGE_VERSION`), so the hook follows releases. Names in `lib/fanpaths.sh` (`KERNEL_HOOK_HEADERS`, `KERNEL_HOOK_POSTINST`, `KERNEL_HOOK_SCRIPT`).
- PLAN.md (§3, §4, §5), `docs/how-it-works.md` (new section), `docs/installing.md`, `packaging/README.md`, CHANGELOG.

## Why
- David, Mint 22.3 → 27 (Ubuntu 24.04 → 26.04 base): kernel `7.0.0-44-generic` was replaced by a new build with the same name. DKMS's hooks saw it already built and kept the old module; the new kernel refused it (*disagrees about version of symbol module_layout*). His other DKMS fixes broke the same way.
- Fedora and Arch give every kernel build a new name, so they never hit this.
- The deb uses links, not files: dpkg makes every file in `/etc` a conffile, kept after `apt remove` and never put back once deleted (the preinst's removal of an `install.sh` copy would have deleted it on a reinstall). A link isn't a conffile.
- The kernel packages run these with `run-parts --exit-on-error`, so the hook always exits 0, and `install.sh` writes real files (a dangling link would make `run-parts` fail the kernel install).

## Tested
- Mocked only, outside the repository: a fake `/lib/modules` tree and a fake `dkms` (`DKMS_REBUILD_ROOT` / `DKMS_REBUILD_DKMS`), under dash and bash. Renders for both layouts; `bash -n` / `dash -n`; no kernel, no headers, no module → nothing; fresh build → no rebuild; headers replaced after the build (new inode, as `cp -p` twice does) → `--check` 1 with the command, one `dkms install … --force`, then fresh again; `updates/` and `extra/` folders; dkms failing or missing → still exit 0; through `run-parts --exit-on-error` as a link; `install-files.sh` with and without `deb`; clone-remove's loop (removes a file, leaves a link); `galaxybook-fan status` with a faked DKMS.
- Not tested: a real Mint/Ubuntu kernel install, a real DKMS rebuild, building the `.deb` (no debhelper here: the PR's workflow builds it).

## For the next person
- `install.sh --check` doesn't report module health, so it wasn't changed.
- The login monitor's "fix isn't active" notification already says `sudo galaxybook-fan rebuild`, which also fixes this case.
- David's other DKMS fixes broke the same way and need the same hook; the template only needs its three names filled in.
