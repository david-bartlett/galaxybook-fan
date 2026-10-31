/* SPDX-License-Identifier: GPL-2.0 */
/*
 * Default config for the Galaxy Book 5 Pro (940XHA), so the module builds
 * standalone. install.sh replaces this in /usr/src with one generated from
 * the running machine's DSDT by dsdt-fan-config.py.
 *
 * DSDT:     SECCSD LH43STAR 0x01072009
 * Field:    \_SB_.PC00.LPCB.H_EC.FANS
 *           ECR (SystemMemory @ 0xFE0B0000) offset 0x87 bits 0-3
 * Table:    FANT = 0x0DAC, 0x0EE2, 0x1144, 0x127A, +10
 */
#ifndef GALAXYBOOK_FAN_CONFIG_H
#define GALAXYBOOK_FAN_CONFIG_H

#define GB_DSDT_ID		"SECCSD LH43STAR 0x01072009"
#define GB_DSDT_OEM_ID		"SECCSD"
#define GB_DSDT_OEM_TABLE_ID	"LH43STAR"
#define GB_DSDT_OEM_REV		0x01072009
#define GB_DMI_PRODUCT		"940XHA"
/* Read through ACPI by name, exactly as _FST does */
#define GB_FIELD_PATH		"\\_SB_.PC00.LPCB.H_EC.FANS"
#define GB_FIELD_WIDTH		4

/* RPM for each raw field value; -1 = no data (outside the firmware table) */
static const int gb_rpm_for_raw[16] = {
	    0,  3510,  3820,  4430,  4430,  4740,    -1,    -1,
	   -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1
};

#endif
