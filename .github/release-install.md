> [!IMPORTANT]
> **galaxybook-fan** makes fan speed reporting work on the Samsung Galaxy Book 5 (`940XHA`, `960XHA`, `960QHA`, `750XHD`, `754XHD`, `750QHA`, `754QHA`). It checks your laptop's own firmware before installing anything.
>
> **Already installed?** Run the new version's `install.sh` the same way: it replaces the old version.

## Install

Download **Source code (tar.gz)** below, then in the folder you downloaded it to (usually Downloads):

```bash
tar xzf galaxybook-fan-@VERSION@.tar.gz
cd galaxybook-fan-@VERSION@
sudo ./install.sh --check    # shows what it found in your firmware, installs nothing
sudo ./install.sh
```

Or with git:

```bash
git clone --branch v@VERSION@ https://github.com/david-bartlett/galaxybook-fan
cd galaxybook-fan
sudo ./install.sh
```

To remove it: `sudo ./uninstall.sh` in the same folder.
