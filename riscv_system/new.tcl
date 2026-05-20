
# Read Data

read_verilog /home/m44892me/Questa/COMP12111/src/BoardLib/AckieV2.v
read_verilog /home/m44892me/Questa/COMP12111/src/BoardLib/Board_reset.v
read_verilog /home/m44892me/Questa/COMP12111/src/BoardLib/BoardV3.v
read_verilog /home/m44892me/Questa/COMP12111/src/BoardLib/Clocks.v
read_verilog /home/m44892me/Questa/COMP12111/src/BoardLib/Keyboard.v
read_verilog /home/m44892me/Questa/COMP12111/src/BoardLib/Segments_Scan.v
read_verilog /home/m44892me/Questa/COMP12111/src/BoardLib/Uart_s7.v
read_verilog /home/m44892me/Questa/COMP12111/src/Ex2/Traffic_Light.v
read_verilog /home/m44892me/Questa/COMP12111/src/Ex2/Traffic_Light_Board.v
read_verilog /home/m44892me/Questa/COMP12111/src/GLIB/glbl.v




synth_design  -top Traffic_Light_Board -part xc7s25ftgb196-1 -fsm_extraction off 



read_xdc /cadtools5/questa_custom/resource/comp12111/BoardV3_timing.xdc
read_xdc /cadtools5/questa_custom/resource/comp12111/BoardV3_physical.xdc

opt_design
power_opt_design -verbose
place_design -directive Explore
route_design -directive Explore
report_io  -file post_route_io.rpt

set_property BITSTREAM.CONFIG.USR_ACCESS         0xaabbccdd    [current_design]
set_property CONFIG_VOLTAGE                     3.3            [current_design]
set_property CFGBVS                             VCCO           [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE        16             [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR    No             [current_design]
set_property BITSTREAM.CONFIG.USERID   0xB623D            [current_design]
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set design_name  Traffic_Light_Board 

write_bitstream -force ${design_name}.bit
write_bitstream -force -bin_file ${design_name}
write_cfgmem    -force -format MCS -size 8 -loadbit "up 0x0 ${design_name}.bit" -interface SPIx1 ${design_name}
exit 

