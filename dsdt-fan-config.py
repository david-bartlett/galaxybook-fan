#!/usr/bin/env python3
"""
dsdt-fan-config.py - derive galaxybook_fan's EC location and RPM table from
the running machine's disassembled DSDT, and write galaxybook_fan_config.h.

It reads the fan device's _FST method rather than trusting hardcoded values:

    Local0 = ^^H_EC.FANS /* \\_SB_.PC00.LPCB.H_EC.FANS */   -> EC field
    Switch (ToInteger (Local0)) { Case (n) { Local0 = m } }  -> level map
    If ((Local0 == Zero)) ...                                -> level 0 = off
    Local0--                                                 -> 1-based levels
    Local1 = FANT [Local0]                                   -> RPM table
    Local1 += 0x0A                                           -> RPM offset

then resolves FANS's byte/bit position from its Field() in the
EmbeddedControl OperationRegion, and FANT's values from Name (FANT, Package).

Anything that doesn't match this shape is an error - the script never guesses.

Usage: dsdt-fan-config.py --dsl dsdt.dsl --product 940XHA --out config.h
Exit status: 0 = header written, 1 = DSDT doesn't match / failed a check,
             2 = bad arguments or unreadable input.
"""

import argparse
import re
import sys


class FanConfigError(Exception):
    pass


# --------------------------------------------------------------------------
# Disassembly helpers
# --------------------------------------------------------------------------

def strip_line(line):
    """Drop // and /* */ comments and string literals, so brace counting and
    pattern matching only see code. (Buffer hex dumps carry '// .{..' comments.)"""
    line = re.sub(r'"(?:[^"\\]|\\.)*"', '""', line)
    line = re.sub(r'/\*.*?\*/', '', line)
    return line.split('//', 1)[0]


def block_end(code, start):
    """Given the index of a header line (Device/Method/Field/...), return the
    index of the line holding its matching closing brace."""
    depth = 0
    seen_open = False
    for i in range(start, len(code)):
        for ch in code[i]:
            if ch == '{':
                depth += 1
                seen_open = True
            elif ch == '}':
                depth -= 1
                if seen_open and depth == 0:
                    return i
        if not seen_open and i > start + 1:
            break
    raise FanConfigError(f"Unbalanced braces after line {start + 1}")


def find_blocks(code, pattern, lo=0, hi=None):
    """All (start, end, match) for header lines matching pattern in [lo, hi]."""
    hi = len(code) - 1 if hi is None else hi
    out = []
    i = lo
    while i <= hi:
        m = re.match(pattern, code[i])
        if m:
            end = block_end(code, i)
            out.append((i, end, m))
        i += 1
    return out


def parse_int(tok):
    tok = tok.strip()
    named = {"Zero": 0, "One": 1, "Ones": 0xFFFFFFFFFFFFFFFF}
    if tok in named:
        return named[tok]
    if re.fullmatch(r'0x[0-9A-Fa-f]+', tok):
        return int(tok, 16)
    if re.fullmatch(r'\d+', tok):
        return int(tok)
    raise FanConfigError(f"Not an integer constant: '{tok}'")


# --------------------------------------------------------------------------
# Steps
# --------------------------------------------------------------------------

def direct_children(code, start, end):
    """Line indices inside a block that sit at its top level (depth 1),
    i.e. not inside a nested Device/Method/etc."""
    out = []
    depth = 0
    for i in range(start, end + 1):
        if depth == 1:
            out.append(i)
        depth += code[i].count('{') - code[i].count('}')
    return out


def find_fan_device(raw, code):
    """The single PNP0C0B device that implements _FST."""
    candidates = []
    for start, end, m in find_blocks(code, r'\s*Device\s*\((\w+)\)'):
        top = direct_children(code, start, end)
        # iasl writes: Name (_HID, EisaId ("PNP0C0B") /* Fan (Thermal Solution) */)
        if not any(re.search(r'Name\s*\(_HID,\s*(?:EisaId\s*\(\s*)?"PNP0C0B"', raw[i]) for i in top):
            continue
        # _FST must belong to this device itself, not a nested one
        fst = [b for b in find_blocks(code, r'\s*Method\s*\(_FST\b', start + 1, end) if b[0] in top]
        if fst:
            candidates.append((m.group(1), start, end, fst[0]))
    if not candidates:
        raise FanConfigError("No ACPI fan device (PNP0C0B) with an _FST method")
    if len(candidates) > 1:
        names = ", ".join(c[0] for c in candidates)
        raise FanConfigError(f"More than one fan device with _FST ({names}) - not supported")
    return candidates[0]


def parse_fst(raw, code, fst_start, fst_end):
    body_raw = raw[fst_start:fst_end + 1]
    body = code[fst_start:fst_end + 1]
    text = "\n".join(body)

    # 1. First statement: LocalN = <path>.FIELD  /* \FULL.PATH.FIELD */
    ec_read = None
    for line in body_raw:
        m = re.match(r'\s*(Local\d)\s*=\s*([\^\\]*[\w.]+\.(\w{1,4}))\s*/\*\s*(\\[\w.]+)\s*\*/', line)
        if m:
            ec_read = m
            break
    if not ec_read:
        raise FanConfigError("_FST doesn't start by reading an EC field into a Local "
                             "(expected 'Local0 = ^^H_EC.FANS /* \\...FANS */')")
    var, field, full_path = ec_read.group(1), ec_read.group(3), ec_read.group(4)
    ec_path = full_path.rsplit('.', 1)[0]

    # 2. Optional Switch remapping raw EC value -> level
    level_map = {}
    sw = re.search(r'Switch\s*\(\s*ToInteger\s*\(\s*' + var + r'\s*\)\s*\)', text)
    if sw:
        # Case (x) { var = y }  - exactly one assignment per case
        for cm in re.finditer(r'Case\s*\(([^()]+)\)\s*\{([^{}]*)\}', text):
            stmts = [s.strip() for s in cm.group(2).strip().splitlines() if s.strip()]
            if len(stmts) != 1:
                raise FanConfigError(f"Case ({cm.group(1)}) has {len(stmts)} statements - expected one '{var} = n'")
            am = re.fullmatch(var + r'\s*=\s*(\w+)', stmts[0])
            if not am:
                raise FanConfigError(f"Case ({cm.group(1)}) does '{stmts[0]}' - expected '{var} = n'")
            level_map[parse_int(cm.group(1))] = parse_int(am.group(1))
        if not level_map:
            raise FanConfigError("_FST has a Switch but no Case (n) { Local = m } entries")
        if re.search(r'\bDefault\b', text):
            raise FanConfigError("_FST Switch has a Default case - not supported")

    # 3. Level 0 means off
    if not re.search(r'If\s*\(\(\s*' + var + r'\s*==\s*Zero\s*\)\)', text):
        raise FanConfigError(f"_FST has no 'If (({var} == Zero))' off check")

    # 4. 1-based levels
    if not re.search(var + r'\s*--', text):
        raise FanConfigError(f"_FST has no '{var}--' before the table lookup")

    # 5. Table lookup (with or without DerefOf)
    tm = re.search(r'(Local\d)\s*=\s*(?:DerefOf\s*\(\s*)?(\w{1,4})\s*\[\s*' + var + r'\s*\]', text)
    if not tm:
        raise FanConfigError(f"_FST has no 'LocalN = TABLE [{var}]' lookup")
    rvar, table = tm.group(1), tm.group(2)

    # 6. Optional RPM offset
    offset = 0
    om = re.search(rvar + r'\s*\+=\s*(\w+)', text)
    if om:
        offset = parse_int(om.group(1))

    # 7. Whitelist every statement. Anything else (extra maths, another EC
    #    read, Case (Package ...), loops, calls) means _FST doesn't have the
    #    shape the table above was derived from - refuse rather than guess.
    const = r'(?:Zero|One|0x[0-9A-Fa-f]+|\d+)'
    allowed = [
        r'Method\s*\(_FST\b.*',
        r'[{}]',
        var + r'\s*=\s*[\^\\]*[\w.]+\.' + field,                 # EC read
        r'Switch\s*\(\s*ToInteger\s*\(\s*' + var + r'\s*\)\s*\)',
        r'Case\s*\(\s*' + const + r'\s*\)',
        var + r'\s*=\s*' + const,                                 # level remap
        r'\w{1,4}\s*\[\s*' + const + r'\s*\]\s*=\s*Local\d',      # store into return pkg
        r'If\s*\(\(\s*' + var + r'\s*==\s*Zero\s*\)\)',
        r'Else',
        var + r'\s*--',
        rvar + r'\s*=\s*(?:DerefOf\s*\(\s*)?' + table + r'\s*\[\s*' + var + r'\s*\]\s*\)?',
        rvar + r'\s*\+=\s*' + const,
        r'Return\s*\(\s*\w{1,4}\s*\)',
    ]
    for line in body:
        s = line.strip()
        if s and not any(re.fullmatch(p, s) for p in allowed):
            raise FanConfigError(f"_FST contains an unexpected statement: '{s}'")

    return {
        "field": field, "full_path": full_path, "ec_path": ec_path,
        "level_map": level_map, "table": table, "offset": offset,
    }


def parse_table(code, name, dev_start, dev_end):
    """Name (FANT, Package (0xNN) { a, b, ... }) - prefer the fan device's own."""
    pat = r'\s*Name\s*\(' + name + r',\s*Package\s*\((\w+)\)'
    hits = find_blocks(code, pat, dev_start, dev_end) or find_blocks(code, pat)
    if not hits:
        raise FanConfigError(f"Table {name} not found")
    if len(hits) > 1:
        raise FanConfigError(f"Table {name} defined {len(hits)} times - ambiguous")
    start, end, m = hits[0]
    declared = parse_int(m.group(1))
    inner = " ".join(code[start:end + 1])
    inner = inner[inner.index('{') + 1:inner.rindex('}')]
    vals = [parse_int(t) for t in inner.split(',') if t.strip()]
    if len(vals) != declared:
        raise FanConfigError(f"{name} declares {declared} entries but has {len(vals)}")
    if not 1 <= len(vals) <= 16:
        raise FanConfigError(f"{name} has {len(vals)} entries - expected 1..16")
    return vals


def parse_ec_field(code, ec_path, field):
    """Byte and bit position of FIELD inside the EC device's EmbeddedControl region."""
    ec_name = ec_path.rsplit('.', 1)[-1].rstrip('_') or ec_path.rsplit('.', 1)[-1]
    devs = [d for d in find_blocks(code, r'\s*Device\s*\((\w+)\)')
            if d[2].group(1).rstrip('_') == ec_name]
    if len(devs) != 1:
        raise FanConfigError(f"Expected one EC device '{ec_name}', found {len(devs)}")
    # The device itself, plus any Scope (\...H_EC) blocks that extend it
    ranges = [devs[0][:2]]
    for s_start, s_end, sm in find_blocks(code, r'\s*Scope\s*\(([\\^\w.]+)\)'):
        if sm.group(1).rsplit('.', 1)[-1].lstrip('\\^').rstrip('_') == ec_name:
            ranges.append((s_start, s_end))

    regions = {}
    for r_start, r_end in ranges:
        for i in range(r_start, r_end + 1):
            m = re.match(r'\s*OperationRegion\s*\((\w+),\s*(\w+),\s*(\w+),\s*(\w+)\)', code[i])
            if m:
                regions[m.group(1)] = (m.group(2), m.group(3))

    fields = [b for r_start, r_end in ranges
              for b in find_blocks(code, r'\s*Field\s*\((\w+),', r_start, r_end)]
    fields = sorted(set((s, e) for s, e, _ in fields))   # a Scope nested in the Device would repeat
    found = []
    for f_start, f_end in fields:
        fm = re.match(r'\s*Field\s*\((\w+),', code[f_start])
        region = fm.group(1)
        bit = 0
        # Body lines look like "Offset (0x87),", "FANS,   4,", ",   3," or
        # "AccessAs (BufferAcc, 0x01),"
        for line in code[f_start + 1:f_end + 1]:
            s = line.strip().strip('{}').strip()
            if not s:
                continue
            m = re.fullmatch(r'Offset\s*\((\w+)\)\s*,?', s)
            if m:
                bit = parse_int(m.group(1)) * 8
                continue
            if s.startswith("AccessAs"):
                continue
            if s.startswith("Connection"):
                raise FanConfigError(f"Field ({region}) uses Connection - not supported")
            m = re.fullmatch(r'(\w{1,4})?\s*,\s*(\w+)\s*,?', s)
            if not m:
                raise FanConfigError(f"Unrecognised Field ({region}) entry: '{s}'")
            name, width = m.group(1), parse_int(m.group(2))
            if name == field:
                found.append((region, bit, width))
            bit += width

    if len(found) != 1:
        raise FanConfigError(f"EC field {field} defined {len(found)} times in {ec_name} - expected exactly one")
    region, bit, width = found[0]
    if region not in regions:
        raise FanConfigError(f"OperationRegion {region} for {field} not found in {ec_name}")
    space, base = regions[region]
    if space != "EmbeddedControl":
        raise FanConfigError(f"{field} is in a {space} region, not EmbeddedControl")
    if parse_int(base) != 0:
        raise FanConfigError(f"{region} starts at {base}, not 0 - not supported")
    byte, shift = divmod(bit, 8)
    if not 1 <= width <= 8 or shift + width > 8:
        raise FanConfigError(f"{field} is {width} bits at bit {shift} - must fit in one byte")
    if byte > 0xFF:
        raise FanConfigError(f"{field} at EC offset 0x{byte:X} is outside the 256-byte EC space")
    return byte, shift, width


def build_rpm_table(fst, table_vals, width):
    """RPM for every possible raw EC value, mirroring _FST exactly.
    -1 = _FST would index outside the table (reported as 'no data')."""
    rpm = []
    for raw in range(1 << width):
        level = fst["level_map"].get(raw, raw)   # unmatched Case leaves Local unchanged
        if level == 0:
            rpm.append(0)
        elif 1 <= level <= len(table_vals):
            rpm.append(table_vals[level - 1] + fst["offset"])
        else:
            rpm.append(-1)
    valid = [r for r in rpm if r > 0]
    if not valid:
        raise FanConfigError("No raw EC value maps to a running fan speed")
    bad = [r for r in valid if not 500 <= r <= 20000]
    if bad:
        raise FanConfigError(f"Implausible fan speeds {bad} (expected 500..20000 RPM)")
    return rpm


def dsdt_id(raw):
    """(oem_id, oem_table_id, oem_revision) from the DefinitionBlock header."""
    for line in raw[:60]:
        m = re.search(r'DefinitionBlock\s*\("[^"]*",\s*"DSDT",\s*\w+,\s*"([^"]*)",\s*"([^"]*)",\s*(\w+)\)', line)
        if m:
            return m.group(1), m.group(2), parse_int(m.group(3))
    raise FanConfigError("No DSDT DefinitionBlock header - is this a disassembled DSDT?")


def c_string(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--dsl", required=True, help="disassembled DSDT (iasl -d)")
    ap.add_argument("--product", required=True, help="DMI product_name to lock the module to")
    ap.add_argument("--out", help="header to write (omit to just print the summary)")
    args = ap.parse_args()

    try:
        with open(args.dsl, encoding="utf-8", errors="replace") as f:
            raw = f.read().splitlines()
    except OSError as e:
        print(f"Can't read {args.dsl}: {e}", file=sys.stderr)
        return 2

    try:
        oem_id, oem_table, oem_rev = dsdt_id(raw)
        ident = f"{oem_id} {oem_table} 0x{oem_rev:08X}"
        code = [strip_line(l) for l in raw]
        dev_name, dev_start, dev_end, (fst_start, fst_end, _) = find_fan_device(raw, code)
        fst = parse_fst(raw, code, fst_start, fst_end)
        table_vals = parse_table(code, fst["table"], dev_start, dev_end)
        byte, shift, width = parse_ec_field(code, fst["ec_path"], fst["field"])
        rpm = build_rpm_table(fst, table_vals, width)
    except FanConfigError as e:
        print(f"DSDT check failed: {e}", file=sys.stderr)
        return 1

    # Summary for the installer to show
    print(f"DSDT:        {ident}")
    print(f"Fan device:  {dev_name} (PNP0C0B)")
    print(f"EC field:    {fst['full_path']} = EC 0x{byte:02X} bits {shift}-{shift + width - 1}")
    print(f"Table:       {fst['table']} = {', '.join(f'0x{v:04X}' for v in table_vals)} (+{fst['offset']} RPM)")
    speeds = sorted(set(r for r in rpm if r >= 0))
    print(f"Speeds:      {', '.join(str(s) for s in speeds)} RPM")
    unmapped = [i for i, r in enumerate(rpm) if r < 0]
    if unmapped:
        print(f"Unmapped EC values (reported as no data): {', '.join(map(str, unmapped))}")

    if args.out:
        rows = ",\n".join(
            "\t" + ", ".join(f"{r:5d}" for r in rpm[i:i + 8]) for i in range(0, len(rpm), 8))
        header = f"""/* SPDX-License-Identifier: GPL-2.0 */
/*
 * Generated by dsdt-fan-config.py from this machine's DSDT - do not edit.
 * Re-run install.sh after a BIOS update.
 *
 * DSDT:     {ident}
 * EC field: {fst['full_path']} (EC 0x{byte:02X}, bits {shift}-{shift + width - 1})
 * Table:    {fst['table']} = {', '.join(f'0x{v:04X}' for v in table_vals)}, +{fst['offset']}
 */
#ifndef GALAXYBOOK_FAN_CONFIG_H
#define GALAXYBOOK_FAN_CONFIG_H

#define GB_DSDT_ID\t\t{c_string(ident)}
#define GB_DSDT_OEM_ID\t\t{c_string(oem_id)}
#define GB_DSDT_OEM_TABLE_ID\t{c_string(oem_table)}
#define GB_DSDT_OEM_REV\t\t0x{oem_rev:08x}
#define GB_DMI_PRODUCT\t\t{c_string(args.product)}
#define GB_EC_PATH\t\t{c_string(fst['ec_path'])}
#define GB_EC_ADDR\t\t0x{byte:02x}
#define GB_EC_SHIFT\t\t{shift}
#define GB_EC_WIDTH\t\t{width}

/* RPM for each raw EC value; -1 = no data (outside the firmware table) */
static const int gb_rpm_for_raw[{len(rpm)}] = {{
{rows}
}};

#endif
"""
        try:
            with open(args.out, "w", encoding="utf-8") as f:
                f.write(header)
        except OSError as e:
            print(f"Can't write {args.out}: {e}", file=sys.stderr)
            return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
