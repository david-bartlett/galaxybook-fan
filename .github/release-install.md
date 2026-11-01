> [!IMPORTANT]
> **galaxybook-fan** makes fan speed reporting work on the Samsung Galaxy Book 5 (`940XHA`, `960XHA`, `960QHA`, `750XHD`, `754XHD`, `750QHA`, `754QHA`). It reads your laptop's own firmware to set itself up, and refuses anything else.
>
> **Already installed?** See **3. Update** below: one command installs this release.

## 1. Check your laptop first

Download **[check-galaxybook-fan.sh](https://github.com/david-bartlett/galaxybook-fan/releases/download/v@VERSION@/check-galaxybook-fan.sh)** (also in the files below) and run it. It only reads, and installs nothing:

```bash
sudo bash check-galaxybook-fan.sh
```

It says whether galaxybook-fan will work on your laptop, and whether your model is already confirmed. If your model isn't confirmed yet, install the fix and run it again: it gives you a short report to post as a [Works on my model](https://github.com/david-bartlett/galaxybook-fan/issues/new?template=works_on.yml) issue.

## 2. Install

Download your distro's file below, open a terminal in the folder you downloaded it to (usually Downloads) and run the command:

| Distro | Download | Then run |
| --- | --- | --- |
| **Fedora 44, 45** | `galaxybook-fan-@VERSION@-1.noarch.rpm` | `sudo dnf install ./galaxybook-fan-@VERSION@-1.noarch.rpm` |
| **Ubuntu 24.04, 26.04, Mint, Debian 13, MX 25** | `galaxybook-fan_@VERSION@-1_all.deb` | `sudo apt install ./galaxybook-fan_@VERSION@-1_all.deb` |
| **Arch, CachyOS, EndeavourOS** | `galaxybook-fan-@VERSION@-1-any.pkg.tar.zst` | `sudo pacman -U ./galaxybook-fan-@VERSION@-1-any.pkg.tar.zst` |

DKMS builds the module on your laptop, from its own firmware, for every kernel with headers: on Arch, install your kernel's headers package too (the install says which, e.g. `linux-cachyos-headers`). With Secure Boot on and the signing key not enrolled yet, the install prints the `mokutil` command to run once.

Then check: `galaxybook-fan status`, and `sensors` shows the fan's speed.

<details>
<summary>The galaxybook-fan command</summary>

| Command | What it does |
| --- | --- |
| `galaxybook-fan status` | What's installed, which kernels, and the fan speed now |
| `sudo galaxybook-fan check` | Will it work on this laptop? (read-only) |
| `sudo galaxybook-fan rebuild` | After a BIOS update: read the new firmware and build the module again |
| `sudo galaxybook-fan test-native` | Can the stock acpi-fan driver read the fan by itself now? (then the fix isn't needed) |
| `sudo galaxybook-fan update` | Install the newest release's package |
| `sudo galaxybook-fan updates on` / `off` | "New version" notifications on or off |
| `galaxybook-fan updates status` | Are they on? (checked every 6 hours) |
| `galaxybook-fan updates check` | Look now; if there's a new version, show the notification (no sudo) |

</details>

To remove it: `sudo dnf remove galaxybook-fan`, `sudo apt remove galaxybook-fan` or `sudo pacman -R galaxybook-fan`.

<details>
<summary>Other ways: build it on Arch, or install.sh from the source code (any distro)</summary>

**Arch, building it yourself:** download `PKGBUILD` and `galaxybook-fan.install` into a new, empty folder, then run `makepkg -si` there.

**install.sh**, for other distros (anything with `dnf`, `apt` or `pacman`): download **Source code (tar.gz)** below, then:

```bash
tar xzf galaxybook-fan-@VERSION@.tar.gz
cd galaxybook-fan-@VERSION@
sudo ./install.sh --check    # shows what it found in your firmware, installs nothing
sudo ./install.sh
```

To remove it: `sudo ./uninstall.sh` in the same folder.

</details>

## 3. Update

Already have galaxybook-fan 0.7.0 or newer? It looks for new releases by itself, but only every 6 hours, so to update now:

```bash
sudo galaxybook-fan update
```

It downloads your distro's file from this release, checks it against `SHA256SUMS` and installs it (`dnf`, `apt` or `pacman` asks first, as usual). Or run `galaxybook-fan updates check` (no `sudo`, from 0.8.0) to see the new-version notification now, with **Update now** and **What's new**.

Older versions, or a copy installed with `install.sh`: install this release's file the same way as in **2. Install**, which updates the old one. The Fedora and Ubuntu / Debian packages replace an `install.sh` copy; on Arch, run `sudo ./uninstall.sh` in its folder first.

`SHA256SUMS` lists the files' checksums: `sha256sum -c SHA256SUMS --ignore-missing` in the download folder checks the ones you downloaded.
