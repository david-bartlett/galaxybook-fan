# galaxybook-fan

Fan speed reporting for the Samsung Galaxy Book 5 on Linux, without a DSDT override.

## Will it work on my laptop?

Download **[check-galaxybook-fan.sh](https://github.com/david-bartlett/galaxybook-fan/releases/latest/download/check-galaxybook-fan.sh)** and run it. It only reads, and installs or changes nothing:

```bash
sudo bash check-galaxybook-fan.sh
```

or make it executable first, then run it with `./`:

```bash
chmod +x check-galaxybook-fan.sh
sudo ./check-galaxybook-fan.sh
```

It checks your model and reads your laptop's own firmware the same way the fix does, then says whether galaxybook-fan will work. If your model isn't confirmed yet, install the fix and run the check again: when the fan speed shows, it gives you a short report to post as a **[Works on my model](https://github.com/david-bartlett/galaxybook-fan/issues/new?template=works_on.yml)** issue, so your model can be added below.

**Confirmed working:**

| Model | Laptop |
|---|---|
| `940XHA` | Galaxy Book 5 Pro 14" |

Not confirmed yet, but expected to work (the check tells you): `960XHA`, `960QHA`, `750XHD`, `754XHD`, `750QHA`, `754QHA`.

## Install

From the **[latest release](https://github.com/david-bartlett/galaxybook-fan/releases/latest)**, download your distro's file and install it:

| Distro | Command |
| --- | --- |
| **Fedora 44, 45** | `sudo dnf install ./galaxybook-fan-*.noarch.rpm` |
| **Ubuntu 24.04, 26.04, Mint, Debian 13, MX 25** | `sudo apt install ./galaxybook-fan_*_all.deb` |
| **Arch, CachyOS, EndeavourOS** | `sudo pacman -U ./galaxybook-fan-*-any.pkg.tar.zst` (or `makepkg -si` with the release's `PKGBUILD` and `galaxybook-fan.install`) |

The packages do what [`install.sh`](https://github.com/david-bartlett/galaxybook-fan/blob/main/docs/installing.md) does, with no questions: DKMS builds the module on your laptop from its own firmware, for every kernel with headers. They refuse anything that isn't a Galaxy Book 5 (on Arch the module just isn't built, and the install says why). A copy installed with `install.sh` is replaced by the rpm and deb; on Arch, run `sudo ./uninstall.sh` in its folder first. Remove the package with `sudo dnf remove`, `sudo apt remove` or `sudo pacman -R galaxybook-fan`. Details: [packaging/README.md](packaging/README.md). Other distros, or from a clone: [install.sh](https://github.com/david-bartlett/galaxybook-fan/blob/main/docs/installing.md).

## Uninstall

The package: `sudo dnf remove galaxybook-fan`, `sudo apt remove galaxybook-fan` or `sudo pacman -R galaxybook-fan`. A copy installed with `install.sh`:

```bash
sudo ./uninstall.sh
```

Either removes everything that was added and rebinds `acpi-fan`. No reboot is needed.

## Updating

You're told about each new release with a notification, a minute after login and then every hour while you stay logged in. It comes once per version, with two buttons. Nothing is installed until you choose to:

| Button | What it does |
| --- | --- |
| **Update now** | Opens a terminal running `sudo galaxybook-fan update` |
| **What's new** | Opens the release page |

The update downloads your distro's package from the release, checks it against the release's `SHA256SUMS` and installs it with `dnf`, `apt` or `pacman`, which asks before installing as usual.

From a terminal:

| Command | What it does |
| --- | --- |
| `sudo galaxybook-fan update` | Install the newest release's package |
| `sudo galaxybook-fan updates on` / `off` | "New version" notifications on or off |
| `galaxybook-fan updates status` | Are they on? (checked hourly) |
| `galaxybook-fan updates check` | Look now; if there's a new version, show the notification (no sudo) |

**Installed with `install.sh`?** You get the same notification, and it tells you how to update instead: `git pull` (or the new release's source code), then `sudo ./install.sh`, in its folder.

<details>
<summary>How the update check works</summary>

- At login it always asks GitHub, and waits up to 2 minutes for the network. Nothing is said when GitHub can't be reached.
- A release is only announced once its packages are attached.
- The notification stays on screen until you close it, or until the new version is installed some other way, such as `sudo galaxybook-fan update`. After **What's new**, it comes back, so **Update now** is still there.
- On GNOME, hover over it for the whole text and the buttons, or click it to open the release page.
- **Update now** only appears when a terminal can be opened for it.

</details>

## The `galaxybook-fan` command

Installed with the fix; `galaxybook-fan --help` shows the same list.

<details>
<summary>All the commands</summary>

| Command | What it does |
| --- | --- |
| `galaxybook-fan status` | What's installed, which kernels, and the fan speed now |
| `sudo galaxybook-fan check` | Will it work on this laptop? (read-only) |
| `sudo galaxybook-fan rebuild` | After a BIOS update: read the new firmware and build the module again |
| `sudo galaxybook-fan test-native` | Can the stock acpi-fan driver read the fan by itself now? (then the fix isn't needed) |
| `sudo galaxybook-fan update` | Install the newest release's package |
| `sudo galaxybook-fan updates on` / `off` | "New version" notifications on or off |
| `galaxybook-fan updates status` | Are they on? (checked hourly) |
| `galaxybook-fan updates check` | Look now; if there's a new version, show the notification (no sudo) |

</details>

## Documentation

| Guide | What's in it |
|---|---|
| [How it works](https://github.com/david-bartlett/galaxybook-fan/blob/main/docs/how-it-works.md) | The firmware bug, what the fix does, when it refuses, the initramfs, what each file is for |
| [Installing with install.sh](https://github.com/david-bartlett/galaxybook-fan/blob/main/docs/installing.md) | Other distros or a clone, what the installer does, Secure Boot signing |
| [Compatibility](https://github.com/david-bartlett/galaxybook-fan/blob/main/docs/compatibility.md) | When the fix is no longer needed, supported hardware and kernels, test results |

## How it stays safe

- **It never guesses.** If your firmware doesn't match the known shape, the module isn't built. See [Guards](https://github.com/david-bartlett/galaxybook-fan/blob/main/docs/how-it-works.md#guards).
- **Nothing is added to the boot chain,** so a BIOS update can't make the laptop unbootable.
- **After a BIOS update the module refuses to load** until you run `sudo galaxybook-fan rebuild`, instead of giving wrong readings.
- **Nothing is installed or removed automatically.** The notifications tell you what to run.

## Licence

GPL-2.0, the same licence as the module.
