> [!IMPORTANT]
> **galaxybook-fan** makes fan speed reporting work on the Samsung Galaxy Book 5 (`940XHA`, `960XHA`, `960QHA`, `750XHD`, `754XHD`, `750QHA`, `754QHA`). It checks your laptop's own firmware before installing anything.
>
> **Already installed?** Run the new version's `install.sh` the same way: it replaces the old version.

## 1. Check your laptop first

Download **[check-galaxybook-fan.sh](https://github.com/david-bartlett/galaxybook-fan/releases/download/v@VERSION@/check-galaxybook-fan.sh)** (also in the files below) and run it. It only reads, and installs nothing:

```bash
sudo bash check-galaxybook-fan.sh
```

It says whether galaxybook-fan will work on your laptop, and whether your model is already confirmed. If your model isn't confirmed yet, install the fix and run it again: it gives you a short report to post as a [Works on my model](https://github.com/david-bartlett/galaxybook-fan/issues/new?template=works_on.yml) issue.

## 2. Install

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
