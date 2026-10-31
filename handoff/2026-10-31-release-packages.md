# Packaging step 6: packages on the release

PR #20 · Claude · 2026-10-31

## What changed
- `.github/workflows/release.yml` (same file, so the release tool's Actions link still works): jobs `versions` (dkms.conf / install.sh match VERSION always; tag and CHANGELOG section for a release), `rpm` (`fedora:45`), `deb` (`debian:13`), `arch` (`archlinux:base-devel`: makepkg as a plain user, `--nodeps`; release `PKGBUILD` from `packaging/arch/PKGBUILD.release.in` with the tarball's sha256, or SKIP while the repository is private), `check-script`, and `publish` (tag or Run workflow only: creates the release if needed, attaches everything plus `SHA256SUMS`, `--clobber`).
- **Pull requests** now run the build jobs too, with the packages as artifacts (`galaxybook-fan-rpm`, `-deb`, `-arch`, `check-galaxybook-fan`): David can test what a release would attach.
- rpm `Release:` without `%{?dist}`: `galaxybook-fan-X.Y.Z-1.noarch.rpm`, one file for Fedora 44 and 45.
- `.github/release-install.md`: per-distro table (download, one command), Arch's PKGBUILD and `install.sh` in a collapsed section, `SHA256SUMS`. README Install: packages first, then `install.sh`.
- PLAN.md §3, §7.1 (what a release does now), §8.2 (testing PR artifacts), §10.3 step 6 ✅; packaging READMEs; CHANGELOG.

## Tested
- Here: all three packages built with the same commands the jobs run (rpm 4.18 with `--nodeps`, debhelper 13, makepkg 6), file names as in the table; the release `PKGBUILD` rendered with this version and SKIP, `bash -n`, and `makepkg` with it against a local tarball of this checkout builds the same file list as the local PKGBUILD; `release-notes.sh` renders the new install table; workflow YAML parses.
- The real check is this PR's own workflow run: its artifacts are the packages.
- Not tested: `publish` (needs a tag: the next release is its first run).

## For the next person
- The first packaged release is the next one (0.6.0). If `publish` fails, fix it in a PR and use Actions → Release → Run workflow with the tag: it re-attaches the files to the existing release.
- When the repository goes public, the release PKGBUILD gets the tarball's real checksum automatically.
