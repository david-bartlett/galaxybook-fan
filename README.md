# galaxybook-fan

Fan speed reporting for Samsung Galaxy Book laptops on Linux, without a DSDT override.

## The problem

Samsung's fan `_FST` method (e.g. `\_SB.PC00.LPCB.FAN0._FST`) does:

```
Local1 = FANT [Local0]      // Index reference, no DerefOf()
Local1 += 0x0A
```

Windows' AML interpreter tolerates this. ACPICA doesn't, so whenever the fan is spinning `_FST` aborts with `AE_AML_OPERAND_TYPE`, and the stock `acpi-fan` driver reports an I/O error instead of a speed.

## The fix

`galaxybook_fan` is a small DKMS hwmon module that reads the same EC field `_FST` reads (`H_EC.FANS`) by asking ACPI for its value. The firmware performs the read exactly as it would for `_FST`, through whichever region the field lives in and with its own locking. The module then applies `_FST`'s level remap and RPM table itself, so only the broken table lookup is bypassed.

Nothing is hardcoded per model. The installer disassembles **this machine's own DSDT** and `dsdt-fan-config.py` works out:

- which EC field `_FST` reads, and that it's defined exactly once in a plain readable region (the 940XHA reads it through `ECR`, a SystemMemory window onto the EC's RAM)
- how `_FST` remaps the raw value to a fan level (its `Switch`/`Case` table)
- the RPM table (`FANT`) and offset

The results are baked into `galaxybook_fan_config.h` before DKMS builds the module.

On the Galaxy Book 5 Pro (940XHA) that gives:

| `FANS` value | Fan speed |
|---|---|
| 0 | 0 RPM (off) |
| 1 | 3510 RPM |
| 2 | 3820 RPM |
| 3, 4 | 4430 RPM |
| 5 | 4740 RPM |

These are Samsung's own table values, so the speed is stepped, exactly as Windows reports it. The EC doesn't expose a measured RPM.

The installer also enables `galaxybook-acpi-fan-unbind.service`, which unbinds the stock `acpi-fan` driver early in boot. That removes the dead "Fan 0" sensor and the AML errors in dmesg. The fan has no ACPI control methods, so the cooling device `acpi-fan` registers does nothing anyway.

Compared with fanspeed-fix-cpio, this adds nothing to the boot chain. There's no initrd change and no recovery entry, and a BIOS update can't make the laptop unbootable.

## Guards

`dsdt-fan-config.py` never guesses. It refuses, and nothing is installed, if:

- there isn't exactly one `PNP0C0B` fan device with an `_FST` method
- `_FST` contains any statement outside the known shape (extra maths, another EC read, `Case (Package …)`, `Default`, loops, calls…)
- the EC field isn't defined exactly once, is wider than 8 bits, or is in anything other than an EmbeddedControl, SystemMemory or SystemIO region
- the RPM table is missing, defined more than once, the wrong length, or gives a speed outside 500–20000 RPM

On failure, the disassembled DSDT is saved to `/tmp/galaxybook-fan-dsdt.dsl` so you can see why.

The module also checks itself at load time, and refuses to load unless both of these match what the config was generated from:

- the DMI product name
- the DSDT's OEM ID, table ID and revision

So after a **BIOS update** the fan sensor disappears, and dmesg tells you to re-run `install.sh`, instead of a changed `_FST` or RPM table producing wrong readings. At load it also checks that the field exists and can be read.

## Install

```bash
sudo ./install.sh --check    # derive and show the config from your DSDT, install nothing
sudo ./install.sh            # confirmed models (940XHA)
sudo ./install.sh --force    # other models, once --check output looks right
```

The installer:
- refuses to run while fanspeed-fix-cpio is active, to avoid two fan sensors
- installs `iasl` (acpica), `python3`, `dkms`, `make`, `gcc` and the kernel headers if they're missing
- derives the fan config from the DSDT, as described above
- with Secure Boot on, finds whichever MOK key is enrolled (DKMS, akmods or Ubuntu shim) and points DKMS at it
- installs the module through DKMS, so it rebuilds automatically on kernel updates
- autoloads it via `/etc/modules-load.d/galaxybook_fan.conf`, which is also a good file for checking whether the fix is installed
- enables the `acpi-fan` unbind service

Re-running `install.sh` over an existing install is fine; there's no need to uninstall first.

## Uninstall

```bash
sudo ./uninstall.sh
```

This removes everything the installer added and rebinds `acpi-fan`. No reboot is needed.

## Files

| File | Purpose |
|---|---|
| `galaxybook_fan.c` | the module |
| `galaxybook_fan_config.h` | default config (940XHA), so the module builds standalone; the installer replaces it in `/usr/src` |
| `dsdt-fan-config.py` | derives and validates the config from a disassembled DSDT |
| `install.sh` / `uninstall.sh` | as above |
