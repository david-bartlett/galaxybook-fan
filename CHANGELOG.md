# Changelog

<!-- Release pages: lines that start with a bold headline, "- **Own repository:** …",
     are listed under What's new; the whole section is under "Full changelog" (collapsed).
     Bold lines: short, so What's new stays brief.
     Plain lines: the full detail, shown only in Full changelog.
     Every release, even a small one: at least one bold line. -->

## Unreleased

## 0.3.0 — 2026-10-31

- **Own repository:** galaxybook-fan has moved out of samsung-galaxybook-fixes into its own repository, with its full history
- It used to be `extras/galaxybook-fan` in [samsung-galaxybook-fixes](https://github.com/david-bartlett/samsung-galaxybook-fixes), which now only has a README pointing here. Already installed from there? Run this repository's `install.sh` once, so the notifications after a BIOS or kernel update tell you to run `install.sh` and `uninstall.sh` in this folder instead of the old one
- The version is now three numbers (`0.2.0`, was `0.2`), in a new `VERSION` file that the release tool keeps in step with `dkms.conf` and `install.sh`. Re-running `install.sh` replaces the old DKMS version, as before
- `PLAN.md`, `AGENTS.md` and `handoff/` for contributors
- Release pages: how to install from the source code, *What's new* and the full changelog, made by a release workflow when a version is tagged

## 0.2 — 2026-10-24

- **Fan speed on the Galaxy Book 5:** a small DKMS module reads the fan speed that Samsung's broken `_FST` method can't report on Linux
- First version, developed in `extras/galaxybook-fan` of samsung-galaxybook-fixes: the module, the installer that derives the EC field and RPM table from the machine's own DSDT, the `acpi-fan` unbind service, Secure Boot signing, and the login-time check that notices a kernel or BIOS update. Tested on the Galaxy Book 5 Pro (940XHA) with Fedora 45, Ubuntu 26.04, Linux Mint 27, MX Linux 25 and CachyOS
