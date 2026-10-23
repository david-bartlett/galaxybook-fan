// SPDX-License-Identifier: GPL-2.0
/*
 * galaxybook_fan - fan speed for Samsung Galaxy Book laptops, read directly
 * from the Embedded Controller.
 *
 * Bypasses the fan device's _FST method, which fails on ACPICA with
 * AE_AML_OPERAND_TYPE whenever the fan is running: it does
 *     Local1 = FANT [Local0]
 * without DerefOf(), storing an Index reference instead of an integer.
 *
 * The module reads the same EC field _FST reads (e.g. H_EC.FANS) by asking
 * ACPI for its value, so the firmware does the access exactly as it would
 * for _FST - through whichever region the field lives in, with its own
 * locking - and then applies _FST's level remap and RPM table itself.
 *
 * The field path, remap and table come from galaxybook_fan_config.h, which
 * install.sh generates from this machine's own DSDT (dsdt-fan-config.py).
 * The copy in the repo is for the 940XHA.
 */

#include <linux/acpi.h>
#include <linux/build_bug.h>
#include <linux/dmi.h>
#include <linux/err.h>
#include <linux/hwmon.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/platform_device.h>
#include <linux/string.h>

#include "galaxybook_fan_config.h"

#define DRV_NAME	"galaxybook_fan"

static_assert(ARRAY_SIZE(gb_rpm_for_raw) == (1 << GB_FIELD_WIDTH));
static_assert(GB_FIELD_WIDTH >= 1 && GB_FIELD_WIDTH <= 8);

static bool force;
module_param(force, bool, 0444);
MODULE_PARM_DESC(force, "Load even if the DMI product or DSDT isn't the one the config was generated for");

static struct platform_device *gb_pdev;
static struct device *gb_hwmon;
static acpi_handle gb_field;

static int gb_read_field(unsigned long long *raw)
{
	acpi_status status;

	status = acpi_evaluate_integer(gb_field, NULL, NULL, raw);
	if (ACPI_FAILURE(status))
		return -EIO;
	if (*raw >> GB_FIELD_WIDTH)
		return -EIO;	/* wider than the DSDT declares - shouldn't happen */
	return 0;
}

static int gb_fan_read(struct device *dev, enum hwmon_sensor_types type,
		       u32 attr, int channel, long *val)
{
	unsigned long long raw;
	int ret, rpm;

	if (type != hwmon_fan || attr != hwmon_fan_input)
		return -EOPNOTSUPP;

	ret = gb_read_field(&raw);
	if (ret)
		return ret;

	rpm = gb_rpm_for_raw[raw];
	if (rpm < 0)
		return -ENODATA;	/* _FST would index past the firmware table */

	*val = rpm;
	return 0;
}

static int gb_fan_read_string(struct device *dev, enum hwmon_sensor_types type,
			      u32 attr, int channel, const char **str)
{
	if (type != hwmon_fan || attr != hwmon_fan_label)
		return -EOPNOTSUPP;

	*str = "Fan";
	return 0;
}

static umode_t gb_fan_is_visible(const void *data, enum hwmon_sensor_types type,
				 u32 attr, int channel)
{
	if (type == hwmon_fan &&
	    (attr == hwmon_fan_input || attr == hwmon_fan_label))
		return 0444;
	return 0;
}

static const struct hwmon_ops gb_fan_ops = {
	.is_visible	= gb_fan_is_visible,
	.read		= gb_fan_read,
	.read_string	= gb_fan_read_string,
};

static const struct hwmon_channel_info * const gb_fan_info[] = {
	HWMON_CHANNEL_INFO(fan, HWMON_F_INPUT | HWMON_F_LABEL),
	NULL
};

static const struct hwmon_chip_info gb_fan_chip_info = {
	.ops	= &gb_fan_ops,
	.info	= gb_fan_info,
};

/* Compare a fixed-width, space/NUL-padded ACPI header field with a C string */
static bool gb_acpi_field_eq(const char *field, size_t len, const char *want)
{
	size_t n = len;

	while (n && (field[n - 1] == ' ' || field[n - 1] == '\0'))
		n--;
	return n == strlen(want) && !memcmp(field, want, n);
}

/*
 * The EC offset and RPM table were derived from one specific DSDT. After a
 * BIOS update the field could move, so refuse to report anything until
 * install.sh has re-derived the config from the new table.
 */
static int gb_check_dsdt(void)
{
	struct acpi_table_header *hdr;
	bool same;

	if (ACPI_FAILURE(acpi_get_table(ACPI_SIG_DSDT, 0, &hdr))) {
		pr_err(DRV_NAME ": can't read the DSDT header\n");
		return -ENODEV;
	}
	same = gb_acpi_field_eq(hdr->oem_id, ACPI_OEM_ID_SIZE, GB_DSDT_OEM_ID) &&
	       gb_acpi_field_eq(hdr->oem_table_id, ACPI_OEM_TABLE_ID_SIZE, GB_DSDT_OEM_TABLE_ID) &&
	       hdr->oem_revision == GB_DSDT_OEM_REV;
	if (!same)
		pr_err(DRV_NAME ": DSDT is %.*s %.*s 0x%08x but config was generated for %s - BIOS updated? Re-run install.sh\n",
		       ACPI_OEM_ID_SIZE, hdr->oem_id,
		       ACPI_OEM_TABLE_ID_SIZE, hdr->oem_table_id,
		       hdr->oem_revision, GB_DSDT_ID);
	acpi_put_table(hdr);
	return same ? 0 : -ENODEV;
}

static int __init gb_fan_init(void)
{
	const char *vendor = dmi_get_system_info(DMI_SYS_VENDOR);
	const char *product = dmi_get_system_info(DMI_PRODUCT_NAME);
	unsigned long long raw;
	int ret;

	if (!vendor || !strstr(vendor, "SAMSUNG"))
		return -ENODEV;

	/* The config describes one machine's firmware - don't apply it to another */
	if (!product || strcmp(product, GB_DMI_PRODUCT)) {
		if (!force) {
			pr_err(DRV_NAME ": config is for %s, this is %s - re-run install.sh (or load with force=1)\n",
			       GB_DMI_PRODUCT, product ?: "unknown");
			return -ENODEV;
		}
		pr_warn(DRV_NAME ": config is for %s, this is %s - loading because force=1\n",
			GB_DMI_PRODUCT, product ?: "unknown");
	}

	if (!force) {
		ret = gb_check_dsdt();
		if (ret)
			return ret;
	}

	/* The field the fan's _FST reads from - and prove it can be read */
	if (ACPI_FAILURE(acpi_get_handle(NULL, GB_FIELD_PATH, &gb_field))) {
		pr_err(DRV_NAME ": EC field %s not found\n", GB_FIELD_PATH);
		return -ENODEV;
	}
	ret = gb_read_field(&raw);
	if (ret) {
		pr_err(DRV_NAME ": can't read EC field %s\n", GB_FIELD_PATH);
		return ret;
	}

	gb_pdev = platform_device_register_simple(DRV_NAME, PLATFORM_DEVID_NONE,
						  NULL, 0);
	if (IS_ERR(gb_pdev))
		return PTR_ERR(gb_pdev);

	gb_hwmon = hwmon_device_register_with_info(&gb_pdev->dev, DRV_NAME, NULL,
						   &gb_fan_chip_info, NULL);
	if (IS_ERR(gb_hwmon)) {
		platform_device_unregister(gb_pdev);
		return PTR_ERR(gb_hwmon);
	}

	pr_info(DRV_NAME ": DSDT %s, reading %s (currently %llu)\n",
		GB_DSDT_ID, GB_FIELD_PATH, raw);
	return 0;
}

static void __exit gb_fan_exit(void)
{
	hwmon_device_unregister(gb_hwmon);
	platform_device_unregister(gb_pdev);
}

module_init(gb_fan_init);
module_exit(gb_fan_exit);

MODULE_AUTHOR("David Bartlett");
MODULE_DESCRIPTION("Samsung Galaxy Book fan speed via EC (bypasses broken _FST)");
MODULE_LICENSE("GPL");
