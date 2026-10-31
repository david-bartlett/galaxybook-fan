> [!IMPORTANT]
> **galaxybook-fan** makes fan speed reporting work on the Samsung Galaxy Book 5 (`940XHA`, `960XHA`, `960QHA`, `750XHD`, `754XHD`, `750QHA`, `754QHA`). It reads your laptop's own firmware to set itself up, and refuses anything else.
>
> **Already installed?** Install the new file the same way: it updates the old one. A copy installed with `install.sh` is replaced by the Fedora and Ubuntu / Debian packages; on Arch, run `sudo ./uninstall.sh` in its folder first.

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

`SHA256SUMS` lists the files' checksums: `sha256sum -c SHA256SUMS --ignore-missing` in the download folder checks the ones you downloaded.
