#!/bin/bash

# This script converts and ELF file into
# kmd format

export PATH=$PATH:/data/toolchains/bin


TEMP_FILE=$(mktemp)
TEMP_FILE_B=$(mktemp)
DATA="$(riscv64-unknown-elf-objdump --source --source-comment="SRCSRC: " -d $1)"

echo "$DATA" > $TEMP_FILE

# Remove first 7 lines of header
tail -n +7 $TEMP_FILE > $TEMP_FILE_B
cat $TEMP_FILE_B

# Cleanup temp files
rm $TEMP_FILE
rm $TEMP_FILE_B
