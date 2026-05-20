#!/bin/bash

export PATH=$PATH:/cadtools5/Xilinx_Vivado_2024.2/Vivado/2024.1/bin
export PATH=$PATH:/cadtools5/Vivado2024.1/Vivado/2024.1/bin 
export PATH=$PATH:/cadtools5/Vivado2024.1/Vivado/2024.1/bin



SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR

rm -rf ./RISCV_Dual
vivado -source riscv.tcl -mode batch

echo "Bit file should have been built"
echo "impl2_run files are in ./RISCV_Dual/RISCV_Dual.runs/impl_2"

read -p "Press enter to continue"