//`define VERSION_ID      32'h20_11_24                          /* ID by date */
//`define VERSION_ID      32'h13_12_24                          /* ID by date */
//`define VERSION_ID      32'h20_12_24                          /* ID by date */
`define VERSION_ID      32'h09_07_25                            /* ID by date */
                                                            /* LED pattern rm */

//`define CLOCK_FREQUENCY 32'd10_000_000                  /* 10 MHz system CLK*/
//`define CLOCK_FREQUENCY 32'd20_000_000                 /* System clock rate */
`define CLOCK_FREQUENCY 32'd40_000_000                   /* Changed to 40 MHz */
`define BAUD_RATE       32'd115_200              /* Default baud rate to host */
`define TIMER_FREQUENCY 32'd1_000_000            /* Timer frequency (/ <2^10) */

`define RESET_ADDRESS   32'h0000_0000

/* Most of used space in first MiB: first 256 KiB is 'protected'              */
`define MEMORY_AREA_S0  16'h0000 /* Master Machine memory (00000000-0000FFFC) */
`define PERIPH          16'h0001     /* Intervening pages are for I/O devices */
`define PERIPHU         16'h0002
                                                                /* "Reserved" */
`define MEMORY_AREA_S1a 16'h0004       /* Slave User memory 00040000-0007FFFC */
`define MEMORY_AREA_S1b 16'h0005
`define MEMORY_AREA_S1c 16'h0006
`define MEMORY_AREA_S1d 16'h0007

`define MEMORY_WORDS_1  2048
`define MEMORY_WORDS_2 32786

`define SRAM            12'h001                /* Second MiB of address space */

`define P_LED    8'h00                  /* I/O device offsets within 'PERIPH' */
`define P_LCD    8'h01
`define P_TIM    8'h02
`define P_PIO    8'h03
`define P_INT    8'h04
`define P_FIFO   8'h05
`define P_VDU    8'h06
`define P_CTL    8'h07
`define P_DE     8'h08

`define RD_EMPTY       2'b00/* Enumerated states: destination register status */
`define RD_PASSING     2'b01
`define RD_AWAITED     2'b10
`define RD_READY       2'b11

`define SRC_REG        2'b00/* Enumerated states: register source for execute */
`define SRC_EXEC       2'b01
`define SRC_MEM        2'b10

`define RD_NONE        2'b00
`define RD_EXEC        2'b01
`define RD_LOAD        2'b10
`define RD_CSR         2'b11

`define BR_NONE        2'b00                /* Enumerated states: branch type */
`define BR_REG         2'b01
`define BR_AL          2'b10
`define BR_CC          2'b11

`define TRAP_IN_ALGN   6'h00/* Codes indicating exception types, returns etc. */
`define TRAP_IN_ACC    6'h01/* Top bit (currently 5) is set for interrupts    */
`define TRAP_ILLEGAL   6'h02/* Next bit (currently 4) is set for trap returns */
`define TRAP_BREAK     6'h03/* Remaining bits code for cause (mostly)         */
`define TRAP_LD_ALGN   6'h04
`define TRAP_LD_ACC    6'h05
`define TRAP_ST_ALGN   6'h06
`define TRAP_ST_ACC    6'h07
`define TRAP_U_ECALL   6'h08
`define TRAP_S_ECALL   6'h09
`define TRAP_M_ECALL   6'h0B
`define TRAP_IN_PAGE   6'h0C
`define TRAP_LD_PAGE   6'h0D
`define TRAP_ST_PAGE   6'h0F
`define TRAP_URET      6'h10            /* Also codes other system operations */
`define TRAP_SRET      6'h11                 /* Change prefix to 'SYS_'?? *** */
`define TRAP_MRET      6'h13
`define TRAP_NONE      6'h1E
`define TRAP_UNKNOWN   6'h1F                                  /* Unrecognised */
`define TRAP_INT_US    6'h20
`define TRAP_INT_SS    6'h21
`define TRAP_INT_MS    6'h23
`define TRAP_INT_UT    6'h24
`define TRAP_INT_ST    6'h25
`define TRAP_INT_MT    6'h27
`define TRAP_INT_UE    6'h28
`define TRAP_INT_SE    6'h29
`define TRAP_INT_ME    6'h2B

`define ABORT_NONE      3'h0                 /* Enumerated states: abort type */
`define ABORT_LD_ALGN   3'h1
`define ABORT_LD_ACC    3'h2
`define ABORT_LD_PAGE   3'h3
`define ABORT_ST_ALGN   3'h5
`define ABORT_ST_ACC    3'h6
`define ABORT_ST_PAGE   3'h7

`define ABORT_BIT_ALGN     0                       /* Bit positions in vector */
`define ABORT_BIT_ACC      1
`define ABORT_BIT_PAGE     2

`define ADDR_USTATUS    12'h000                     /* CSR register addresses */
`define ADDR_UIE        12'h004
`define ADDR_UTVEC      12'h005
`define ADDR_USTATUSH   12'h010
`define ADDR_USCRATCH   12'h040
`define ADDR_UEPC       12'h041
`define ADDR_UCAUSE     12'h042
`define ADDR_UTVAL      12'h043

`define ADDR_SSTATUS    12'h100
`define ADDR_SEDELEG    12'h102
`define ADDR_SIDELEG    12'h103
`define ADDR_SIE        12'h104
`define ADDR_STVEC      12'h105
`define ADDR_SCOUNTEREN 12'h106
`define ADDR_SSTATUSH   12'h110
`define ADDR_SSCRATCH   12'h140
`define ADDR_SEPC       12'h141
`define ADDR_SCAUSE     12'h142
`define ADDR_STVAL      12'h143

`define ADDR_MSTATUS    12'h300
`define ADDR_MISA       12'h301
`define ADDR_MEDELEG    12'h302
`define ADDR_MIDELEG    12'h303
`define ADDR_MIE        12'h304
`define ADDR_MTVEC      12'h305
`define ADDR_MCOUNTEREN 12'h306
`define ADDR_MSTATUSH   12'h310
`define ADDR_MCOUNTINHIBIT 12'h320
`define ADDR_MSCRATCH   12'h340
`define ADDR_MEPC       12'h341
`define ADDR_MCAUSE     12'h342
`define ADDR_MTVAL      12'h343
`define ADDR_MIP        12'h344

`define ADDR_CYCLE      12'hC00
`define ADDR_TIME       12'hC01
`define ADDR_INSTRET    12'hC02
`define ADDR_CYCLEH     12'hC80
`define ADDR_TIMEH      12'hC81
`define ADDR_INSTRETH   12'hC82

`define ADDR_MVENDORID  12'hF11
`define ADDR_MARCHID    12'hF12
`define ADDR_MIMPID     12'hF13
`define ADDR_MHARTID    12'hF14
`define ADDR_MCONFIGPTR 12'hF15

`define MISA_DEFAULT    32'h4014_1100          /* ISA supported, inc. U, S, M */
`define MISA_MASK       32'h4014_1000        /* Can't clear I (so E always 0) */
`define MIP_READ_MASK   32'h0000_0AAA // Also MIE(?)  Review these! @@@
`define MIP_WRITE_MASK  32'h0000_0AAA
`define MEDELEG_MASK    32'h0000_BBFF
`define MIDELEG_MASK    32'h0000_0BBB

/* Control addressing (space 0, processor) uses bit 8 to mux fetch/mem stages */
`define CTRL_PC          32'h000          /* External ctrl register addresses */
`define CTRL_MODE        32'h001                          /* Enable(s) (etc.) */
`define CTRL_FETCHES     32'h002             /* Number of fetches before halt */
`define CTRL_BKPT_ID     32'h003     /* ID bit vector of active breakpoint(s) */
`define CTRL_PRIV        32'h004           /* Processor privilege mode (etc?) */
`define CTRL_BKPT_EN     32'h005                        /* Breakpoint enables */
`define CTRL_BKPT        32'h080                  /* Breakpoint register base */

`define CTRL_WTCH_0      32'h100                   /* Watchpoint base address */
`define CTRL_WTCH_1      32'h110
`define CTRL_WTCH_2      32'h120
`define CTRL_WTCH_3      32'h130
`define CTRL_WTCH_AD     32'h000               /* Watchpoint register offsets */
`define CTRL_WTCH_AD_MSK 32'h001
`define CTRL_WTCH_CTRL   32'h002
`define CTRL_WTCH_EN     32'h10E
`define CTRL_WTCH_SRC    32'h10F
