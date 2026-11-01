# galaxybook-fan: technical plan for contributors

This is the handover for anyone (people or coding agents such as Codex) working on this repository. It explains how the project works, what every file is for, and **how changes must be made**. Read the ground rules first, then the newest notes in `handoff/`; the rest is reference.

---

## 1. Ground rules (read first)

1. **Every change is a pull request.** Create a branch, commit, push the branch and open a PR against `main`. Never push to `main`, never merge, never force-push someone else's branch.
2. **David tests every PR on his laptop before merging.** Say in the PR description what to test and how (§8). Say plainly what you could not test (anything needing the real hardware, Secure Boot, a kernel build or a real desktop session).
3. **Never make a release.** Don't change `VERSION`, the version in `module/dkms.conf` or `PKG_VERSION` in `install.sh`; don't create tags (`v*`) or GitHub releases. David releases with his own tool (§7).
4. **One topic per PR.** Before pushing more commits to an existing PR's branch, check it hasn't been merged already (`gh pr view N --json merged` or the REST API); if it has, start a new branch from `main`.
5. **Every user-visible change gets a CHANGELOG line** under `## Unreleased` (§7.2), and a README update when the README describes the thing you changed.
6. **Don't add files you didn't mean to.** Review `git status` before committing; don't use `git add -A` blindly. Build output (`*.o`, `*.ko`, `*.mod*`, `__pycache__`) and test scripts stay out of the repository.
7. **Wording:** British English. Plain words for users: say what happens and what to do.
8. **Handoff notes.** Every PR adds one short note in `handoff/` (`YYYY-MM-DD-short-topic.md`; template in `handoff/README.md`). Before starting, read the notes newer than your last session. When a PR changes how something works, update this file in the same PR, so it always describes the project as it is.
9. **Safety first.** The installer runs as root, builds and signs a kernel module and can import a Secure Boot key. Read §9 before changing anything like that.

---

## 2. What the project is

Makes **fan speed reporting** work on Linux on the **Samsung Galaxy Book 5** series, without a DSDT override.

- Samsung's fan `_FST` method (e.g. `\_SB.PC00.LPCB.FAN0._FST`) does `Local1 = FANT [Local0]` with no `DerefOf()`. Windows tolerates it; ACPICA aborts with `AE_AML_OPERAND_TYPE` whenever the fan is spinning, so the stock `acpi-fan` driver reports I/O errors instead of a speed.
- `galaxybook_fan` is a small **DKMS hwmon module** that reads the same EC field `_FST` reads (e.g. `H_EC.FANS`) through ACPI by name, then applies `_FST`'s level remap and RPM table (`FANT`) itself. Only the broken lookup is bypassed.
- **Nothing is hard-coded per model.** The installer disassembles the machine's own DSDT; `dsdt-fan-config.py` derives and validates the field, remap and table, and writes `galaxybook_fan_config.h` before DKMS builds the module.
- **Supported:** Galaxy Book 5 models `940XHA`, `960XHA`, `960QHA`, `750XHD`, `754XHD`, `750QHA`, `754QHA` (with or without an `NP` prefix; same list as fnkeys-fix-book5). Tested on the 940XHA only. Other Samsung models are refused (earlier Galaxy Books already work with the stock driver); `--force` overrides. Non-Samsung machines are always refused. Kernel 6.8 or newer.
- **Distros:** packages for Fedora 44/45, Ubuntu 24.04/26.04, Mint, Debian 13, MX 25 and Arch/CachyOS; `install.sh` for anything with `dnf`, `apt` or `pacman`. Tested on Fedora 45, Ubuntu 26.04, Linux Mint 22.3, MX Linux 25.3 and CachyOS.
- **Repository:** public since 31 October 2026 (0.7.0). It was `extras/galaxybook-fan` in `david-bartlett/samsung-galaxybook-fixes` until October 2026 (history moved with it; the old folder is tagged `galaxybook-fan-final` there).

## 3. Install method and where things live

Install is a package from the release (rpm, deb or Arch, §10), or `sudo ./install.sh` from a clone or the release's source code. Re-running it over an existing install is fine. `sudo ./uninstall.sh` removes everything it added.

| What | Where |
|---|---|
| Module source for DKMS: `galaxybook_fan.c`, `Makefile`, `dkms.conf`, `gen-config.sh`, `dsdt-fan-config.py`, `models.sh` (no config header: `gen-config.sh` writes it at each build) | `/usr/src/galaxybook-fan-<version>/` |
| `--force` remembered, so DKMS keeps building on a non-Book 5 / already-fixed firmware | `/etc/galaxybook-fan/force` |
| The command | `/usr/local/sbin/galaxybook-fan` (packages: `/usr/bin/galaxybook-fan`) |
| Autoload | `/etc/modules-load.d/galaxybook_fan.conf` (also the quickest "is it installed?" check) |
| Module options (old versions only; install and uninstall remove it) | `/etc/modprobe.d/galaxybook_fan.conf` |
| `acpi-fan` unbind at boot | `/etc/systemd/system/galaxybook-acpi-fan-unbind.service` (older versions used a udev rule, `/etc/udev/rules.d/90-galaxybook-acpi-fan-unbind.rules`, which install and uninstall remove) |
| Keep the module out of dracut images | `/etc/dracut.conf.d/galaxybook-fan.conf` |
| DKMS signing drop-in (only when needed) | `/etc/dkms/framework.conf.d/galaxybook-fan-signing.conf` |
| Fedora shared akmods key config (shared with Andy's fixes; uninstall leaves it) | `/etc/dkms/framework.conf.d/akmods-keys.conf` |
| Temporary "don't rebuild every initramfs" drop-in (removed by a trap) | `/etc/dkms/framework.conf.d/zz-galaxybook-fan-defer-initramfs.conf` |
| Login check scripts | `/usr/local/bin/samsung-galaxybook-fan-check.sh`, `samsung-galaxybook-fan-user-check.sh` |
| Library folder: `dsdt-fan-config.py`, `fanpaths.sh`, `models.sh`, `fan-dkms.sh`, the built `check-galaxybook-fan.sh` | `/usr/local/lib/samsung-galaxybook/fan/` (packages: `/usr/lib/galaxybook-fan/`) |
| Monitor service, user timer and service | `samsung-galaxybook-fan-monitor.service`, `samsung-galaxybook-fan-user-check.{service,timer}` |
| Polkit rule (lets `wheel`/`sudo` users start the monitor) | `/etc/polkit-1/rules.d/49-samsung-galaxybook-fan-monitor.rules` |
| State (kernel, BIOS, install folder and method at last check) | `/var/lib/samsung-galaxybook/fan-state` (`KVER`, `BIOS`, `INSTALL_DIR`, `INSTALL_METHOD` = `clone` or `package`) |
| Notification for the user check | `/run/samsung-galaxybook/fan-status` |
| New-version check: script, user timer and service (60 s after login, then hourly; GitHub at most every 6 hours) | `update-check.sh` and `update.sh` in the library folder; `galaxybook-fan-update-check.{timer,service}` in `/usr/lib/systemd/user/` (packages, enabled for every user) or `~/.config/systemd/user/` (`install.sh`, for the user it ran for). The packages start the update timer in sessions that are already running (`package-scripts.sh`'s `user_systemctl_all`); `install.sh`'s, for the user it ran for, also starts at once |
| New-version check's off switch (`galaxybook-fan updates off`) | `/etc/galaxybook-fan/no-update-check` |
| New-version check's state, per user | `~/.local/state/galaxybook-fan/last-update-check` (when GitHub last answered), `notified-version` (told once per version) |
| Installed version, for the check | `VERSION` in the library folder (packages; `install.sh` writes it too) |
| Shared graphical session helper (Xfce etc.; shared with other Galaxy Book fixes) | `/etc/systemd/user/samsung-galaxybook-session.target`, `/usr/local/bin/samsung-galaxybook-session-start.sh`, `/etc/xdg/autostart/samsung-galaxybook-session.desktop`, `/etc/samsung-galaxybook/session-helper.d/` |

## 4. Repository map

Users run `install.sh` and `uninstall.sh` from the top folder; what DKMS builds is in `module/`, and the helpers `install.sh` uses and installs are in `lib/`.

| File | Purpose |
|---|---|
| `install.sh` | `--check` (derive and show the config, install nothing), `--test-native`, `--force`. Finds the rest through `MODULE_SRC` (`module/`) and `LIB_SRC` (`lib/`). Refuses if the galaxybook-fan package is installed. |
| `module/gen-config.sh` | DKMS `PRE_BUILD` (`dkms.conf`): before every build, reads the DSDT and DMI, checks the model (Book 5 only unless `/etc/galaxybook-fan/force`) and runs the parser to write `galaxybook_fan_config.h`. **On any problem it writes a header that is only an `#error` with the reason**, because DKMS 3.0 ignores a `PRE_BUILD`'s exit status: the build then fails, and the reason is in `make.log`. `GBFAN_DSDT` / `GBFAN_DMI` override the paths for testing. |
| `lib/galaxybook-fan` | The command: `status`, `check` (runs the installed `check-galaxybook-fan.sh`), `rebuild` (DKMS remove + install for the running kernel and every other kernel it's built for that has headers, so `gen-config.sh` reads the firmware again; then reloads and records the state), `test-native`, `update` (the newest release's file for this format, picked from its `SHA256SUMS`, checked against it, installed with dnf / apt / pacman; an `install.sh` copy is told how instead), `updates on|off|status`, `updates check`, `--help` (`cmd_help`: a table of the commands, 80 columns, bold only on a terminal; keep its rows in step with the header comment) (as the user, not root: looks now, ignoring the daily and once-per-version limits, prints the result and shows the notification if there's a newer release). |
| `lib/update-check.sh` | The new-version check, run as the user by `galaxybook-fan-update-check.service` (see *Login check*). |
| `lib/update.sh` (notification) | `gbfan_update_title` / `gbfan_update_text` (shared wording), `gbfan_update_notify` (`notify-update.sh` beside the running script, `GBFAN_HERE`, via `systemd-run --user`; else plain `notify-send`), `gbfan_update_mark_told`. Used by `update-check.sh` and `updates check`. |
| `lib/notify-update.sh`, `lib/notify-dbus.py`, `lib/update-in-terminal.sh` | The notification with **Update now** (a terminal, found from `xdg-terminal-exec`, the desktop's usual one or any installed, running `update-in-terminal.sh`, i.e. `sudo galaxybook-fan update`) and **What's new** (`xdg-open` the release page, then, 2 s later, a fresh copy of the notification is shown (desktops close it on any button, so there's never two); *Update now* or closing it ends it. **Not** the `resident` hint (`notify-send` reports a button only once the notification closes, and KDE kept it), **nor** `--replace-id` (KDE quietly updates the closed one instead of showing it)) where `notify-send --action` exists; on GNOME through `notify-dbus.py` instead (see §4). `notify-update.sh` waits for a click, so `update-check.sh` starts it with `systemd-run --user`; without that, a plain notification. |
| `lib/update.sh` | Is there a newer release: `gbfan_installed_version` (the library folder's `VERSION`, which `install.sh` now writes too; else DKMS), `gbfan_latest_version` (where `…/releases/latest` redirects: no API, no rate limit; 404 while private), `gbfan_version_newer`, `gbfan_update_hint`. `GBFAN_REPO_URL` points it elsewhere for tests. |
| `lib/fanpaths.sh` | **All names and paths**, for the `clone` layout (install.sh: `/usr/local`) and the `package` layout (`/usr`). Sourced by `install.sh`, `uninstall.sh`, the command and the login check. `gbfan_package_installed` (rpm/dpkg/pacman). |
| `lib/package-scripts.sh` | What every package format runs: `configure` after install/upgrade, `remove` before removal (never on upgrade). See `packaging/README.md`. |
| `packaging/` | `files/*.in` (units, scripts, polkit rule, session helper, dracut, autoload) **shared by `install.sh` and the packages**, filled in by `render.sh clone|package`; `install-files.sh` (a package's files, every format); `pre-script.sh` (the pre-install step: the Book 5 check in `files/pkg-pre.sh.in`, then removing an `install.sh` copy, with `lib/fanpaths.sh`, `lib/fan-dkms.sh` and `lib/clone-remove.sh` built in; bash); `rpm/` (spec, `build.sh`); `debian/` (control, rules, maintainer scripts, `build.sh`); `arch/` (`PKGBUILD`, `galaxybook-fan.install`). |
| `lib/fan-dkms.sh` | DKMS steps shared by `install.sh`, `uninstall.sh`, the command and the packages: remove all versions, defer/resume the initramfs rebuild, version and kernel list, the build-failure reason from `make.log`, rebuild one kernel, unload (`modprobe -r`, else `rmmod`); `gbfan_unbind_acpi_fan` (only while `galaxybook_fan` is loaded) / `gbfan_bind_acpi_fan`; `gbfan_headers_cmd` (the headers package for a kernel: pacman pkgbase, apt or dnf). |
| `uninstall.sh` | Removes everything `install.sh` added and rebinds `acpi-fan`, with `lib/clone-remove.sh`. |
| `lib/clone-remove.sh` | **The removal steps for a copy installed with `install.sh`** (`gbfan_remove_clone`, `gbfan_clone_installed`), shared by `uninstall.sh` and the packages' pre-install step, which removes such a copy before installing. Change removal here, not in `uninstall.sh`. |
| `module/galaxybook_fan.c` | The hwmon module. At load it checks the DMI product and the DSDT's OEM ID, table ID and revision against the config (refuses on a mismatch, i.e. after a BIOS update, unless `force=1`), then checks the field exists and reads. |
| `module/galaxybook_fan_config.h` | Default config for the 940XHA so the module builds standalone. The installer replaces it in `/usr/src` with one generated for the running machine. |
| `lib/dsdt-fan-config.py` | Parses the disassembled DSDT: `--dsl … --product … --out config.h` writes the header; `--status` prints `broken`, `fixed` or `unknown`. Never guesses: anything outside the known `_FST` shape is an error (exit 1). |
| `lib/samsung-galaxybook-fan-check.sh` | `--test-native` (bind the stock `acpi-fan` briefly while the fan spins and see if it reads), `--monitor` (the root side of the login check), `--record-state [INSTALL_DIR]`. |
| `lib/models.sh` | **The one model list:** `BOOK5_MODELS` (the series) and `CONFIRMED_MODELS` (reported working), plus `gbfan_model` (upper-case, drop `NP`) and `gbfan_in_list`; and `gbfan_dsdt_overridden` (the kernel log's `Table Upgrade: override [DSDT`, e.g. the old fanspeed-fix-cpio; `GBFAN_KLOG` for tests) with its message. Sourced by `install.sh`, `gen-config.sh`, the packages' pre-install step and the login monitor; built into the check script. |
| `tools/check-galaxybook-fan.sh` | The read-only "will it work on my laptop?" check (§5.1). Run from a clone it uses `lib/`; the release copy is one file. |
| `tools/build-check-script.sh` | `bash tools/build-check-script.sh OUT [VERSION]`: the single-file copy, with `lib/models.sh` and `lib/dsdt-fan-config.py` built in at its `#@EMBED@` line. The release workflow runs it. |
| `.github/ISSUE_TEMPLATE/` | Issue forms: *Works on my model* (asks for the check's report), *Bug report*; `config.yml` links the confirmed list. |
| `module/Makefile`, `module/dkms.conf` | Kernel module build and DKMS definition. `install.sh` copies them, the `.c` and the generated config into `/usr/src/galaxybook-fan-<version>/`, flat. |
| `LICENSE` | GNU GPL version 2, the licence the module already declares (`SPDX-License-Identifier: GPL-2.0`). |
| `VERSION` | The release version, `X.Y.Z`. The release tool keeps `PACKAGE_VERSION` in `module/dkms.conf` and `PKG_VERSION` in `install.sh` in step with it (§7.1). |
| `CHANGELOG.md` | Release notes (§7.2). |
| `PLAN.md`, `AGENTS.md`, `handoff/` | This file, the short rules for agents, and one note per PR. |
| `.github/workflows/release.yml`, `.github/release-notes.sh`, `.github/release-install.md` | The release workflow and the release page's text (§7.1). |

## 5. How it works

### Install (`install.sh`)

1. Checks root, distro (`dnf`/`apt`/`pacman`), Samsung vendor and model (`BOOK5_MODELS` / `CONFIRMED_MODELS` from `lib/models.sh`), kernel ≥ 6.8.
2. Installs what's missing: `iasl`, `python3`, `dkms`, `make`, `gcc`, kernel headers, `mokutil` (EFI), polkit, `notify-send`. Warns if the user isn't in `wheel`/`sudo`.
3. Disassembles the DSDT, runs `dsdt-fan-config.py`. Refuses if `_FST` is already fixed (`--force` overrides) or the shape is unknown (saves the DSL to `/tmp/galaxybook-fan-dsdt.dsl`).
4. Secure Boot: finds the key DKMS will sign with (`framework.conf`, then `framework.conf.d/*.conf` in order, falling back to `/var/lib/dkms/mok.*`); generates and/or offers `mokutil --import` if needed; checks the built module really is signed.
5. Removes any older DKMS versions and `/usr/src/galaxybook-fan-*`, copies the module source with `gen-config.sh`, the parser and `models.sh` (`--force` also writes `/etc/galaxybook-fan/force`), `dkms add` / `dkms install` with the initramfs rebuild deferred. DKMS's `PRE_BUILD` writes the config; a failed build prints `gen-config.sh`'s reason.
6. Autoload, unbind service, dracut omit, login check (scripts, units, polkit, session helper where needed), the library folder and the `galaxybook-fan` command, then `--record-state "$SCRIPT_DIR" clone`.

**After a BIOS update** the module refuses to load (its DSDT check). The login check tells the user to run `sudo galaxybook-fan rebuild`, which rebuilds through DKMS, so `gen-config.sh` reads the new firmware. Uninstall hints depend on `INSTALL_METHOD`: `./uninstall.sh` in the recorded folder, or remove the package.

### 5.1 check-galaxybook-fan.sh and confirming models

`sudo bash check-galaxybook-fan.sh` installs and changes nothing. It reads the DMI vendor, product and BIOS, disassembles the DSDT with `iasl` and runs the parser exactly as the installer does, then says one of: not a Samsung; not a Book 5 (and, if it has the bug anyway, asks for a report); fan method not recognised (asks a Book 5 owner for a bug report); firmware already fixed (fix not needed); **should work**, with *already confirmed, nothing to report*, or *not confirmed yet*. When the fix is installed and `galaxybook_fan` reads a non-zero speed on an unconfirmed model, it prints a report to paste into a *Works on my model* issue. Exit status: 0 fine, 1 won't work / problem, 2 couldn't check (not root, `iasl` missing).

**When a *Works on my model* report comes in:** check the report (Book 5 model, `Firmware: … fix needed`, a plausible RPM), add the model to `CONFIRMED_MODELS` in `lib/models.sh` **and** to the *Confirmed working* table at the top of `README.md` (removing it from the "expected to work" line), with a CHANGELOG line. One PR, then close the issue with a link to it.

### Login check

Ten seconds after login a user timer checks whether the kernel or BIOS changed or the module isn't loaded. If so it starts the root monitor (polkit), which works out what happened and leaves a notification: BIOS fixed `_FST` → uninstall; BIOS changed, still broken → re-run `install.sh`; `_FST` unrecognisable → run `--test-native`; new kernel, module not loaded → re-run `install.sh`; new kernel reads the fan natively → uninstall. **The notifications name the folder `install.sh` was last run from** (recorded state), so a moved clone needs `install.sh` re-run once. Nothing is installed or removed automatically.

**New versions:** a second user timer, `galaxybook-fan-update-check.timer` (60 s after login, so its notification doesn't arrive together with fingerprint-fix-sdcp's at 30 s; then hourly; enabled globally by the packages, per user by `install.sh`), starts `galaxybook-fan-update-check.service`, which skips itself unless the fix is installed and `/etc/galaxybook-fan/no-update-check` (`galaxybook-fan updates off`) is absent. It runs `lib/update-check.sh` (installed in the library folder): GitHub at most every 6 hours (`~/.local/state/galaxybook-fan/last-update-check`, written only when GitHub answered, and not while a newer release's files are missing), and a newer release only once its `SHA256SUMS` lists this system's package (`gbfan_release_ready` in `lib/update.sh`; `galaxybook-fan updates check` too), so `galaxybook-fan update` can always install what was announced; otherwise the next hourly run looks again, trying for about 2 minutes while the network comes up (8 tries, 15 s apart), and tells once per version (`notified-version`, written only if `notify-send` worked). The text always gives `sudo galaxybook-fan update` and the release link, each on its own line (GNOME shows no buttons); where buttons work, `notify-update.sh` adds **Update now** and **What's new**; on GNOME only (not Budgie) it's shown by `lib/notify-dbus.py` (Python + PyGObject, straight over D-Bus; it stays running for the button press, which GNOME sends only to the program that made the notification), because `notify-send` 0.8.8 on Ubuntu 26.04 says *Actions are not supported* and drops the buttons although GNOME lists `actions` and shows them; it's sent as critical (`-u critical`: GNOME ignores `-t 0` and moves normal notifications into its list after a few seconds), and clicking the notification (its `default` action) opens the release page too, and the text says so — other desktops can draw `default` as a third button. A notification is drawn by the *installed* version's scripts, so a change to it shows from the release after the one that brings it. Kept apart from the login check so that waiting for the network never holds up its notifications.

## 6. Coding conventions

- **Shell:** bash, `set -uo pipefail` as the scripts already use; `bash -n` clean. Keep paths as the variables at the top of each script; `install.sh` and `uninstall.sh` must agree on every path.
- **Python:** `dsdt-fan-config.py` uses only the standard library and runs with `python3 -I`. Keep it strict: when unsure, refuse.
- **C:** kernel style; must build against 6.8 and newer. Keep the load-time checks.
- **Messages:** say what happened and what the user can do next, with the exact command.
- **Comments:** explain why, briefly. Match the existing style.

---

## 7. Releases (David only) and the CHANGELOG

### 7.1 How David releases

David releases with a release tool in his private repository `david-bartlett/samsung-galaxybook-dev-tools` (folder `galaxybook-fan-github`, a copy of the fingerprint-fix-sdcp one). Its Release button sets `VERSION` (and the version in `module/dkms.conf` and `install.sh`), turns `## Unreleased` into `## X.Y.Z — date`, commits, tags `vX.Y.Z` and pushes, then adds a fresh `## Unreleased`.

**Release file names are an interface:** `galaxybook-fan update` finds this system's file in the release's `SHA256SUMS` by name (`galaxybook-fan-X.Y.Z-N.noarch.rpm`, `galaxybook-fan_X.Y.Z-N_all.deb`, `galaxybook-fan-X.Y.Z-N-any.pkg.tar.zst`). Change those only together with `gbfan_package_pattern` (`lib/update.sh`, used by `cmd_update` and the new-version check), and keep `SHA256SUMS` on every release.

The tag starts `.github/workflows/release.yml`:
- checks that `VERSION`, `module/dkms.conf`, `install.sh` and the CHANGELOG all have the tag's version;
- builds the packages: the `.rpm` in `fedora:45` (`packaging/rpm/build.sh`), the `.deb` in `debian:13` (`packaging/debian/build.sh`) and the Arch `.pkg.tar.zst` in `archlinux:base-devel` (`makepkg` in `packaging/arch/`), plus the release `PKGBUILD` (from `packaging/arch/PKGBUILD.release.in`, with the tarball's checksum once the repository is public), `galaxybook-fan.install` and `check-galaxybook-fan.sh`;
- creates the GitHub release **as a draft**, with notes from `.github/release-notes.sh`: the install table (`.github/release-install.md`), *What's new* (the bold lines) and the whole section collapsed under *Full changelog*;
- attaches the files and `SHA256SUMS`, then publishes it (`--latest`). Drafts are hidden from `releases/latest` and the releases page, so the new-version check never finds a release without its files. A re-run publishes only a release that is still a draft, so re-attaching an old release's files never makes it the latest.

**On every pull request** the same workflow builds the packages without releasing: they're the run's *Artifacts* (Actions → the PR's run), so David can test exactly what a release would attach. *Run workflow* with an existing tag re-attaches the files to that release.

**Contributors never do any of this.** Versioning (for David's information): fixes → `x.y.Z`, features → `x.Y.0`, a change users must act on → `X.0.0`.

### 7.2 CHANGELOG rules

- Add lines under `## Unreleased` at the top (create it if missing; never add lines to an already released section).
- Each change is a `- ` line. Group related lines; separate groups with a blank line.
- A **bold headline line** (`- **Short headline:** a few words`) for the release page's *What's new*. Keep it short.
- Then **plain lines** with the full detail (shown only under the collapsed *Full changelog*).
- **Every release needs at least one bold line.**

---

## 8. Testing

### 8.1 What you can do without the hardware

- `bash -n install.sh uninstall.sh lib/samsung-galaxybook-fan-check.sh`; `python3 -m py_compile lib/dsdt-fan-config.py`.
- **Parser:** run `dsdt-fan-config.py` against DSL text (a saved 940XHA DSDT, or small hand-made DSL showing the broken, fixed and unknown `_FST` shapes). Keep test files **outside the repository**.
- **check-galaxybook-fan.sh without the laptop:** write a small ASL file with the 940XHA's fan device (`FAN0` with `_FST` reading `^^H_EC.FANS`, a `Switch` remap, `If ((Local0 == Zero))`, `Local0--`, `Local1 = FANT [Local0]`, `Local1 += 0x0A`; `H_EC` with a SystemMemory `ECR` region and `FANS, 4` at offset `0x87`; DSDT IDs `SECCSD LH43STAR 0x01072009`), compile it with `iasl`, and variants with `DerefOf (FANT [Local0])` (fixed) and an extra statement (unrecognised). Build the script with `tools/build-check-script.sh`, then run a copy with `/sys/class/dmi/id`, `/sys/firmware/acpi/tables/DSDT`, `/sys/class/hwmon`, `/etc/modules-load.d/galaxybook_fan.conf`, `/usr/src/galaxybook-fan-*` and `/etc/os-release` redirected (`sed`) to a scratch folder. Keep all of this outside the repository.
- **Module:** `make -C module KDIR=/lib/modules/<version>/build` builds against any installed headers; it can't be loaded meaningfully without the hardware.
- Describe in the PR what you checked and what you couldn't.

### 8.2 What David tests (write the steps in the PR)

David has a Galaxy Book 5 Pro (940XHA) that multi-boots **Fedora 45** (KDE), **Ubuntu 26.04** (GNOME), **Linux Mint** (Cinnamon), **MX Linux 25** (Xfce) and **CachyOS** (KDE, Limine), with Windows; he boots each from the F10 menu. On each distro he tests a branch like this:

```bash
cd ~/git/github.com-david-bartlett/galaxybook-fan
git fetch && git switch <branch>
sudo ./install.sh --check
sudo ./install.sh
sensors | grep -A2 galaxybook_fan     # fan speed shown; spin the fan up to see it change
```

Give him a short numbered list of what to run and what he should see (and `sudo ./uninstall.sh` when the PR touches removal).

For a PR that changes packaging, he can also test the packages the PR's workflow run built: Actions → the run → *Artifacts* (`galaxybook-fan-rpm`, `-deb`, `-arch`), unzip, then `sudo dnf install ./…rpm`, `sudo apt install ./…deb` or `sudo pacman -U ./…zst`. On Arch, `sudo ./uninstall.sh` first if an `install.sh` copy is there.

---

## 9. Safety and gotchas

- **Never guess the firmware.** If the DSDT doesn't match the known shape, refuse and explain; a wrong field or table gives wrong readings with no warning.
- **Never put a ready-made config header in `/usr/src`.** `module/galaxybook_fan_config.h` (940XHA) is only for building by hand from the repository; DKMS must always get its header from `gen-config.sh`, which fails the build with an `#error` rather than build for the wrong machine.
- **`acpi-fan` is only unbound while `galaxybook_fan` is loaded** (the unit's `ConditionPathIsDirectory=/sys/module/galaxybook_fan`, after `systemd-modules-load`; `gbfan_unbind_acpi_fan`). Where our module isn't loaded, the stock driver may well work (an earlier Galaxy Book, fixed firmware, a DSDT override), and unbinding it would leave no fan sensor at all. Keep it that way.
- **A DSDT override hides the firmware:** with one, `/sys/firmware/acpi/tables/DSDT` is the override. Everything that reads the DSDT checks `gbfan_dsdt_overridden` first and says to remove it.
- **Updates are never installed by themselves:** the update check (`galaxybook-fan-update-check.timer`) only notifies; `sudo galaxybook-fan update` installs, through the package manager (which asks), and only a file whose checksum matches the release's `SHA256SUMS`. That protects against a broken download, not against a compromised GitHub account (see the release-tag ruleset in §11).
- **Keep the module's load-time DMI and DSDT checks.** They are what makes a BIOS update pause the fix instead of reporting nonsense.
- **Nothing in the boot chain:** no DSDT override, no initrd change, so a BIOS update can never make the laptop unbootable. Keep it that way; the module loads from `modules-load.d` after boot.
- **Secure Boot keys:** never generate a second key when one is configured; Fedora shares one akmods key with Andy's fixes (`akmods-keys.conf` is shared and never removed). Check that the module really was signed.
- **Shared files:** the session helper and `/var/lib/samsung-galaxybook/` are shared with other Galaxy Book fixes. Uninstall removes only this fix's parts.
- **DKMS and initramfs:** keep the deferred-rebuild drop-in removed by a trap, even on failure; never change DKMS's own settings.
- **`--test-native`** is only conclusive while the fan is spinning; don't report "works" from an idle fan.

---

## 10. Packaging plan (agreed 2026-10-31, in progress)

Goal: rpm, deb and Arch packages attached to each release, like fingerprint-fix-sdcp. `install.sh` stays for other distros and for testing. Same distros as fingerprint-fix-sdcp: **Fedora 44/45, Ubuntu 24.04/26.04, Linux Mint, Debian 13, MX Linux 25, Arch / CachyOS**. galaxybook-fan already runs on all of them with `install.sh`.

### 10.1 One architecture-independent package per format

The package ships source, scripts and units; DKMS compiles the module on the user's machine. So there's one package per format, not one per distro release:

| Format | Package | Architecture | Release files |
| --- | --- | --- | --- |
| rpm | `galaxybook-fan` | `noarch` | one `.rpm` for Fedora 44 and 45 |
| deb | `galaxybook-fan` | `all` | one `.deb` for Ubuntu, Mint, Debian, MX |
| Arch | `galaxybook-fan` | `any` | `PKGBUILD`, `galaxybook-fan.install` **and** a prebuilt `.pkg.tar.zst` (fine here, unlike fingerprint-fix-sdcp's driver, because nothing in it links against system libraries) |

License `GPL-2.0-only`. Dependencies: `dkms`, the `iasl` tools (`acpica-tools` / `acpica-tools` / `acpica`), `python3`, polkit, `notify-send` (`libnotify` / `libnotify-bin`), and kernel headers (Fedora `kernel-devel-matched`; Ubuntu/Debian through `dkms`'s recommends; Arch: depends on the kernel, so the `.install` checks for headers and says which package to add).

### 10.2 What `install.sh` does interactively, and how packages do it

1. **Config from this machine's DSDT → DKMS `PRE_BUILD`.** `module/dkms.conf` gets `PRE_BUILD="gen-config.sh"`: on every DKMS build (install, each new kernel) it reads `/sys/firmware/acpi/tables/DSDT`, runs `iasl -d` and `dsdt-fan-config.py`, and writes `galaxybook_fan_config.h` in the build folder. One code path for `install.sh` and the packages. On an unsupported machine the build fails with the reason. The module's load-time DMI/DSDT checks stay as the safety net.
2. **Secure Boot → no prompts in packages.** Sign with whatever key DKMS is configured for (Fedora akmods key, Ubuntu shim key, DKMS's own). If it isn't enrolled, say so and give the exact `mokutil --import` command. `install.sh` keeps offering to import it interactively.
3. **"Re-run install.sh" after a BIOS update → a `galaxybook-fan` command.** `galaxybook-fan check` (as `install.sh --check`), `galaxybook-fan rebuild` (re-runs the DKMS build for the new firmware), `galaxybook-fan test-native`, `galaxybook-fan status`. The login check records how the fix was installed and names the right command in its notifications: `sudo galaxybook-fan rebuild` for a package install, `sudo ./install.sh` in its folder for a clone install.

Also:
- **Galaxy Book 5 only (David's rule):** the packages install only on a Samsung whose DMI product is in the Book 5 list (`940XHA`, `960XHA`, `960QHA`, `750XHD`, `754XHD`, `750QHA`, `754QHA`, with or without `NP`; the same list and normalisation as `install.sh`). One list, in one shared file, used by `install.sh`, the scriptlets and `gen-config.sh`; Book 6 is added there later.
  - **rpm `%pre` and deb `preinst`** refuse anything else (exit 1, with the reason), so nothing is installed. `GALAXYBOOK_FAN_FORCE=1` overrides, like `install.sh --force` (same idea as fingerprint-fix-sdcp's `FPRINT_SDCP_FORCE`).
  - **Arch:** pacman ignores the exit status of `.install` scripts, so `pre_install` can only warn. The real gate there is `gen-config.sh`, which also checks the model: the module never builds on anything but a Book 5, whatever the format, and `post_install` says why it wasn't built.
- **Old versions on upgrade:** `configure` removes every other registered version from DKMS. A deb upgrade deletes the old `/usr/src` copy before `postinst`, and DKMS then refuses to remove it (seen on Mint 22 and Ubuntu 26.04), so `gbfan_dkms_forget` deletes what's left in `/var/lib/dkms` (and its `kernel-*` links, DKMS's record of which kernels it's installed for). Those kernels then get the new version too, where their headers are (on MX a leftover 0.5.0 still held two older kernels). The old versions' module files stay in `/lib/modules/<kernel>/updates/dkms/`, and Debian 13's DKMS then refuses to install over them (*already installed (unversioned module)*): `gbfan_dkms_install` removes the files that message names (only `galaxybook_fan.ko*` under `/lib/modules`) and tries once more (also used by `galaxybook-fan rebuild`). It reads the message whatever DKMS returns: MX's `dkms` wrapper adds every kernel to each install and returns 0 even when some were refused, so success is checked with `dkms status` (`gbfan_dkms_installed_for`), and `configure` installs the new version for every kernel it's only *built* for. DKMS 3.0 (Mint 22) instead keeps an old file it takes for the same module (*exactly matches … will not replace*; the module has no version of its own) and marks the new one installed, so `dkms status` says *Diff between built and installed module*: `gbfan_dkms_install` then runs `dkms install --force` for each kernel with that warning. `gbfan_dkms_version` prefers the installed `VERSION`, else the newest registered.
- **A failed DKMS build never fails the install** (`package-scripts.sh configure` always returns 0): it says why, the package ends up installed and configured (checked with dnf and apt), and `sudo galaxybook-fan rebuild` builds it once sorted. The build itself fails cleanly with `gen-config.sh`'s reason (step 1).
- **Removal only, not upgrade:** tidy-up in rpm `%preun`/`%postun` when `$1 == 0`, deb `prerm remove`/`postrm purge`, Arch `pre_remove`. Never fail a removal.
- **Clone install and package are never installed together.** `install.sh` and `uninstall.sh` refuse while the package is installed. The rpm's `%pre` and the deb's `preinst` (first install only) **remove an `install.sh` copy** with `uninstall.sh`'s own steps (`lib/clone-remove.sh`, built in by `packaging/pre-script.sh`), after the Book 5 check, and carry on, as fingerprint-fix-sdcp's packages do. pacman checks for existing files before running anything and refuses over a same-version copy's `/usr/src/galaxybook-fan-<ver>/` files (the `/etc` autoload file is a `backup` file, so it doesn't clash), so on Arch run `sudo ./uninstall.sh` first, as with fingerprint-fix-sdcp. An older copy doesn't clash: `post_install` removes it after unpacking, with `GBFAN_KEEP_VERSION` set so the removal keeps the files the package now owns (`package-scripts.sh replace-clone`).

### 10.3 Steps (one PR each)

1. ✅ **Preparation:** `PRE_BUILD` config generation (`module/gen-config.sh`), the shared paths file (`lib/fanpaths.sh`) and DKMS helpers (`lib/fan-dkms.sh`), the `galaxybook-fan` command, notifications that know the install method. `install.sh` keeps working throughout. Checked: DKMS 3.0 ignores the `PRE_BUILD` exit status, hence the `#error` header.
2. ✅ **`packaging/` shared files:** units, polkit rule, scripts as templates (`packaging/files/*.in`, `render.sh`, `install-files.sh`), as in fingerprint-fix-sdcp. `install.sh` renders the same templates (`put_rendered`). The package's session helper has its own names (`galaxybook-fan-session.*`), so it never owns a file fingerprint-fix-sdcp's package or a clone install also writes (deb and pacman refuse two packages owning one file).
3. ✅ **rpm** (`packaging/rpm/`: spec, `build.sh`). `noarch`; `%pre -p /bin/bash` = `packaging/pre-script.sh` (removes an `install.sh` copy since PR #17); `%post` / `%preun` call `lib/package-scripts.sh`.
4. ✅ **deb** (`packaging/debian/`: control, rules, maintainer scripts, `build.sh`; debhelper). `Architecture: all`, version `X.Y.Z-N` with no release tag (nothing in it depends on the release). `preinst install` = `packaging/pre-script.sh` (`#!/bin/bash`); `postinst configure` / `prerm remove` call `lib/package-scripts.sh`. The two `/etc` files are conffiles, so `gbfan_clone_installed` doesn't count the autoload file (a removed-not-purged deb leaves it).
5. ✅ **Arch** (`packaging/arch/`: `PKGBUILD` packaging the working tree, `galaxybook-fan.install`; `arch=any`). `post_install` / `post_upgrade` / `pre_remove` call `lib/package-scripts.sh`; `post_install` / `post_upgrade` first run `package-scripts.sh replace-clone` (removes an older install.sh copy after unpacking, keeping what the package owns; a same-version copy makes pacman refuse first, over its `/usr/src` files, so the README says `uninstall.sh` first) and name the missing headers package (`/usr/lib/modules/<kernel>/pkgbase` + `-headers`). Arch's DKMS hooks build for every kernel with headers. Step 6 adds the release `PKGBUILD` (from the tarball) and CI's `.pkg.tar.zst`.
6. ✅ **Release workflow:** builds all three (and on every PR, as artifacts), attaches them with the release `PKGBUILD`, `galaxybook-fan.install`, the check script and `SHA256SUMS`, and the release page has a per-distro download-and-install table. The rpm has no `.fcNN` in its name (`%{?dist}` dropped: one noarch file for Fedora 44 and 45).

David tests each step on his laptop's distros before merging; the first packaged release follows step 6.

## 11. Ideas not done yet (ask David before starting)

- **Galaxy Book 6:** support it if its firmware has the same `_FST` bug (add its models after checking a real DSDT). The repository name is kept generic for this.
- **Branch ruleset on `main`** (block force pushes, restrict deletions; bypass: repository admin; no required PR, as the release tool pushes to `main`). The `v*` tag ruleset is in place since going public.
- Testing the "signing key not enrolled" path and Book 5 models other than the 940XHA on real hardware.
