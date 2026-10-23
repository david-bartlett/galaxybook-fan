// SPDX-License-Identifier: GPL-2.0
/*
 * galaxybook_fan - fan speed for Samsung Galaxy Book laptops, read directly
 * from the Embedded Controller.
 *
 * Bypasses \_SB.PC00.LPCB.FAN0._FST, which fails on ACPICA with
 * AE_AML_OPERAND_TYPE whenever the fan is running: it does
 *     Local1 = FANT [Local0]
 * without DerefOf(), storing an Index reference instead of an integer.
 *
 * This mirrors what _FST is meant to return:
 *     FANS  = EC byte 0x87, bits 0-3
 *     level = 1->1, 2->2, 3->3, 4->3, 5->4, 0->off
 *     rpm   = FANT[level - 1] + 10
 */

#include <linux/acpi.h>
#include <linux/dmi.h>
#include <linux/err.h>
#include <linux/hwmon.h>
#include <linux/module.h>
#include <linux/platform_device.h>

#define DRV_NAME	"galaxybook_fan"

#define EC_FANS_ADDR	0x87
#define EC_FANS_MASK	0x0f

static bool force;
module_param(force, bool, 0444);
MODULE_PARM_DESC(force, "Load even if the DMI model is not in the known list");

/* \_SB.PC00.LPCB.FAN0.FANT from the 940XHA DSDT */
static const u16 fant[] = { 0x0dac, 0x0ee2, 0x1144, 0x127a };

static struct platform_device *gb_pdev;
static struct device *gb_hwmon;

static int gb_fan_level(u8 fans)
{
	switch (fans) {
	case 0:
		return 0;
	case 1:
		return 1;
	case 2:
		return 2;
	case 3:
	case 4:
		return 3;
	case 5:
		return 4;
	default:
		/* _FST would index past FANT here; report no data instead */
		return -ENODATA;
	}
}

static int gb_fan_read(struct device *dev, enum hwmon_sensor_types type,
		       u32 attr, int channel, long *val)
{
	u8 raw;
	int ret, level;

	if (type != hwmon_fan || attr != hwmon_fan_input)
		return -EOPNOTSUPP;

	ret = ec_read(EC_FANS_ADDR, &raw);
	if (ret)
		return ret;

	level = gb_fan_level(raw & EC_FANS_MASK);
	if (level < 0)
		return level;

	*val = level ? fant[level - 1] + 10 : 0;
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

static const struct dmi_system_id gb_fan_dmi[] = {
	{
		.ident = "Samsung Galaxy Book5 Pro (940XHA)",
		.matches = {
			DMI_MATCH(DMI_SYS_VENDOR, "SAMSUNG ELECTRONICS CO., LTD."),
			DMI_MATCH(DMI_PRODUCT_NAME, "940XHA"),
		},
	},
	{ }
};
MODULE_DEVICE_TABLE(dmi, gb_fan_dmi);

static int __init gb_fan_init(void)
{
	acpi_handle handle;

	if (!dmi_check_system(gb_fan_dmi) && !force)
		return -ENODEV;

	/* Sanity check: this is the EC that FAN0._FST reads from */
	if (ACPI_FAILURE(acpi_get_handle(NULL, "\\_SB.PC00.LPCB.H_EC", &handle)))
		return -ENODEV;

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
