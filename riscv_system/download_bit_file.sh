#!/bin/bash

# This script downloads a bit file to the RISC-V Lab Board
# A Mathews (2025)
# Paramaters: $1 should be the path to the bit file 

echo "Downloading BIT File to RISC-V FPGA Lab Board"
echo " Parameter 1 should be the bit file to load onto the FPGA"
echo " This is: $1"
 

export PATH=$PATH:/cadtools5/Xilinx_Vivado_2024.2/Vivado/2024.1/bin
export PATH=$PATH:/data/Xilinx/Vivado/2024.1/bin/
export PATH=$PATH:/cadtools5/Vivado2024.1/Vivado/2024.1/bin

if [ -z $1 ]; then echo "No file specified, exiting"; exit; else echo ""; fi

# store location of script dir
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd ) 

echo "Now launching vivado and uploading the new bit file"

# Generate a custom TCL script for downloading the board image 
# See vivado docs for 
TCL_FILE_CONTENT=" \
    open_hw_manager \n \
    connect_hw_server -allow_non_jtag \n \
    open_hw_target \n  \
    set_property PROGRAM.FILE {$1} [get_hw_devices xc7s50_0] \n \
    current_hw_device [get_hw_devices xc7s50_0] \n \
    refresh_hw_device -update_hw_probes false [lindex [get_hw_devices xc7s50_0] 0]  \n \
    create_hw_cfgmem -hw_device [get_hw_devices xc7s50_0] -mem_dev [lindex [get_cfgmem_parts {mt25ql128-spi-x1_x2_x4}] 0] \n \
    set_property PROBES.FILE {} [get_hw_devices xc7s50_0] \n \
    set_property FULL_PROBES.FILE {} [get_hw_devices xc7s50_0] \n \
    program_hw_devices [get_hw_devices xc7s50_0] \n \
    refresh_hw_device [lindex [get_hw_devices xc7s50_0] 0] "

# Save TCL Contents to temporary  file 
# avoids relying on file permissions on cadmaster
# etc 
TMP_FILE=$(mktemp -q /tmp/load_riscv_board.XXXXXX.tcl)
echo -e $TCL_FILE_CONTENT > $TMP_FILE

# Run VIVADO with the required TCL script  
vivado -mode batch -source $TMP_FILE
