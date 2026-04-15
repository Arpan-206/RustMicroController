#!/usr/bin/env python3
import re
import subprocess
import sys


def load_raw_bytes(elf):
    """Return dict {addr: byte_value} from all LOAD sections via objdump -s."""
    result = subprocess.run(
        ["riscv64-unknown-elf-objdump", "-s", elf],
        capture_output=True, text=True,
    )
    mem = {}
    # Lines like:  40160 83200100 13018100 67800000 41727061  ................
    line_re = re.compile(r"^\s*([0-9a-f]+)\s+((?:[0-9a-f]{2,8}\s*)+)\s{2}")
    for line in result.stdout.splitlines():
        m = line_re.match(line)
        if not m:
            continue
        base = int(m.group(1), 16)
        offset = 0
        for token in m.group(2).split():
            # Each token is bytes in memory order, 2 hex chars per byte
            for i in range(0, len(token), 2):
                mem[base + offset] = int(token[i:i+2], 16)
                offset += 1
    return mem


def load_instructions(elf):
    """Return dict {addr: (hexword, mnemonic)} for real instructions via -D,
    excluding .insn pseudo-ops (which objdump emits for non-instruction bytes)."""
    result = subprocess.run(
        ["riscv64-unknown-elf-objdump", "-D", elf],
        capture_output=True, text=True,
    )
    insns = {}
    insn_re = re.compile(r"^\s*([0-9a-f]+):\s+([0-9a-f]+)\s+(.+)$")
    for line in result.stdout.splitlines():
        m = insn_re.match(line)
        if not m:
            continue
        addr = int(m.group(1), 16)
        hexval = m.group(2).strip()
        mnemonic = m.group(3).strip()
        # Skip .insn pseudo-ops — these are data bytes objdump couldn't decode
        if mnemonic.startswith(".insn"):
            continue
        insns[addr] = (hexval, mnemonic)
    return insns


def main():
    if len(sys.argv) < 2:
        print("Usage: elftokmd.py <elf>", file=sys.stderr)
        sys.exit(1)

    elf = sys.argv[1]

    mem = load_raw_bytes(elf)
    insns = load_instructions(elf)

    if not mem:
        print("No sections found — is the ELF empty?", file=sys.stderr)
        sys.exit(1)

    addresses = sorted(mem.keys())
    i = 0
    while i < len(addresses):
        addr = addresses[i]

        if addr in insns:
            # Emit as instruction line
            hexval, mnemonic = insns[addr]
            insn_size = len(hexval) // 2  # 2 or 4 bytes
            print(f"0x{addr:x} : {hexval.zfill(8)} ; {mnemonic}")
            i += insn_size
        else:
            # Emit as raw data bytes (up to 4 per line, matching main.kmd format)
            chunk = []
            for j in range(4):
                if i >= len(addresses):
                    break
                a = addresses[i]
                if a != addr + j:
                    break  # gap in memory
                if a in insns:
                    break  # hit an instruction boundary
                chunk.append(mem[a])
                i += 1
            hex_bytes = " ".join(f"{b:02X}" for b in chunk)
            print(f"0x{addr:x} : {hex_bytes}")


if __name__ == "__main__":
    main()
