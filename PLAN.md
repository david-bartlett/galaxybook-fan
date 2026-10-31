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
- **Distros:** anything with `dnf`, `apt` or `pacman`. Tested on Fedora 45, Ubuntu 26.04, Linux Mint 27, MX Linux 25 and CachyOS.
- **Repository:** private for now; David makes it public when it's ready for other people. It was `extras/galaxybook-fan` in `david-bartlett/samsung-galaxybook-fixes` until October 2026 (history moved with it; the old folder is tagged `galaxybook-fan-final` there).

## 3. Install method and where things live

Install is `sudo ./install.sh` from a clone (no packages yet; see the plan in §10). Re-running it over an existing install is fine. `sudo ./uninstall.sh` removes everything it added.

| What | Where |
|---|---|
| Module source for DKMS (with the generated config) | `/usr/src/galaxybook-fan-<version>/` |
| Autoload | `/etc/modules-load.d/galaxybook_fan.conf` (also the quickest "is it installed?" check) |
| Module options (old versions only; install and uninstall remove it) | `/etc/modprobe.d/galaxybook_fan.conf` |
| `acpi-fan` unbind at boot | `/etc/systemd/system/galaxybook-acpi-fan-unbind.service` (older versions used a udev rule, `/etc/udev/rules.d/90-galaxybook-acpi-fan-unbind.rules`, which install and uninstall remove) |
| Keep the module out of dracut images | `/etc/dracut.conf.d/galaxybook-fan.conf` |
| DKMS signing drop-in (only when needed) | `/etc/dkms/framework.conf.d/galaxybook-fan-signing.conf` |
| Fedora shared akmods key config (shared with Andy's fixes; uninstall leaves it) | `/etc/dkms/framework.conf.d/akmods-keys.conf` |
| Temporary "don't rebuild every initramfs" drop-in (removed by a trap) | `/etc/dkms/framework.conf.d/zz-galaxybook-fan-defer-initramfs.conf` |
| Login check scripts | `/usr/local/bin/samsung-galaxybook-fan-check.sh`, `samsung-galaxybook-fan-user-check.sh` |
| DSDT parser copy for the monitor | `/usr/local/lib/samsung-galaxybook/fan/dsdt-fan-config.py` |
| Monitor service, user timer and service | `samsung-galaxybook-fan-monitor.service`, `samsung-galaxybook-fan-user-check.{service,timer}` |
| Polkit rule (lets `wheel`/`sudo` users start the monitor) | `/etc/polkit-1/rules.d/49-samsung-galaxybook-fan-monitor.rules` |
| State (kernel, BIOS, install folder at last check) | `/var/lib/samsung-galaxybook/fan-state` |
| Notification for the user check | `/run/samsung-galaxybook/fan-status` |
| Shared graphical session helper (Xfce etc.; shared with other Galaxy Book fixes) | `/etc/systemd/user/samsung-galaxybook-session.target`, `/usr/local/bin/samsung-galaxybook-session-start.sh`, `/etc/xdg/autostart/samsung-galaxybook-session.desktop`, `/etc/samsung-galaxybook/session-helper.d/` |

## 4. Repository map

Users run `install.sh` and `uninstall.sh` from the top folder; what DKMS builds is in `module/`, and the helpers `install.sh` uses and installs are in `lib/`.

| File | Purpose |
|---|---|
| `install.sh` | `--check` (derive and show the config, install nothing), `--test-native`, `--force`. Finds the rest through `MODULE_SRC` (`module/`) and `LIB_SRC` (`lib/`). |
| `uninstall.sh` | Removes everything `install.sh` added and rebinds `acpi-fan`. |
| `module/galaxybook_fan.c` | The hwmon module. At load it checks the DMI product and the DSDT's OEM ID, table ID and revision against the config (refuses on a mismatch, i.e. after a BIOS update, unless `force=1`), then checks the field exists and reads. |
| `module/galaxybook_fan_config.h` | Default config for the 940XHA so the module builds standalone. The installer replaces it in `/usr/src` with one generated for the running machine. |
| `lib/dsdt-fan-config.py` | Parses the disassembled DSDT: `--dsl … --product … --out config.h` writes the header; `--status` prints `broken`, `fixed` or `unknown`. Never guesses: anything outside the known `_FST` shape is an error (exit 1). |
| `lib/samsung-galaxybook-fan-check.sh` | `--test-native` (bind the stock `acpi-fan` briefly while the fan spins and see if it reads), `--monitor` (the root side of the login check), `--record-state [INSTALL_DIR]`. |
| `lib/models.sh` | **The one model list:** `BOOK5_MODELS` (the series) and `CONFIRMED_MODELS` (reported working), plus `gbfan_model` (upper-case, drop `NP`) and `gbfan_in_list`. Sourced by `install.sh`; built into the check script. |
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
5. Removes any older DKMS versions and `/usr/src/galaxybook-fan-*`, copies the source plus the generated config, `dkms add` / `dkms install` with the initramfs rebuild deferred.
6. Autoload, unbind service, dracut omit, login check (scripts, units, polkit, session helper where needed), then `--record-state "$SCRIPT_DIR"`.

### 5.1 check-galaxybook-fan.sh and confirming models

`sudo bash check-galaxybook-fan.sh` installs and changes nothing. It reads the DMI vendor, product and BIOS, disassembles the DSDT with `iasl` and runs the parser exactly as the installer does, then says one of: not a Samsung; not a Book 5 (and, if it has the bug anyway, asks for a report); fan method not recognised (asks a Book 5 owner for a bug report); firmware already fixed (fix not needed); **should work**, with *already confirmed, nothing to report*, or *not confirmed yet*. When the fix is installed and `galaxybook_fan` reads a non-zero speed on an unconfirmed model, it prints a report to paste into a *Works on my model* issue. Exit status: 0 fine, 1 won't work / problem, 2 couldn't check (not root, `iasl` missing).

**When a *Works on my model* report comes in:** check the report (Book 5 model, `Firmware: … fix needed`, a plausible RPM), add the model to `CONFIRMED_MODELS` in `lib/models.sh` **and** to the *Confirmed working* table at the top of `README.md` (removing it from the "expected to work" line), with a CHANGELOG line. One PR, then close the issue with a link to it.

### Login check

Ten seconds after login a user timer checks whether the kernel or BIOS changed or the module isn't loaded. If so it starts the root monitor (polkit), which works out what happened and leaves a notification: BIOS fixed `_FST` → uninstall; BIOS changed, still broken → re-run `install.sh`; `_FST` unrecognisable → run `--test-native`; new kernel, module not loaded → re-run `install.sh`; new kernel reads the fan natively → uninstall. **The notifications name the folder `install.sh` was last run from** (recorded state), so a moved clone needs `install.sh` re-run once. Nothing is installed or removed automatically.

## 6. Coding conventions

- **Shell:** bash, `set -uo pipefail` as the scripts already use; `bash -n` clean. Keep paths as the variables at the top of each script; `install.sh` and `uninstall.sh` must agree on every path.
- **Python:** `dsdt-fan-config.py` uses only the standard library and runs with `python3 -I`. Keep it strict: when unsure, refuse.
- **C:** kernel style; must build against 6.8 and newer. Keep the load-time checks.
- **Messages:** say what happened and what the user can do next, with the exact command.
- **Comments:** explain why, briefly. Match the existing style.

---

## 7. Releases (David only) and the CHANGELOG

### 7.1 How David releases

David releases with a release tool in his private repository `david-bartlett/samsung-galaxybook-dev-tools` (folder `galaxybook-fan-github`, a copy of the fingerprint-fix-sdcp one). Its Release button sets `VERSION` (and the version in `module/dkms.conf` and `install.sh`), turns `## Unreleased` into `## X.Y.Z — date`, commits, tags `vX.Y.Z` and pushes, then adds a fresh `## Unreleased`. The workflow also builds `check-galaxybook-fan.sh` and attaches it; the release page's first step links to it. The tag starts `.github/workflows/release.yml`, which checks that `VERSION`, `module/dkms.conf`, `install.sh` and the CHANGELOG all have the tag's version, then creates the GitHub release with notes from `.github/release-notes.sh`: the install steps (`.github/release-install.md`), *What's new* (the bold lines) and the whole section collapsed under *Full changelog*. There are no packages yet; users download the source code GitHub attaches to every release.

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

---

## 9. Safety and gotchas

- **Never guess the firmware.** If the DSDT doesn't match the known shape, refuse and explain; a wrong field or table gives wrong readings with no warning.
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
- **Check before relying on it:** what each package manager does when the DKMS build fails during install (it must give a clear message, not leave apt or dnf half-configured).
- **Removal only, not upgrade:** tidy-up in rpm `%preun`/`%postun` when `$1 == 0`, deb `prerm remove`/`postrm purge`, Arch `pre_remove`. Never fail a removal.
- **Clone install and package detect each other**, so the two are never installed together.

### 10.3 Steps (one PR each)

1. **Preparation:** `PRE_BUILD` config generation, a shared paths file (clone vs package layout, like fingerprint-fix-sdcp's `lib/fixpaths.sh`), the `galaxybook-fan` command, notifications that know the install method. `install.sh` keeps working throughout.
2. **`packaging/` shared files:** units, polkit rule, scripts as templates (`packaging/files/*.in`, `render.sh`, `install-files.sh`), as in fingerprint-fix-sdcp.
3. **rpm** (`packaging/rpm/`: spec, `build.sh`).
4. **deb** (`packaging/debian/`: control, rules, maintainer scripts, `build.sh`).
5. **Arch** (`packaging/arch/`: `PKGBUILD`, `galaxybook-fan.install`; CI builds the `.pkg.tar.zst`).
6. **Release workflow:** build all three, attach them, and change the release page to a per-distro download-and-install table.

David tests each step on his laptop's distros before merging; the first packaged release follows step 6.

## 11. Ideas not done yet (ask David before starting)

- **Galaxy Book 6:** support it if its firmware has the same `_FST` bug (add its models after checking a real DSDT). The repository name is kept generic for this.
- **Going public:** when David is happy, make the repository public and add a branch ruleset on `main` (block force pushes, restrict deletions, optionally require a PR with 0 approvals).
- Testing the "signing key not enrolled" path and Book 5 models other than the 940XHA on real hardware.
