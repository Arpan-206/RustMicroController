#!/bin/bash
set -e

ELF="target/riscv32im-unknown-none-elf/release/rv32-bare"
KMD="rv32-bare.kmd"

echo ">> Building Rust..."
cargo build --release

echo ">> Converting ELF to KMD..."
python3 elftokmd.py "$ELF" > "$KMD"

echo ">> Done: $KMD"
