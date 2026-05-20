#!/bin/bash
  
export PATH=$PATH:/cadtools5/Xilinx_Vivado_2024.2/Vivado/2024.1/bin
export PATH=$PATH:/data/Xilinx/Vivado/2024.1/bin/
export PATH=$PATH:/data/Xilinx/Vivado/2024.1/bin/
export PATH=$PATH:/cadtools5/Vivado2024.1/Vivado/2024.1/bin


SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $SCRIPT_DIR
 
vivado ./RISCV_Dual/RISCV_Dual.xpr
 