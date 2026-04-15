#!/usr/bin/env python3
import re
import subprocess
import sys


def main():
    if len(sys.argv) < 2:
        print("Usage: elftokmd.py <elf>", file=sys.stderr)
        sys.exit(1)

    elf = sys.argv[1]

    result = subprocess.run(
        ["riscv64-unknown-elf-objdump", "-d", "--no-show-raw-insn", elf],
        capture_output=True,
        text=True,
    )

    # Regex: lines like "   1a4:   li   a0, 1"
    insn_re = re.compile(r"^\s*([0-9a-f]+):\s+(.+)$")

    entries = []  # list of (address, instruction_string)

    for line in result.stdout.splitlines():
        m = insn_re.match(line)
        if not m:
            continue
        addr_str, insn = m.group(1), m.group(2).strip()
        # Skip lines where the "instruction" is raw hex bytes (no-show-raw-insn
        # already removes them, but guard anyway)
        if not insn:
            continue
        entries.append((int(addr_str, 16), insn))

    if not entries:
        print("No instructions found — is the ELF empty?", file=sys.stderr)
        sys.exit(1)

    # Emit KMD format: one instruction per line, address in hex
    # Use objdump WITH raw hex for the actual KMD encoding
    result2 = subprocess.run(
        ["riscv64-unknown-elf-objdump", "-d", elf], capture_output=True, text=True
    )

    insn_raw_re = re.compile(r"^\s*([0-9a-f]+):\s+([0-9a-f]+)\s+(.+)$")

    for line in result2.stdout.splitlines():
        m = insn_raw_re.match(line)
        if not m:
            continue
        addr = int(m.group(1), 16)
        hexval = m.group(2).strip()
        mnemonic = m.group(3).strip()
        # Pad hex to 8 digits
        print(f"0x{addr:x} : {hexval.zfill(8)} ; {mnemonic}")


if __name__ == "__main__":
    main()
