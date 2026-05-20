# Vivado Constraints file for new lab board. Board version - V1.2
#
# File version 1.0 12/4/24 - dmc
#
# ------------------------------
# File version 1.1 19/4/24 - dmc
# 19/4/24 - set_property PACKAGE_PIN Y3  [get_ports {SRAM_D[29]}]
#           corrected to  pin Y4 - Anthony
# ------------------------------
# V1.2 - 25-6-24 - dmc
# Changed FPGA_IO pins to buses.
#
# Changed CLK_100MHZ_R to
# CLK_50MHZ_R
# Changed FPGA_LED_EN to FPGA_LED_NEN
# Added FPGA_LCD_NBL
# Changed name on LCD control pins (+ "_ctrl")
# Removed comment about 100MHz clock
# ------------------------------
#

set_property BITSTREAM.CONFIG.UNUSEDPIN PULLDOWN [current_design]
# or perhaps PULLUP ?
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

set_property PACKAGE_PIN U18 [get_ports CLK_50MHZ_R]

# UART
set_property PACKAGE_PIN N21 [get_ports FTDI_TXD]
set_property PACKAGE_PIN P21 [get_ports FTDI_RXD]
set_property PACKAGE_PIN N20 [get_ports FTDI_NRTS]
set_property PACKAGE_PIN P20 [get_ports FTDI_NCTS]

# SPI
# set_property PACKAGE_PIN D9  [get_ports {cclk}]
# set_property PACKAGE_PIN N17 [get_ports {spi_cs}]
# set_property PACKAGE_PIN M21 [get_ports {spi_mosi}]
# set_property PACKAGE_PIN M22 [get_ports {spi_din}]


# LED
set_property PACKAGE_PIN B22 [get_ports FPGA_RED1]
# D3
set_property PACKAGE_PIN F21 [get_ports FPGA_YEL1]
# D5
set_property PACKAGE_PIN D22 [get_ports FPGA_GRN1]
# D7
set_property PACKAGE_PIN E22 [get_ports FPGA_BLU1]
# D9

set_property PACKAGE_PIN F22 [get_ports FPGA_RED2]
# D4
set_property PACKAGE_PIN G22 [get_ports FPGA_YEL2]
# D6
set_property PACKAGE_PIN J22 [get_ports FPGA_GRN2]
# D8
set_property PACKAGE_PIN K22 [get_ports FPGA_BLU2]
# D10

set_property PACKAGE_PIN A21 [get_ports FPGA_LED_NEN]
# NOTE - This is active low.
#

# LCD
set_property PACKAGE_PIN A19 [get_ports {FPGA_LCD[0]}]
set_property PACKAGE_PIN A18 [get_ports {FPGA_LCD[1]}]
set_property PACKAGE_PIN A17 [get_ports {FPGA_LCD[2]}]
set_property PACKAGE_PIN A16 [get_ports {FPGA_LCD[3]}]
set_property PACKAGE_PIN A14 [get_ports {FPGA_LCD[4]}]
set_property PACKAGE_PIN A13 [get_ports {FPGA_LCD[5]}]
set_property PACKAGE_PIN A12 [get_ports {FPGA_LCD[6]}]
set_property PACKAGE_PIN A11 [get_ports {FPGA_LCD[7]}]

set_property PACKAGE_PIN B19 [get_ports {FPGA_LCD_ctrl[0]}]
set_property PACKAGE_PIN A20 [get_ports {FPGA_LCD_ctrl[1]}]
set_property PACKAGE_PIN B13 [get_ports {FPGA_LCD_ctrl[2]}]
set_property PACKAGE_PIN E15 [get_ports FPGA_LCD_NBL]
#

# Buttons
set_property PACKAGE_PIN D11 [get_ports FPGA_SW1]
# SW1
set_property PACKAGE_PIN D12 [get_ports FPGA_SW3]
# SW3 - bit confusing !
set_property PACKAGE_PIN D13 [get_ports FPGA_SW2]
# SW2 -
set_property PACKAGE_PIN D14 [get_ports FPGA_SW4]
# SW4
#
# IO connector J15 - OLD - V1.1 PCB
#set_property PACKAGE_PIN AA1 [get_ports {FPGA_IO_0[8]}]
#set_property PACKAGE_PIN AB2 [get_ports {FPGA_IO_0[7]}]
#set_property PACKAGE_PIN AA2 [get_ports {FPGA_IO_0[9]}]
#set_property PACKAGE_PIN AB4 [get_ports {FPGA_IO_0[6]}]
#set_property PACKAGE_PIN AB5 [get_ports {FPGA_IO_0[10]}]
#set_property PACKAGE_PIN AA7 [get_ports {FPGA_IO_0[5]}]
#set_property PACKAGE_PIN AB7 [get_ports {FPGA_IO_0[11]}]
#set_property PACKAGE_PIN AA8 [get_ports {FPGA_IO_0[4]}]
#set_property PACKAGE_PIN AB9 [get_ports {FPGA_IO_0[12]}]
#set_property PACKAGE_PIN AA9 [get_ports {FPGA_IO_0[3]}]
#set_property PACKAGE_PIN AB10 [get_ports {FPGA_IO_0[13]}]
#set_property PACKAGE_PIN AA10 [get_ports {FPGA_IO_0[2]}]
#set_property PACKAGE_PIN V8 [get_ports {FPGA_IO_0[14]}]
#set_property PACKAGE_PIN Y7 [get_ports {FPGA_IO_0[1]}]
#set_property PACKAGE_PIN Y8 [get_ports {FPGA_IO_0[15]}]
#set_property PACKAGE_PIN W7 [get_ports {FPGA_IO_0[0]}]
#

# IO connector J15 - NEW - V1.2 PCB
set_property PACKAGE_PIN AA1  [get_ports {FPGA_IO_0[0]}]
set_property PACKAGE_PIN AB2  [get_ports {FPGA_IO_0[1]}]
set_property PACKAGE_PIN AA2  [get_ports {FPGA_IO_0[2]}]
set_property PACKAGE_PIN AB4  [get_ports {FPGA_IO_0[3]}]
set_property PACKAGE_PIN AB5  [get_ports {FPGA_IO_0[4]}]
set_property PACKAGE_PIN AA7  [get_ports {FPGA_IO_0[5]}]
set_property PACKAGE_PIN AB7  [get_ports {FPGA_IO_0[6]}]
set_property PACKAGE_PIN AA8  [get_ports {FPGA_IO_0[7]}]
set_property PACKAGE_PIN AB9  [get_ports {FPGA_IO_0[8]}]
set_property PACKAGE_PIN AA9  [get_ports {FPGA_IO_0[9]}]
set_property PACKAGE_PIN AB10 [get_ports {FPGA_IO_0[10]}]
set_property PACKAGE_PIN AA10 [get_ports {FPGA_IO_0[11]}]
set_property PACKAGE_PIN V8   [get_ports {FPGA_IO_0[12]}]
set_property PACKAGE_PIN Y7   [get_ports {FPGA_IO_0[13]}]
set_property PACKAGE_PIN Y8   [get_ports {FPGA_IO_0[14]}]
set_property PACKAGE_PIN W7   [get_ports {FPGA_IO_0[15]}]
#

# IO connector J16 - NEW - V1.2 PCB
set_property PACKAGE_PIN Y19   [get_ports {FPGA_IO_1[16]}]
set_property PACKAGE_PIN P15   [get_ports {FPGA_IO_1[17]}]
set_property PACKAGE_PIN Y20   [get_ports {FPGA_IO_1[18]}]
set_property PACKAGE_PIN P16   [get_ports {FPGA_IO_1[19]}]
set_property PACKAGE_PIN Y21   [get_ports {FPGA_IO_1[20]}]
set_property PACKAGE_PIN R18   [get_ports {FPGA_IO_1[21]}]
set_property PACKAGE_PIN AA21  [get_ports {FPGA_IO_1[22]}]
set_property PACKAGE_PIN R17   [get_ports {FPGA_IO_1[23]}]
set_property PACKAGE_PIN AA20  [get_ports {FPGA_IO_1[24]}]
set_property PACKAGE_PIN R16   [get_ports {FPGA_IO_1[25]}]
set_property PACKAGE_PIN AB19  [get_ports {FPGA_IO_1[26]}]
set_property PACKAGE_PIN T16   [get_ports {FPGA_IO_1[27]}]
set_property PACKAGE_PIN AB21  [get_ports {FPGA_IO_1[28]}]
set_property PACKAGE_PIN T19   [get_ports {FPGA_IO_1[29]}]
set_property PACKAGE_PIN AB20  [get_ports {FPGA_IO_1[30]}]
set_property PACKAGE_PIN U17   [get_ports {FPGA_IO_1[31]}]
#
# IO connector J16 - OLD - V1.1 PCB
#set_property PACKAGE_PIN Y19 [get_ports {FPGA_IO_1[24]}]
#set_property PACKAGE_PIN P15 [get_ports {FPGA_IO_1[23]}]
#set_property PACKAGE_PIN Y20 [get_ports {FPGA_IO_1[25]}]
#set_property PACKAGE_PIN P16 [get_ports {FPGA_IO_1[22]}]
#set_property PACKAGE_PIN Y21 [get_ports {FPGA_IO_1[26]}]
#set_property PACKAGE_PIN R18 [get_ports {FPGA_IO_1[21]}]
#set_property PACKAGE_PIN AA21 [get_ports {FPGA_IO_1[27]}]
#set_property PACKAGE_PIN R17 [get_ports {FPGA_IO_1[20]}]
#set_property PACKAGE_PIN AA20 [get_ports {FPGA_IO_1[28]}]
#set_property PACKAGE_PIN R16 [get_ports {FPGA_IO_1[19]}]
#set_property PACKAGE_PIN AB19 [get_ports {FPGA_IO_1[29]}]
#set_property PACKAGE_PIN T16 [get_ports {FPGA_IO_1[18]}]
#set_property PACKAGE_PIN AB21 [get_ports {FPGA_IO_1[30]}]
#set_property PACKAGE_PIN T19 [get_ports {FPGA_IO_1[17]}]
#set_property PACKAGE_PIN AB20 [get_ports {FPGA_IO_1[31]}]
#set_property PACKAGE_PIN U17 [get_ports {FPGA_IO_1[16]}]
#
# Arduino shield
# set_property PACKAGE_PIN B20   [get_ports {FPGA_ARDU_0}]
# set_property PACKAGE_PIN C19   [get_ports {FPGA_ARDU_1}]
# set_property PACKAGE_PIN C18   [get_ports {FPGA_ARDU_2}]
# set_property PACKAGE_PIN C17   [get_ports {FPGA_ARDU_3}]
# set_property PACKAGE_PIN C16   [get_ports {FPGA_ARDU_4}]
# set_property PACKAGE_PIN C15   [get_ports {FPGA_ARDU_5}]
# set_property PACKAGE_PIN E16   [get_ports {FPGA_ARDU_6}]
# set_property PACKAGE_PIN D16   [get_ports {FPGA_ARDU_7}]

# set_property PACKAGE_PIN F14   [get_ports {FPGA_ARDU_8}]
# set_property PACKAGE_PIN F13   [get_ports {FPGA_ARDU_9}]
# set_property PACKAGE_PIN F12   [get_ports {FPGA_ARDU_10}]
# set_property PACKAGE_PIN F11   [get_ports {FPGA_ARDU_11}]
# set_property PACKAGE_PIN C13   [get_ports {FPGA_ARDU_12}]
# set_property PACKAGE_PIN C12   [get_ports {FPGA_ARDU_13}]

# set_property PACKAGE_PIN C11   [get_ports {FPGA_ARDU_14}]
# set_property PACKAGE_PIN C10   [get_ports {FPGA_ARDU_15}]

# Analogue inputs - See XADC user guide. UG480
# --------------------------------------------
# AIN0
# FPGA_AD0P  - IO_L5P_T0_AD9P_15     - K16
# FPGA_AD0N  - IO_L5N_T0_AD9N_15     - J16

# AIN1
# FPGA_AD8P  - IO_L3P_T0_DQS_AD1P_15 - J17
# FPGA_AD8N  - IO_L3N_T0_DQS_AD1N_15 - H18

# AIN2
# FPGA_AD1P  - IO_L2P_T0_AD8P_15     - H17
# FPGA_AD1N  - IO_L2N_T0_AD8N_15     - G17

# AIN3
# FPGA_AD9P  - IO_L1P_T0_AD0P_15     - F17
# FPGA_AD9N  - IO_L1N_T0_AD0N_15     - F18

# AIN4
# FPGA_AD10P - IO_L8P_T1_AD10P_15    - D20
# FPGA_AD10N - IO_L8N_T1_AD10N_15    - C20

# AIN5
# FPGA_AD3P  - IO_L9P_T1_DQS_AD3P_15 - D21
# FPGA_AD3N  - IO_L9N_T1_DQS_AD3N_15 - C22

# HDMI connector
set_property PACKAGE_PIN V21 [get_ports R_FPGA_TMDS_D0_p]
set_property PACKAGE_PIN W22 [get_ports R_FPGA_TMDS_D0_n]
set_property PACKAGE_PIN U22 [get_ports R_FPGA_TMDS_D1_p]
set_property PACKAGE_PIN V22 [get_ports R_FPGA_TMDS_D1_n]
set_property PACKAGE_PIN T21 [get_ports R_FPGA_TMDS_D2_p]
set_property PACKAGE_PIN T22 [get_ports R_FPGA_TMDS_D2_n]
set_property PACKAGE_PIN Y22 [get_ports R_FPGA_TMDS_CLK_p]
set_property PACKAGE_PIN AA22 [get_ports R_FPGA_TMDS_CLK_n]

# set_property PACKAGE_PIN R7 [get_ports {R_FPGA_DCC_CLK}]
# Not needed for video.
# set_property PACKAGE_PIN R6 [get_ports {R_FPGA_DCC_DATA}]
#

# SRAM
set_property PACKAGE_PIN R2 [get_ports {SRAM_D[0]}]
set_property PACKAGE_PIN W5 [get_ports {SRAM_D[1]}]
set_property PACKAGE_PIN W4 [get_ports {SRAM_D[2]}]
set_property PACKAGE_PIN T7 [get_ports {SRAM_D[3]}]
set_property PACKAGE_PIN T6 [get_ports {SRAM_D[4]}]
set_property PACKAGE_PIN V5 [get_ports {SRAM_D[5]}]
set_property PACKAGE_PIN V4 [get_ports {SRAM_D[6]}]
set_property PACKAGE_PIN T5 [get_ports {SRAM_D[7]}]
set_property PACKAGE_PIN U5 [get_ports {SRAM_D[8]}]
set_property PACKAGE_PIN V7 [get_ports {SRAM_D[9]}]
set_property PACKAGE_PIN V6 [get_ports {SRAM_D[10]}]
set_property PACKAGE_PIN T8 [get_ports {SRAM_D[11]}]
set_property PACKAGE_PIN U8 [get_ports {SRAM_D[12]}]
set_property PACKAGE_PIN V1 [get_ports {SRAM_D[13]}]
set_property PACKAGE_PIN W1 [get_ports {SRAM_D[14]}]
set_property PACKAGE_PIN W2 [get_ports {SRAM_D[15]}]
set_property PACKAGE_PIN Y1 [get_ports {SRAM_D[16]}]
set_property PACKAGE_PIN U2 [get_ports {SRAM_D[17]}]
set_property PACKAGE_PIN U1 [get_ports {SRAM_D[18]}]
set_property PACKAGE_PIN W3 [get_ports {SRAM_D[19]}]
set_property PACKAGE_PIN Y3 [get_ports {SRAM_D[20]}]
set_property PACKAGE_PIN U4 [get_ports {SRAM_D[21]}]
set_property PACKAGE_PIN U3 [get_ports {SRAM_D[22]}]
set_property PACKAGE_PIN T3 [get_ports {SRAM_D[23]}]
set_property PACKAGE_PIN T2 [get_ports {SRAM_D[24]}]
set_property PACKAGE_PIN AA6 [get_ports {SRAM_D[25]}]
set_property PACKAGE_PIN AB6 [get_ports {SRAM_D[26]}]
set_property PACKAGE_PIN Y6 [get_ports {SRAM_D[27]}]
set_property PACKAGE_PIN Y5 [get_ports {SRAM_D[28]}]
set_property PACKAGE_PIN Y4 [get_ports {SRAM_D[29]}]
set_property PACKAGE_PIN AA3 [get_ports {SRAM_D[30]}]
set_property PACKAGE_PIN AB3 [get_ports {SRAM_D[31]}]

set_property PACKAGE_PIN H7 [get_ports {SRAM_A[0]}]
set_property PACKAGE_PIN J3 [get_ports {SRAM_A[1]}]
set_property PACKAGE_PIN H2 [get_ports {SRAM_A[2]}]
set_property PACKAGE_PIN H4 [get_ports {SRAM_A[3]}]
set_property PACKAGE_PIN H3 [get_ports {SRAM_A[4]}]
set_property PACKAGE_PIN J2 [get_ports {SRAM_A[5]}]
set_property PACKAGE_PIN J1 [get_ports {SRAM_A[6]}]
set_property PACKAGE_PIN K3 [get_ports {SRAM_A[7]}]
set_property PACKAGE_PIN K2 [get_ports {SRAM_A[8]}]
set_property PACKAGE_PIN H6 [get_ports {SRAM_A[9]}]
set_property PACKAGE_PIN H5 [get_ports {SRAM_A[10]}]
set_property PACKAGE_PIN K6 [get_ports {SRAM_A[11]}]
set_property PACKAGE_PIN J6 [get_ports {SRAM_A[12]}]
set_property PACKAGE_PIN J8 [get_ports {SRAM_A[13]}]
set_property PACKAGE_PIN J7 [get_ports {SRAM_A[14]}]
set_property PACKAGE_PIN L7 [get_ports {SRAM_A[15]}]
set_property PACKAGE_PIN L6 [get_ports {SRAM_A[16]}]
set_property PACKAGE_PIN L5 [get_ports {SRAM_A[17]}]

set_property PACKAGE_PIN M4 [get_ports SRAM_NOE]
set_property PACKAGE_PIN M3 [get_ports SRAM_NCE]
set_property PACKAGE_PIN L1 [get_ports SRAM_L_NUB]
set_property PACKAGE_PIN K1 [get_ports SRAM_L_NLB]
set_property PACKAGE_PIN M2 [get_ports SRAM_L_NWE]
set_property PACKAGE_PIN M1 [get_ports SRAM_U_NUB]
set_property PACKAGE_PIN N4 [get_ports SRAM_U_NLB]
set_property PACKAGE_PIN N3 [get_ports SRAM_U_NWE]
#

###############################################################################

set_property IOSTANDARD LVCMOS33 [get_ports CLK_50MHZ_R]

# UART
set_property IOSTANDARD LVCMOS33 [get_ports FTDI_TXD]
set_property IOSTANDARD LVCMOS33 [get_ports FTDI_RXD]
set_property IOSTANDARD LVCMOS33 [get_ports FTDI_NRTS]
set_property IOSTANDARD LVCMOS33 [get_ports FTDI_NCTS]

# SPI
# set_property IOSTANDARD LVCMOS33 [get_ports {cclk}]
# set_property IOSTANDARD LVCMOS33 [get_ports {spi_cs}]
# set_property IOSTANDARD LVCMOS33 [get_ports {spi_mosi}]
# set_property IOSTANDARD LVCMOS33 [get_ports {spi_din}]

# Leds
set_property IOSTANDARD LVCMOS33 [get_ports FPGA_RED1]
set_property IOSTANDARD LVCMOS33 [get_ports FPGA_YEL1]
set_property IOSTANDARD LVCMOS33 [get_ports FPGA_GRN1]
set_property IOSTANDARD LVCMOS33 [get_ports FPGA_BLU1]

set_property IOSTANDARD LVCMOS33 [get_ports FPGA_RED2]
set_property IOSTANDARD LVCMOS33 [get_ports FPGA_YEL2]
set_property IOSTANDARD LVCMOS33 [get_ports FPGA_GRN2]
set_property IOSTANDARD LVCMOS33 [get_ports FPGA_BLU2]

set_property IOSTANDARD LVCMOS33 [get_ports FPGA_LED_NEN]
#

# LCD
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_LCD[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_LCD[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_LCD[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_LCD[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_LCD[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_LCD[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_LCD[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_LCD[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_LCD_ctrl[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_LCD_ctrl[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_LCD_ctrl[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports FPGA_LCD_NBL]

#set_property PULLDOWN     TRUE     [get_ports {FPGA_LCD[0]}]
#set_property PULLDOWN     TRUE     [get_ports {FPGA_LCD[1]}]
#set_property PULLDOWN     TRUE     [get_ports {FPGA_LCD[2]}]
#set_property PULLDOWN     TRUE     [get_ports {FPGA_LCD[3]}]
#set_property PULLDOWN     TRUE     [get_ports {FPGA_LCD[4]}]
#set_property PULLDOWN     TRUE     [get_ports {FPGA_LCD[5]}]
#set_property PULLDOWN     TRUE     [get_ports {FPGA_LCD[6]}]
#set_property PULLDOWN     TRUE     [get_ports {FPGA_LCD[7]}]
#set_property PULLDOWN     TRUE     [get_ports {FPGA_LCD_ctrl[0]}]
#set_property PULLDOWN     TRUE     [get_ports {FPGA_LCD_ctrl[1]}]
#set_property PULLDOWN     TRUE     [get_ports {FPGA_LCD_ctrl[2]}]
#

# Buttons
set_property IOSTANDARD LVCMOS33 [get_ports FPGA_SW1]
# SW1
set_property IOSTANDARD LVCMOS33 [get_ports FPGA_SW3]
# SW3
set_property IOSTANDARD LVCMOS33 [get_ports FPGA_SW2]
# SW2
set_property IOSTANDARD LVCMOS33 [get_ports FPGA_SW4]
# SW4
#

# IO connector J15
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_0[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_0[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_0[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_0[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_0[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_0[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_0[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_0[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_0[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_0[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_0[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_0[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_0[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_0[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_0[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_0[15]}]
#

# IO connector J16
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_1[16]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_1[17]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_1[18]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_1[19]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_1[20]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_1[21]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_1[22]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_1[23]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_1[24]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_1[25]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_1[26]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_1[27]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_1[28]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_1[29]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_1[30]}]
set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_IO_1[31]}]
#

# Arduino shield
# set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_ARDU_0}]
# set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_ARDU_1}]
# set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_ARDU_2}]
# set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_ARDU_3}]
# set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_ARDU_4}]
# set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_ARDU_5}]
# set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_ARDU_6}]
# set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_ARDU_7}]

# set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_ARDU_8}]
# set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_ARDU_9}]
# set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_ARDU_10}]
# set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_ARDU_11}]
# set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_ARDU_12}]
# set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_ARDU_13}]

# set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_ARDU_14}]
# set_property IOSTANDARD LVCMOS33 [get_ports {FPGA_ARDU_15}]

# HDMI connector
set_property IOSTANDARD TMDS_33 [get_ports R_FPGA_TMDS_D0_p]
set_property IOSTANDARD TMDS_33 [get_ports R_FPGA_TMDS_D0_n]
set_property IOSTANDARD TMDS_33 [get_ports R_FPGA_TMDS_D1_p]
set_property IOSTANDARD TMDS_33 [get_ports R_FPGA_TMDS_D1_n]
set_property IOSTANDARD TMDS_33 [get_ports R_FPGA_TMDS_D2_p]
set_property IOSTANDARD TMDS_33 [get_ports R_FPGA_TMDS_D2_n]
set_property IOSTANDARD TMDS_33 [get_ports R_FPGA_TMDS_CLK_p]
set_property IOSTANDARD TMDS_33 [get_ports R_FPGA_TMDS_CLK_n]

# set_property IOSTANDARD LVCMOS33 [get_ports {R_FPGA_DCC_CLK}]
# Not needed for video.
# set_property IOSTANDARD LVCMOS33 [get_ports {R_FPGA_DCC_DATA}]
#

# SRAM
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[16]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[17]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[18]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[19]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[20]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[21]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[22]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[23]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[24]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[25]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[26]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[27]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[28]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[29]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[30]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_D[31]}]


set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_A[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_A[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_A[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_A[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_A[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_A[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_A[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_A[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_A[8]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_A[9]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_A[10]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_A[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_A[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_A[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_A[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_A[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_A[16]}]
set_property IOSTANDARD LVCMOS33 [get_ports {SRAM_A[17]}]

set_property IOSTANDARD LVCMOS33 [get_ports SRAM_NOE]
set_property IOSTANDARD LVCMOS33 [get_ports SRAM_NCE]
set_property IOSTANDARD LVCMOS33 [get_ports SRAM_L_NUB]
set_property IOSTANDARD LVCMOS33 [get_ports SRAM_L_NLB]
set_property IOSTANDARD LVCMOS33 [get_ports SRAM_L_NWE]
set_property IOSTANDARD LVCMOS33 [get_ports SRAM_U_NUB]
set_property IOSTANDARD LVCMOS33 [get_ports SRAM_U_NLB]
set_property IOSTANDARD LVCMOS33 [get_ports SRAM_U_NWE]
#

###############################################################################






