# galaxybook-fan

Fan speed reporting for the Samsung Galaxy Book 5 Pro (940XHA) on Linux, without a DSDT override.

## The problem

Samsung's `\_SB.PC00.LPCB.FAN0._FST` method does:

```
Local1 = FANT [Local0]      // Index reference, no DerefOf()
Local1 += 0x0A
```

Windows' AML interpreter tolerates this. ACPICA doesn't, so whenever the fan is spinning `_FST` aborts with `AE_AML_OPERAND_TYPE`, and the stock `acpi-fan` driver reports an I/O error instead of a speed.

## The fix

`galaxybook_fan` is a small DKMS hwmon module that reads the fan level directly from the Embedded Controller with the kernel's `ec_read()` (EC byte `0x87`, bits 0-3). It applies the same level→RPM mapping `_FST` is meant to apply:

| EC level (FANS) | Fan speed |
|---|---|
| 0 | 0 RPM (off) |
| 1 | 3510 RPM |
| 2 | 3820 RPM |
| 3, 4 | 4430 RPM |
| 5 | 4740 RPM |

These are Samsung's own table values (`FANT + 0x0A`), so the speed is stepped, exactly as Windows reports it. The EC doesn't expose a measured RPM.

The installer also unbinds the stock `acpi-fan` driver from the fan device with a small oneshot systemd service that runs early in boot. That removes the dead "Fan 0" sensor and the AML errors in dmesg. The fan has no ACPI control methods, so the cooling device `acpi-fan` registers does nothing anyway.

Compared with fanspeed-fix-cpio, this adds nothing to the boot chain. There's no initrd change and no recovery entry, and a BIOS update can't make the laptop unbootable.

## Install

```bash
sudo ./install.sh            # 940XHA
sudo ./install.sh --force    # other models - check your DSDT first
```

The installer:
- refuses to run while fanspeed-fix-cpio is active, to avoid two fan sensors
- installs `dkms`, `make`, `gcc` and the kernel headers if they're missing
- with Secure Boot on, finds whichever MOK key is enrolled (DKMS, akmods or Ubuntu shim) and points DKMS at it
- installs the module through DKMS, so it rebuilds automatically on kernel updates
- autoloads it via `/etc/modules-load.d/`
- enables `galaxybook-acpi-fan-unbind.service`, which unbinds `acpi-fan` at boot

## Uninstall

```bash
sudo ./uninstall.sh
```

This removes everything the installer added and rebinds `acpi-fan`.

## Other models

Before using `--force`, disassemble your DSDT and check that `FAN0._FST` reads `H_EC.FANS` at EC offset `0x87` and that `FANT` holds `0x0DAC, 0x0EE2, 0x1144, 0x127A`:

```bash
sudo acpidump -b && iasl -d dsdt.dat
grep -n -A40 'Method (_FST' dsdt.dsl
grep -n -B2 -A2 '\bFANS,' dsdt.dsl
grep -n 'Name (FANT' -A6 dsdt.dsl
```
