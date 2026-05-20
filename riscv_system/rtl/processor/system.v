/* RV32i processor with 5-stage pipeline                        JDG July 2022 */
/* Latest mod.  3/6/23  More 'wrapping' - now reasonably neat at top level    */
/*                      Prepared for addition of second processor             */
/*              6/6/23  Moved to dual-port BRAM model                         */
/*             11/6/23  Dual processors; interprocessor FIFO (mostly)         */
/*             25/6/23  Most of watchpoint mechanism drafted (-partial- test) */
/*              5/7/24  Lab. type peripherals                                 */
/*            10/12/24  Memory interface clean up (+ general maintenance)     */
/*            20/12/24  Interrupts moved: tidying ...                         */
/*              2/9/25  User peripheral connections tidied                    */
/* Some 'To do's:
Clean up MPU form
Choke rate at FIFO slave end ('UART')
*/

/*----------------------------------------------------------------------------*/
//
/*----------------------------------------------------------------------------*/

module top (
    input  wire         CLK_50MHZ_R,
    input  wire         FTDI_TXD,
    output wire         FTDI_RXD,
    output wire         FPGA_RED1,
    output wire         FPGA_YEL1,
    output wire         FPGA_GRN1,
    output wire         FPGA_BLU1,
    output wire         FPGA_RED2,
    output wire         FPGA_YEL2,
    output wire         FPGA_GRN2,
    output wire         FPGA_BLU2,
    output wire         FPGA_LED_NEN,
    input  wire         FPGA_SW1,
    input  wire         FPGA_SW2,
    input  wire         FPGA_SW3,
    input  wire         FPGA_SW4,
    inout  wire [  7:0] FPGA_LCD,       /* 8 LCD data bits (bidirectional) */
    output wire [  2:0] FPGA_LCD_ctrl,  /* 3 LCD control bits */
    output wire         FPGA_LCD_NBL,   /* LCD backlight */
    inout  wire [ 15:0] FPGA_IO_0,
    inout  wire [31:16] FPGA_IO_1,
    input  wire         FTDI_NRTS,
    output wire         FTDI_NCTS,
    output wire         SRAM_NCE,
    output wire         SRAM_NOE,
    output wire         SRAM_U_NWE,
    output wire         SRAM_L_NWE,
    output wire         SRAM_U_NUB,
    output wire         SRAM_U_NLB,
    output wire         SRAM_L_NUB,
    output wire         SRAM_L_NLB,
    output wire [ 17:0] SRAM_A,
    inout  wire [ 31:0] SRAM_D,

    output wire R_FPGA_TMDS_D0_p,
    output wire R_FPGA_TMDS_D0_n,
    output wire R_FPGA_TMDS_D1_p,
    output wire R_FPGA_TMDS_D1_n,
    output wire R_FPGA_TMDS_D2_p,
    output wire R_FPGA_TMDS_D2_n,

    output wire R_FPGA_TMDS_CLK_p,
    output wire R_FPGA_TMDS_CLK_n
);

  wire clk, reset;  /* Sourced from 'top_ctrl' for simulation purposes */

  wire [ 7:0] led;  /* Output bus from peripheral */
  wire [ 3:0] sw;  /* Input bus to peripheral */

  wire [ 3:0] lcd_ctrl_o;  /* Signals coming from peripheral interface */
  wire [ 7:0] lcd_data_o;
  wire [ 7:0] lcd_data_i;

  wire [31:0] pio2_pin_in;  /* PIO connections to pad ring */
  wire [31:0] pio2_pin_out;  /* Slave subsystem */
  wire [31:0] pio2_pin_en;  // Want renaming/(moving)

  wire [31:0] pio2_pin_in_x;  /* PIO connections to pad ring */
  wire [31:0] pio2_pin_out_x;  /* Slave subsystem */
  wire [31:0] pio2_pin_en_x;  // Want renaming/(moving)

  wire [ 7:0] LED_pin;  /* LED Output bus to pad ring */

  wire [31:0] pin_fn;  /* Pin PIO or other function selects */
  wire [ 7:0] pin_LED;  /* Pin LED function selects */


  wire        pin_LCD;  /* LCD select. High for User_Peripheral con */
  /* -trol, low for LCD controller            */
  wire        pin_LCD_BL;

  wire [31:0] user_periph_din;  /* Alternate I/O buses from user defined block */
  wire [31:0] user_periph_dout;
  wire [31:0] user_periph_dir;
  wire [ 7:0] user_periph_LED;  /* Switches in common with LED port here */
  wire [ 7:0] user_periph_LCD_i;
  wire [11:0] user_periph_LCD_o;

  wire        SRAM_n_CS_o;
  wire        SRAM_n_rd_o;
  wire        SRAM_n_wr_o;  /* Timing strobe */
  wire [17:0] SRAM_address_o;
  wire [ 3:0] SRAM_n_bytes_o;
  wire        SRAM_n_write_o;  /* Data output enable */
  wire [31:0] SRAM_d_in_i;
  wire [31:0] SRAM_d_out_o;

  //assign FTDI_NRTS = 0;  // This works?
  assign FTDI_NCTS    = 0;

  assign FPGA_RED1    = LED_pin[0];
  assign FPGA_YEL1    = LED_pin[1];
  assign FPGA_GRN1    = LED_pin[2];
  assign FPGA_BLU1    = LED_pin[3];
  assign FPGA_RED2    = LED_pin[4];
  assign FPGA_YEL2    = LED_pin[5];
  assign FPGA_GRN2    = LED_pin[6];
  assign FPGA_BLU2    = LED_pin[7];
  assign FPGA_LED_NEN = 1'b0;  /* LED driver permanently enabled */

  assign sw[0]        = FPGA_SW1;
  assign sw[1]        = FPGA_SW2;
  assign sw[2]        = FPGA_SW3;
  assign sw[3]        = FPGA_SW4;


  genvar ii;

  /** Mux LCD controller with User_Peripheral control */

  /** Mux signals, keep the NBL inverted for the user peripheral */
  assign FPGA_LCD_ctrl = pin_LCD ? user_periph_LCD_o[10:8] : lcd_ctrl_o[2:0];
  /* LCD backlight enable controlled via separate function pin */
  assign FPGA_LCD_NBL  = pin_LCD_BL ? ~user_periph_LCD_o[11] : !lcd_ctrl_o[3];

  /** Generate muxes and IOBufs for the User_Peripheral and LCD Controller */
  generate
    assign user_periph_LCD_i = lcd_data_i;

    for (ii = 0; ii < 8; ii = ii + 1) begin
      IOBUF LCD_pad_buffer (
          .I (pin_LCD ? user_periph_LCD_o[ii] : lcd_data_o[ii]),
          .O (lcd_data_i[ii]),
          .T (pin_LCD ? user_periph_LCD_o[8] : lcd_ctrl_o[0]),    /* notWrite = 0 to enable */
          .IO(FPGA_LCD[ii])
      );
    end
  endgenerate


  generate  /* Multiplex auxiliary (currently dummy) functions on I/O pins */

    for (ii = 0; ii < 32; ii = ii + 1) begin  // also see debug_* elsewhere @@@
      assign pio2_pin_out_x[ii] = pin_fn[ii] ? user_periph_dout[ii] : pio2_pin_out[ii];
      assign pio2_pin_en_x[ii]  = pin_fn[ii] ? user_periph_dir[ii] : ~pio2_pin_en[ii];
    end

    for (ii = 0; ii < 8; ii = ii + 1) begin
      assign LED_pin[ii] = pin_LED[ii] ? user_periph_LED[ii] : led[ii];
    end
  endgenerate

  //  assign  user_periph_din[ii] =  pio2_pin_in_x[ii];
  //  assign  pio2_pin_in[ii]     =  pio2_pin_in_x[ii];

  assign user_periph_din = pio2_pin_in_x;
  assign pio2_pin_in     = pio2_pin_in_x;

  IOBUF port_pio_pad_buffer_J15[15:0] (
      .I (pio2_pin_out_x[15:0]),  /* J15*/
      .O (pio2_pin_in_x[15:0]),
      .IO(FPGA_IO_0[15:0]),
      .T (pio2_pin_en_x[15:0])
  );

  IOBUF port_pio_pad_buffer_J16[15:0] (
      .I (pio2_pin_out_x[31:16]),  /* J16 */
      .O (pio2_pin_in_x[31:16]),
      .IO(FPGA_IO_1[31:16]),
      .T (pio2_pin_en_x[31:16])
  );

  OBUFDS #(
      .IOSTANDARD("TMDS_33"),
      .SLEW("FAST")
  ) OBUFDS_clock (
      .I (clk),
      .O (R_FPGA_TMDS_CLK_p),
      .OB(R_FPGA_TMDS_CLK_n)
  );

  OBUFDS #(
      .IOSTANDARD("TMDS_33"),
      .SLEW("FAST")
  ) OBUFDS_red (
      .I (TMDS_shift_red_o),
      .O (R_FPGA_TMDS_D2_p),
      .OB(R_FPGA_TMDS_D2_n)
  );
  OBUFDS #(
      .IOSTANDARD("TMDS_33"),
      .SLEW("FAST")
  ) OBUFDS_green (
      .I (TMDS_shift_green_o),
      .O (R_FPGA_TMDS_D1_p),
      .OB(R_FPGA_TMDS_D1_n)
  );

  OBUFDS #(
      .IOSTANDARD("TMDS_33"),
      .SLEW("FAST")
  ) OBUFDS_blue (
      .I (TMDS_shift_blue_o),
      .O (R_FPGA_TMDS_D0_p),
      .OB(R_FPGA_TMDS_D0_n)
  );

  assign SRAM_NCE   = SRAM_n_CS_o;
  assign SRAM_NOE   = SRAM_n_rd_o;
  assign SRAM_U_NWE = SRAM_n_wr_o;
  assign SRAM_L_NWE = SRAM_n_wr_o;
  assign SRAM_U_NUB = SRAM_n_bytes_o[3];
  assign SRAM_U_NLB = SRAM_n_bytes_o[2];
  assign SRAM_L_NUB = SRAM_n_bytes_o[1];
  assign SRAM_L_NLB = SRAM_n_bytes_o[0];
  assign SRAM_A     = SRAM_address_o;

  IOBUF SRAM_pad_data_buffer[31:0] (
      .I (SRAM_d_out_o),
      .O (SRAM_d_in_i),
      .T ({32{SRAM_n_write_o}}),  /* notWrite = 0 to enable */
      .IO(SRAM_D)
  );

  wire [31:0] instr_address;  /* Instruction fetch address */
  wire [ 1:0] instr_mode;  /* Instruction fetch mode */
  wire [ 1:0] instr_size;  /* Instruction fetch size (= word) */
  wire        instr_read;  /* Instruction fetch active */
  wire [31:0] instr_data;  /* Load data */
  wire        instr_wait;  /* Load data not ready */
  wire [ 2:0] instr_abort;  /* Memory operation abort code */

  wire [31:0] data_address;  /* Load/store address bus */
  wire [ 1:0] data_mode;  /* Load/store mode */
  wire [ 1:0] data_size;  /* Load/store size */
  wire        data_read;  /* Load active */
  wire        data_write;  /* Store active */
  wire [31:0] data_data_st;  /* Store data */
  wire [31:0] data_data_ld;  /* Load data */
  wire        data_wait;  /* Load data not ready */
  wire [ 2:0] data_abort;  /* Memory operation abort code */
  wire [11:0] interrupts;  /* Interrupt inputs */

  wire [63:0] mtime;  /* System time */
  wire        mtimer_irq;  /* System timer interrupt */

  wire        ctrl_run;  /* Instruction fetch can take place */
  wire        ctrl_step;  /* Pulse to step, including continue from breakpoint */
  wire        ctrl_busy;  /* There are active operations in the pipeline */
  wire        ctrl_broken;  /* Breakpoint encountered */
  wire        ctrl_we;  /* Write Enable to slave unit */
  wire [ 1:0] ctrl_space;  /* Address space for external R/W {ctrl,reg,CSR,mem} */
  wire [31:0] ctrl_addr;  /* Address for external R/W */
  wire [ 1:0] ctrl_size;  /* Nominal size of ctrl transfer */
  wire [31:0] ctrl_data_in;  // Mode in here too? ****
  wire [31:0] ctrl_data_out;  /* Debug read out bus */
  wire        ctrl_wait;  /* Master - not connected */

  wire        ctrl_x_proc_reset;
  wire        ctrl_x_periph_reset;

  wire        ctrl_x_alu_fwd;  /* Slave forwarding enable (default: 1) */
  wire        ctrl_x_mem_fwd;  /* Slave forwarding enable (default: 1) */
  wire        ctrl_x_run;
  wire        ctrl_x_step;
  wire        ctrl_x_busy;
  wire        ctrl_x_broken;
  wire        ctrl_x_we;
  wire        ctrl_x_re;
  wire [ 1:0] ctrl_x_space;
  wire [31:0] ctrl_x_addr;
  wire [ 1:0] ctrl_x_size;
  wire [31:0] ctrl_x_data_wr;
  wire [31:0] ctrl_x_data_rd;
  wire        ctrl_x_wait;

  wire [31:0] pio_pin_in;  /* PIO connections to pad ring */
  wire [31:0] pio_pin_out;  /* Master subsystem */
  wire [31:0] pio_pin_en;

  wire fifo_in_wr, fifo_in_rd, fifo_out_wr, fifo_out_rd;  /* Inter-proc. */
  wire [7:0] fifo_d_out_in, fifo_d_out_out, fifo_d_in_in, fifo_d_in_out;  /*FIFOs*/
  wire fifo_empty_out, fifo_empty_in;
  wire fifo_full_out, fifo_full_in;

  /*----------------------------------------------------------------------------*/
  /* Configuration                                                              */

  wire        ex_forward_en = 1'b1;  /* Enable forwarding from execute stage */
  wire        mem_forward_en = 1'b1;  /* Enable forwarding from memory stage */

  /*----------------------------------------------------------------------------*/
  /* Display/demonstration (only) code                                          */

  reg         disp_loading;  /* Display (only) bus signals */
  wire [31:0] disp_data_address;  /* Data address */
  wire [31:0] disp_data_data_in;  /*  Load data */
  wire [31:0] disp_data_data_out;  /* Store data */

  always @(posedge clk) disp_loading <= data_read;  /* Data returned next cycle */
  assign disp_data_address  = (data_read || data_write) ? data_address : 32'hx;
  assign disp_data_data_in  = (disp_loading) ? data_data_ld : 32'hxxxx_xxxx;
  assign disp_data_data_out = (data_write) ? data_data_st : 32'hxxxx_xxxx;

  /*----------------------------------------------------------------------------*/
  //
  /*============================================================================*/
  /* Top level instantiations                                                   */


  wire locked;  /* Locked o/p from PLL */

  assign reset = !locked;

  clk_wiz_0 clk_mult (
      .clk_out1(clk),          /* 40 MHz system clock */
      .clk_out2(clk_TMDS),     /* 400 MHz TMDS shift clock */
      .clk_in1 (CLK_50MHZ_R),  /* 50 MHz clk in       */
      .locked  (locked)
  );  /* inverted and used for reset */

  assign ctrl_run     = 1'b1;
  assign ctrl_step    = 1'b0;
  assign ctrl_we      = 1'b0;
  assign ctrl_space   = 2'hx;
  assign ctrl_addr    = 32'hxxxx_xxxx;
  assign ctrl_size    = 2'hx;
  assign ctrl_data_in = 32'hxxxx_xxxx;

  assign pio_pin_in   = 32'h0000_0000;  /* Not pinned out at present */

  //
  /*============================================================================*/

  subsystem #(
      .slave(1)
  ) slave_unit (
      .clk     (clk),
      .pixclk  (clk),
      .clk_TMDS(clk_TMDS),

      /** Fine-r grained reset control for debug system */
      .reset            (reset),
      .ctrl_periph_reset(ctrl_x_periph_reset),
      .ctrl_proc_reset  (ctrl_x_proc_reset),

      .ex_forward_en (ctrl_x_alu_fwd),
      .mem_forward_en(ctrl_x_mem_fwd),

      .ctrl_run     (ctrl_x_run),
      .ctrl_step    (ctrl_x_step),
      .ctrl_busy    (ctrl_x_busy),
      .ctrl_broken  (ctrl_x_broken),
      .ctrl_we      (ctrl_x_we),
      .ctrl_re      (ctrl_x_re),
      .ctrl_space   (ctrl_x_space),
      .ctrl_addr    (ctrl_x_addr),
      .ctrl_size    (ctrl_x_size),
      .ctrl_data_in (ctrl_x_data_wr),
      .ctrl_data_out(ctrl_x_data_rd),
      .ctrl_wait    (ctrl_x_wait),

      .fifo_full (fifo_full_out),
      .fifo_wr   (fifo_out_wr),
      .fifo_d_out(fifo_d_out_in),
      .fifo_empty(fifo_empty_in),
      .fifo_rd   (fifo_in_rd),
      .fifo_d_in (fifo_d_in_out),

      .pio_pin_in (pio2_pin_in),   /* PIO connections to pad ring */
      .pio_pin_out(pio2_pin_out),  /* Slave subsystem */
      .pio_pin_en (pio2_pin_en),

      .LED(led),
      .SW (sw),   /* Push-button inputs */

      .lcd_ctrl_o(lcd_ctrl_o),  /* LCD pin interface */
      .lcd_data_o(lcd_data_o),
      .lcd_data_i(lcd_data_i),

      .SRAM_n_CS_o   (SRAM_n_CS_o),
      .SRAM_n_rd_o   (SRAM_n_rd_o),
      .SRAM_n_wr_o   (SRAM_n_wr_o),
      .SRAM_address_o(SRAM_address_o),
      .SRAM_n_bytes_o(SRAM_n_bytes_o),
      .SRAM_n_write_o(SRAM_n_write_o),
      .SRAM_d_in_i   (SRAM_d_in_i),
      .SRAM_d_out_o  (SRAM_d_out_o),

      .pin_fn_o    (pin_fn),     /* PIO pin multiplexer control */
      .pin_LED_o   (pin_LED),    /* LED pin multiplexer control */
      .pin_LCD_o   (pin_LCD),
      .pin_LCD_BL_o(pin_LCD_BL),

      .TMDS_shift_red_o  (TMDS_shift_red_o),
      .TMDS_shift_green_o(TMDS_shift_green_o),
      .TMDS_shift_blue_o (TMDS_shift_blue_o),

      .user_periph_din  (user_periph_din),
      .user_periph_dout (user_periph_dout),
      .user_periph_dir  (user_periph_dir),
      .user_periph_LED_o(user_periph_LED),
      .user_periph_LCD_o(user_periph_LCD_o),
      .user_periph_LCD_i(user_periph_LCD_i)
  );  /* End of subsystem instantiation */

  risc_v processor (
      .clk  (clk),   /* Master */
      .reset(reset),

      .instr_address_o(instr_address),  /* Fetch PC */
      .instr_mode_o   (instr_mode),
      .instr_size_o   (instr_size),
      .instr_read_o   (instr_read),
      .instr_data_i   (instr_data),     /* Instruction bus */
      .instr_wait_i   (instr_wait),     /* Instr memory wait state */
      .instr_abort_i  (instr_abort),    /* Instr memory aborting */

      .data_address_o(data_address),  /* Data bus */
      .data_mode_o   (data_mode),
      .data_size_o   (data_size),     /* Load/store size */
      .data_read_o   (data_read),     /* Load enable */
      .data_write_o  (data_write),    /* Store enable */
      .data_data_i   (data_data_ld),  /* Loaded data */
      .data_data_o   (data_data_st),  /* Store data */
      .data_wait_i   (data_wait),     /* Bus not ready */
      .data_abort_i  (data_abort),
      .stop_i        (1'b0),

      .mtime_i     (mtime),      /* System time */
      .interrupts_i(interrupts),

      .ctrl_run     (ctrl_run),       /* External control signals */
      .ctrl_step    (ctrl_step),
      .ctrl_busy    (ctrl_busy),
      .ctrl_broken  (ctrl_broken),
      .ctrl_we      (ctrl_we),
      .ctrl_space   (ctrl_space),
      .ctrl_addr    (ctrl_addr),
      .ctrl_size    (ctrl_size),
      .ctrl_data_in (ctrl_data_in),
      .ctrl_data_out(ctrl_data_out),  /* Proc. needs no extra waits */
      .ctrl_wait    (),               /* Master: bus not in use */

      .ex_forward_en (ex_forward_en),  /* Configuration inputs */
      .mem_forward_en(mem_forward_en)
  );

  periph #(
      .slave(0)
  ) periph  /* Master peripheral block */
  (
      .clk  (clk),
      .reset(reset),

      .instr_address_i(instr_address),  /* Fetch PC */
      .instr_mode_i   (instr_mode),
      .instr_size_i   (instr_size),
      .instr_read_i   (instr_read),
      .instr_data_o   (instr_data),     /* Instruction bus */
      .instr_wait_o   (instr_wait),     /* Instr memory wait state */
      .instr_abort_o  (instr_abort),    /* Instr memory aborting */

      .data_address_i(data_address),  /* Data bus */
      .data_mode_i   (data_mode),
      .data_size_i   (data_size),
      .data_read_i   (data_read),
      .data_write_i  (data_write),
      .data_data_o   (data_data_ld),
      .data_data_i   (data_data_st),
      .data_wait_o   (data_wait),     /* Data bus not ready this cycle */
      .data_abort_o  (data_abort),

      .mtime     (mtime),      /* System time */
      .mtimer_irq(mtimer_irq),

      .rx_din     (FTDI_TXD),     /* Host serial interface */
      .tx_dout    (FTDI_RXD),
      .pio_pin_in (pio_pin_in),   /* PIO interface (test/debug only) */
      .pio_pin_out(pio_pin_out),
      .pio_pin_en (pio_pin_en),

      .ctrl_x_alu_fwd(ctrl_x_alu_fwd),  /* Slave configuration */
      .ctrl_x_mem_fwd(ctrl_x_mem_fwd),

      .ctrl_x_proc_reset  (ctrl_x_proc_reset),   /* Control/debug to subsystem */
      .ctrl_x_periph_reset(ctrl_x_periph_reset),

      .ctrl_x_run(ctrl_x_run),
      .ctrl_x_step(ctrl_x_step),
      .ctrl_x_busy(ctrl_x_busy),
      .ctrl_x_broken(ctrl_x_broken),
      .ctrl_x_we(ctrl_x_we),
      .ctrl_x_re(ctrl_x_re),
      .ctrl_x_space(ctrl_x_space),
      .ctrl_x_addr(ctrl_x_addr),
      .ctrl_x_size(ctrl_x_size),
      .ctrl_x_data_wr(ctrl_x_data_wr),
      .ctrl_x_data_rd(ctrl_x_data_rd),
      .ctrl_x_wait(ctrl_x_wait),

      .fifo_full (fifo_full_in),    /* 'Serial' subsystem comms. */
      .fifo_wr   (fifo_in_wr),
      .fifo_d_out(fifo_d_in_in),    /* Inbound to FIFO */
      .fifo_empty(fifo_empty_out),
      .fifo_rd   (fifo_out_rd),
      .fifo_d_in (fifo_d_out_out),  /* Outbound from FIFO */

      .interrupts_o(interrupts)
  );  // Interrupt 'controller' wanted @@@



  FIFO #(
      .LENGTH(4),
      .WIDTH (8)
  ) fifo_inward (
      .clk(clk),
      .reset(reset),
      .empty(fifo_empty_in),
      .full(fifo_full_in),
      .writing(fifo_in_wr),
      .in_data(fifo_d_in_in),
      .reading(fifo_in_rd),
      .out_data(fifo_d_in_out)
  );

  FIFO #(
      .LENGTH(4),
      .WIDTH (8)
  ) fifo_outward (
      .clk(clk),
      .reset(reset),
      .empty(fifo_empty_out),
      .full(fifo_full_out),
      .writing(fifo_out_wr),
      .in_data(fifo_d_out_in),
      .reading(fifo_out_rd),
      .out_data(fifo_d_out_out)
  );

endmodule  // top

/*============================================================================*/
//
/*----------------------------------------------------------------------------*/

module subsystem (
    input wire clk,
    input wire pixclk,
    input wire clk_TMDS,

    input wire reset,             /* Global reset       */
    input wire ctrl_proc_reset,   /* Processor reset    */
    input wire ctrl_periph_reset, /* Peripheral reset   */

    input wire ex_forward_en,  /* Forwarding enable */
    input wire mem_forward_en, /* Forwarding enable */

    input  wire        ctrl_run,       /* Fetch can take place */
    input  wire        ctrl_step,      /* Single step */
    output wire        ctrl_busy,      /* Pipeline active */
    output wire        ctrl_broken,    /* Breakpoint encountered */
    input  wire        ctrl_we,        /* Write Enable to slave unit */
    input  wire        ctrl_re,        /* Read Enable to slave unit */
    input  wire [ 1:0] ctrl_space,     /* Slave address space */
    input  wire [31:0] ctrl_addr,      /* Address for external R/W */
    input  wire [ 1:0] ctrl_size,      /* Size of ctrl transfer */
    input  wire [31:0] ctrl_data_in,   /* Debug write bus */
    output wire [31:0] ctrl_data_out,  /* Debug read out bus */
    output wire        ctrl_wait,      /* Access not complete */

    input  wire       fifo_full,   /* FIFO connection to master */
    output wire       fifo_wr,
    output wire [7:0] fifo_d_out,
    input  wire       fifo_empty,
    output wire       fifo_rd,
    input  wire [7:0] fifo_d_in,

    input  wire [31:0] pio_pin_in,   /* PIO connections to pad ring */
    output wire [31:0] pio_pin_out,
    output wire [31:0] pio_pin_en,

    output wire [7:0] LED,  /* LED pin interface */
    input  wire [3:0] SW,   /*      User buttons */

    output wire [3:0] lcd_ctrl_o,  /* LCD pin interface */
    output wire [7:0] lcd_data_o,
    input  wire [7:0] lcd_data_i,

    output wire        SRAM_n_CS_o,
    output wire        SRAM_n_rd_o,
    output wire        SRAM_n_wr_o,     /* Timing strobe */
    output wire [17:0] SRAM_address_o,
    output wire [ 3:0] SRAM_n_bytes_o,
    output wire        SRAM_n_write_o,  /* Data output enable */
    input  wire [31:0] SRAM_d_in_i,
    output wire [31:0] SRAM_d_out_o,

    output wire [31:0] pin_fn_o,     /* Source control for I/O */
    output wire [ 7:0] pin_LED_o,
    output wire        pin_LCD_o,
    output wire        pin_LCD_BL_o,

    output wire TMDS_shift_red_o,
    output wire TMDS_shift_green_o,
    output wire TMDS_shift_blue_o,

    input  wire [31:0] user_periph_din,
    output wire [31:0] user_periph_dout,
    output wire [31:0] user_periph_dir,
    input  wire [ 7:0] user_periph_LCD_i,
    output wire [11:0] user_periph_LCD_o,
    output wire [ 7:0] user_periph_LED_o
);

  parameter slave = 0;  /* Slave subsystem variables */

  wire [31:0] instr_address;  /* Instruction fetch address */
  wire [ 1:0] instr_mode;  /* Instruction fetch mode */
  wire [ 1:0] instr_size;  /* Instruction fetch size (= word) */
  wire        instr_read;  /* Instruction fetch active */
  wire        instr_write;  /* Dummy - for completeness */
  wire [31:0] instr_data;  /* Load data */
  wire        instr_wait;  /* Load data not ready */
  wire [ 2:0] instr_abort;  /* Memory operation abort code */
  wire        instr_read_1;  /* After MMU/abort gating */
  wire        instr_write_1;  /* After MMU/abort gating */

  wire [31:0] data_address;  /* Load/store address bus */
  wire [ 1:0] data_mode;  /* Load/store mode */
  wire [ 1:0] data_size;  /* Load/store size */
  wire        data_read;  /* Load active */
  wire        data_write;  /* Store active */
  wire [31:0] data_data_st;  /* Store data */
  wire [31:0] data_data_ld;  /* Load data */
  wire        data_wait;  /* Load data not ready */
  wire [ 2:0] data_abort;  /* Memory operation abort code */
  wire        data_read_1;  /* After MMU/abort gating */
  wire        data_write_1;  /* After MMU/abort gating */
  wire [31:0] data_address_m;  /* Load/store address bus */
  wire [ 1:0] data_mode_m;  /* Load/store mode */
  wire [ 1:0] data_size_m;  /* Load/store size */
  wire        data_read_m;  /* Load active */
  wire        data_write_m;  /* Store active */
  wire [31:0] data_data_st_m;  /* Store data */
  wire [31:0] data_data_ld_m;  /* Load data */
  wire        data_wait_m;  /* Load data not ready */
  wire [ 2:0] data_abort_m_xx;  /* Memory operation abort code */
  wire [11:0] interrupts;  /* Interrupt inputs */

  wire        stop;

  wire [63:0] mtime;  /* Subsystem time */
  wire        mtimer_irq;  /* Subsystem timer interrupt */
  wire        ext_irq;  /* Subsystem device interrupt (from controller) */

  wire [31:0] ctrl_data_out_p;  /* Data read bus from processor */
  wire [31:0] ctrl_data_out_m;  /* Data read bus from memory interception */
  wire        ctrl_wait_RV;  /* Processor control wait (= 0) */

  assign ctrl_data_out = (ctrl_space == 2'h3) ? ctrl_data_out_m : ctrl_data_out_p;

  wire [7:0] led;
  wire [3:0] sw;

  assign LED = led;
  assign sw  = SW;

  risc_v processor (
      .clk  (clk),                      /* Slave */
      .reset(reset || ctrl_proc_reset),

      .instr_address_o(instr_address),  /* Fetch PC */
      .instr_mode_o   (instr_mode),
      .instr_size_o   (instr_size),
      .instr_read_o   (instr_read),
      .instr_data_i   (instr_data),     /* Instruction bus */
      .instr_wait_i   (instr_wait),     /* Instr memory wait state */
      .instr_abort_i  (instr_abort),    /* Instr memory aborting */

      .data_address_o(data_address),  /* Data bus */
      .data_mode_o   (data_mode),     /* Load/store mode */
      .data_size_o   (data_size),     /* Load/store size */
      .data_read_o   (data_read),     /* Load enable */
      .data_write_o  (data_write),    /* Store enable */
      .data_data_i   (data_data_ld),  /* Loaded data */
      .data_data_o   (data_data_st),  /* Store data */
      .data_wait_i   (data_wait),     /* Bus not ready */
      .data_abort_i  (data_abort),
      .stop_i        (stop),          /* Self stop request */

      .mtime_i      (mtime),                        // @@@       /* Subsystem time */
      .interrupts_i ({ext_irq, interrupts[10:0]}),
      //ext_irq
      .ctrl_run     (ctrl_run),                     /* External control signals */
      .ctrl_step    (ctrl_step),
      .ctrl_busy    (ctrl_busy),
      .ctrl_broken  (ctrl_broken),
      .ctrl_we      (ctrl_we),
      .ctrl_space   (ctrl_space),
      .ctrl_addr    (ctrl_addr),
      .ctrl_size    (ctrl_size),
      .ctrl_data_in (ctrl_data_in),
      .ctrl_data_out(ctrl_data_out_p),              /* Proc. needs no extra waits*/
      .ctrl_wait    (ctrl_wait_RV),                 /* If it could be !=0 would OR in */

      .ex_forward_en (ex_forward_en),  /* Configuration inputs */
      .mem_forward_en(mem_forward_en)
  );

  assign instr_write = 1'b0;  /* No writes on instruction bus */

  mmu #(
      .DATA_BUS(0)
  ) immu (
      .address_i(instr_address),  /* Instruction bus */
      .mode_i   (instr_mode),
      .size_i   (instr_size),
      .read_i   (instr_read),
      .write_i  (instr_write),    /* (Tied inactive) */
      .abort_o  (instr_abort),    /* Instruction memory aborting */
      .read_o   (instr_read_1),
      .write_o  (instr_write_1)
  );

  mmu #(
      .DATA_BUS(1)
  ) dmmu (
      .address_i(data_address),  /* Data bus */
      .mode_i   (data_mode),
      .size_i   (data_size),
      .read_i   (data_read),
      .write_i  (data_write),
      .abort_o  (data_abort),    /* Data memory aborting */
      .read_o   (data_read_1),
      .write_o  (data_write_1)
  );

  mem_if mem_if (
      .clk      (clk),           /* Subsystem (slave) */
      .reset    (reset),
      .address_i(data_address),  /* Data bus */
      .mode_i   (data_mode),     /* Load/store mode */
      .size_i   (data_size),     /* Load/store size */
      .read_i   (data_read_1),   /* Load enable */
      .write_i  (data_write_1),  /* Store enable */
      .data_o   (data_data_ld),  /* Loaded data */
      .data_i   (data_data_st),  /* Store data */
      .wait_o   (data_wait),     /* Bus not ready */
      .abort_o  (),
      //            .abort_o(data_abort),

      .ctrl_run(ctrl_run),  //  ### Not all these signals needed, inside
      .ctrl_step(ctrl_step),
      .ctrl_busy(ctrl_busy),
      .ctrl_we(ctrl_we),
      .ctrl_re(ctrl_re),
      .ctrl_space(ctrl_space),
      .ctrl_addr(ctrl_addr),
      .ctrl_size(ctrl_size),
      .ctrl_data_in(ctrl_data_in),
      .ctrl_data_out(ctrl_data_out_m),
      .ctrl_data_wait(ctrl_wait),

      .address_m_o(data_address_m),  /* Data bus */
      .mode_m_o   (data_mode_m),     /* Load/store mode */
      .size_m_o   (data_size_m),     /* Load/store size */
      .read_m_o   (data_read_m),     /* Load enable */
      .write_m_o  (data_write_m),    /* Store enable */
      .data_m_i   (data_data_ld_m),  /* Loaded data */
      .data_m_o   (data_data_st_m),  /* Store data */
      .wait_m_i   (data_wait_m),     /* Bus not ready */
      .abort_m_i  (data_abort_m_xx)
  );

  periph2 #(
      .slave(slave)
  ) periph  /* Slave peripheral block */
  (
      .clk(clk),
      .pixclk(clk),
      .clk_TMDS(clk_TMDS),
      .reset(reset || ctrl_periph_reset),

      .instr_address_i(instr_address),  /* Fetch PC */
      .instr_mode_i   (instr_mode),
      .instr_size_i   (instr_size),
      .instr_read_i   (instr_read_1),
      .instr_data_o   (instr_data),     /* Instruction bus */
      .instr_wait_o   (instr_wait),     /* Instr memory wait state */
      .instr_abort_o  (),               /* Instr memory aborting */
      //               .instr_abort_o(instr_abort),        /* Instr memory aborting */

      .data_address_i(data_address_m),  /* Data bus */
      .data_mode_i   (data_mode_m),
      .data_size_i   (data_size_m),
      .data_read_i   (data_read_m),
      .data_write_i  (data_write_m),
      .data_data_o   (data_data_ld_m),
      .data_data_i   (data_data_st_m),
      .data_wait_o   (data_wait_m),     /* Data bus not ready this cycle */
      .data_abort_o  (data_abort_m_xx),

      .stop_o(stop),  /* Self stop request */

      .mtime       (mtime),      /* System time */
      .mtimer_irq_o(mtimer_irq),

      .ext_irq_o(ext_irq),  /* Device interrupt(s) */

      .pio_pin_in (pio_pin_in),   /* PIO interface */
      .pio_pin_out(pio_pin_out),
      .pio_pin_en (pio_pin_en),
      .led_pin_o  (led),          /* LED interface */
      .sw_pin_i   (sw),

      .lcd_ctrl_o(lcd_ctrl_o),  /* LCD pin interface */
      .lcd_data_o(lcd_data_o),
      .lcd_data_i(lcd_data_i),

      .pin_fn_o    (pin_fn_o),
      .pin_LED_o   (pin_LED_o),
      .pin_LCD_o   (pin_LCD_o),
      .pin_LCD_BL_o(pin_LCD_BL_o),

      .fifo_full(fifo_full),
      .fifo_wr(fifo_wr),
      .fifo_d_out(fifo_d_out),
      .fifo_empty(fifo_empty),
      .fifo_rd(fifo_rd),
      .fifo_d_in(fifo_d_in),

      .TMDS_shift_red_o  (TMDS_shift_red_o),
      .TMDS_shift_green_o(TMDS_shift_green_o),
      .TMDS_shift_blue_o (TMDS_shift_blue_o),

      .SRAM_n_CS_o   (SRAM_n_CS_o),
      .SRAM_n_rd_o   (SRAM_n_rd_o),
      .SRAM_n_wr_o   (SRAM_n_wr_o),
      .SRAM_address_o(SRAM_address_o),
      .SRAM_n_bytes_o(SRAM_n_bytes_o),
      .SRAM_n_write_o(SRAM_n_write_o),
      .SRAM_d_in_i   (SRAM_d_in_i),
      .SRAM_d_out_o  (SRAM_d_out_o),

      .interrupts_o(interrupts),  // Interrupt 'controller' wanted @@@

      .user_periph_din  (user_periph_din),
      .user_periph_dout (user_periph_dout),
      .user_periph_dir  (user_periph_dir),
      .user_periph_LED_o(user_periph_LED_o),
      .user_periph_LCD_i(user_periph_LCD_i),
      .user_periph_LCD_o(user_periph_LCD_o),
      .user_periph_SW_i (SW)
  );

endmodule  // subsystem

/*============================================================================*/
//
/*============================================================================*/

module mem_if (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] address_i,  /* Data bus: processor side */
    input  wire [ 1:0] mode_i,
    input  wire [ 1:0] size_i,
    input  wire        read_i,
    input  wire        write_i,
    output wire [31:0] data_o,     /* Data load bus */
    input  wire [31:0] data_i,     /* Data store bus */
    output wire        wait_o,     /* Data memory wait state */
    output wire [ 2:0] abort_o,    /* Data memory aborting */

    input  wire        ctrl_run,       /* Instruction fetch can take place */
    input  wire        ctrl_step,      /* Pulse to step/continue */
    input  wire        ctrl_busy,      /* Active ops. in the pipeline */
    input  wire        ctrl_we,        /* Write Enable to slave unit */
    input  wire        ctrl_re,        /* Read Enable to slave unit */
    input  wire [ 1:0] ctrl_space,     /* Addr. space for external ctrl */
    input  wire [31:0] ctrl_addr,      /* Address for external R/W */
    input  wire [ 1:0] ctrl_size,      /* Nominal size of ctrl transfer */
    input  wire [31:0] ctrl_data_in,
    output wire [31:0] ctrl_data_out,  /* Debug read out bus */
    output reg         ctrl_data_wait,

    output wire [31:0] address_m_o,  /* Data bus: memory side */
    output wire [ 1:0] mode_m_o,
    output wire [ 1:0] size_m_o,
    output wire        read_m_o,
    output wire        write_m_o,
    input  wire [31:0] data_m_i,     /* Data load bus */
    output wire [31:0] data_m_o,     /* Data store bus */
    input  wire        wait_m_i,     /* Data memory wait state */
    input  wire [ 2:0] abort_m_i
);  /* Data memory aborting */

  reg  [31:0] ctrl_store_data;
  wire        ctrl_acc;
  reg         ctrl_acc_L;
  assign ctrl_acc = ctrl_we || ctrl_re;
  always @(posedge clk) ctrl_acc_L <= ctrl_acc && !ctrl_acc_L;

  always @(*) ctrl_store_data = ctrl_data_in;

  // Working point @@@ ### @@@
  // This needs muxes finishing and WE (& data) appropriately stabilising
  // around potential wait states
  // Feedback on ctrl_busy if/when waiting for cycle completion  @@@
  reg wait_L;

  always @(posedge clk) wait_L <= wait_m_i;

  //always @ (*) ctrl_data_wait = (ctrl_acc && !ctrl_acc_L) || (!ctrl_busy && ctrl_acc && (ctrl_space == 2'h3) && wait_L); // ??????
  always @(*) ctrl_data_wait = !ctrl_busy && ctrl_acc && wait_m_i;
  // Needs expanding to allow for external wait states too. @@@ 

  assign address_m_o   = ctrl_busy ? address_i : ctrl_addr;
  assign mode_m_o      = mode_i;  // More mux-ing here ###
  assign size_m_o      = ctrl_busy ? size_i : ctrl_size;
  assign read_m_o      = ctrl_busy ? read_i : ctrl_re && (ctrl_space == 2'h3);
  assign write_m_o     = ctrl_busy ? write_i : ctrl_we && (ctrl_space == 2'h3);
  assign data_o        = data_m_i;  /* Data load bus */
  assign data_m_o      = ctrl_busy ? data_i : ctrl_store_data;  /* Data store bus */
  assign wait_o        = wait_m_i;  /* Data memory wait state */
  assign abort_o       = ctrl_busy && abort_m_i;  /* Data memory aborting */
  /* Gate off abort since it can signal in ctrl_*, causing branch, causing step */

  assign ctrl_data_out = data_m_i;  /* Read data just taps bus */

endmodule  // mem_if

/*----------------------------------------------------------------------------*/
//
/*============================================================================*/
// Master Peripherals 

module periph (
    input wire clk,
    input wire reset,

    input  wire [31:0] instr_address_i,  /* Instruction bus */
    input  wire [ 1:0] instr_mode_i,
    input  wire [ 1:0] instr_size_i,
    input  wire        instr_read_i,
    output wire [31:0] instr_data_o,     /* Instr input bus */
    output wire        instr_wait_o,     /* Instr memory wait state */
    output wire [ 2:0] instr_abort_o,    /* Instr memory aborting */

    input  wire [31:0] data_address_i,  /* Data bus */
    input  wire [ 1:0] data_mode_i,
    input  wire [ 1:0] data_size_i,
    input  wire        data_read_i,
    input  wire        data_write_i,
    input  wire [31:0] data_data_i,     /* Data input bus */
    output wire [31:0] data_data_o,     /* Data output bus */
    output wire        data_wait_o,     /* Data memory wait state */
    output wire [ 2:0] data_abort_o,    /* Data memory aborting */

    output wire [63:0] mtime,      /* Master system time (to processor) */
    output wire        mtimer_irq,

    input  wire rx_din,  /* Serial line to host */
    output wire tx_dout,

    input  wire [31:0] pio_pin_in,   /* Master PIO (redundant?) */
    output wire [31:0] pio_pin_out,
    output wire [31:0] pio_pin_en,

    output wire ctrl_x_alu_fwd,  /* Slave configuration */
    output wire ctrl_x_mem_fwd,  /* Slave configuration */

    output wire        ctrl_x_proc_reset,    /* Slave control bus */
    output wire        ctrl_x_periph_reset,  /* Full subsystem reset */
    output wire        ctrl_x_run,
    output wire        ctrl_x_step,
    input  wire        ctrl_x_busy,
    input  wire        ctrl_x_broken,
    output wire        ctrl_x_we,
    output wire        ctrl_x_re,
    output wire [ 1:0] ctrl_x_space,
    output wire [31:0] ctrl_x_addr,
    output wire [ 1:0] ctrl_x_size,
    output wire [31:0] ctrl_x_data_wr,
    input  wire [31:0] ctrl_x_data_rd,
    input  wire        ctrl_x_wait,

    input  wire        fifo_full,
    output wire        fifo_wr,
    output wire [ 7:0] fifo_d_out,
    input  wire        fifo_empty,
    output wire        fifo_rd,
    input  wire [ 7:0] fifo_d_in,
    output wire [11:0] interrupts_o
);  /*            */

  parameter slave = 0;

  wire        instr_wait;
  wire        data_wait_y;

  wire        cs_imem;  /* periph' variables */
  wire        cs_dmem;
  wire        cs_uart;
  wire        cs_pio;
  wire        cs_timer;
  wire        cs_io;
  wire        cs_ints;
  wire        data_wait_mem;  /* Load data not ready */
  wire        data_wait_uart;  /* Load data not ready */
  wire        data_wait_pio;  /* Load data not ready */
  wire        data_wait_timer;  /* Load data not ready */
  wire        data_wait_io;  /* Load data not ready */
  wire        data_wait_ints;  /* Load data not ready */
  wire [ 2:0] decoder_abort_v;  /*  Abort vector from data decoder */
  wire [ 2:0] mem_abort_v;  /* Abort vector from data memory */
  wire [ 2:0] uart_abort_v;  /* Abort vector from UART */
  wire [ 2:0] pio_abort_v;  /* Abort vector from PIO */
  wire [ 2:0] timer_abort_v;  /* Abort vector from timer */
  wire [ 2:0] io_abort_v;  /* Abort vector from IO */
  wire [ 2:0] ints_abort_v;  /* Abort vector from interrupt controller */

  wire [31:0] data_data_mem;  /* Load data from memory */
  wire [31:0] data_data_uart;  /* Load data from UART */
  wire [31:0] data_data_pio;  /* Load data from PIO */
  wire [31:0] data_data_io;  /* Load data from I/O */
  wire [31:0] data_data_timer;  /* Load data from timer */
  wire [31:0] data_data_ints;  /* Load data from interrupt controller */

  wire        instr_write;  /* Dummy - for completeness */
  wire [31:0] instr_data_in;  /* Dummy - imem write bus */
  assign instr_write   = 1'b0;
  assign instr_data_in = 32'hxxxx_xxxx;

  wire        uart_ireq_rx;  /* Master's interrupt requests */
  wire        uart_ireq_tx;
  wire        uart_ireq_err;
  wire        timer_ireq;
  // + FIFO interrupts (x2) - any others? @@@

  wire [31:0] mm_io;  /* Various test control bits */

  wire        instr_allow;
  wire        data_allow;

  assign instr_allow = (instr_abort_o == `ABORT_NONE);
  assign data_allow  = (data_abort_o == `ABORT_NONE);

  wire instr_read_ok = instr_read_i && instr_allow;
  wire instr_write_ok = 1'b0;
  wire data_read_ok = data_read_i && data_allow;
  wire data_write_ok = data_write_i && data_allow;

  // periph
  idec instr_decoder (
      .address_i      (instr_address_i),  /* Master */
      .mode_i         (instr_mode_i),
      .size_i         (instr_size_i),
      .read_i         (instr_read_i),
      .cs_memory_o    (cs_imem),
      .decoder_abort_o(instr_abort_o)
  );

  decoder data_decoder (
      .address_i        (data_address_i),  /* Master */
      .mode_i           (data_mode_i),
      .size_i           (data_size_i),
      .read_i           (data_read_i),
      .write_i          (data_write_i),
      .cs_memory_o      (cs_dmem),
      .cs_uart_o        (cs_uart),
      .cs_pio_o         (cs_pio),
      .cs_mm_io_o       (cs_io),
      .cs_timer_o       (cs_timer),
      .cs_ints_o        (cs_ints),
      .decoder_abort_v_o(decoder_abort_v)
  );
  // Faults here reconciled with unit aborts

  // Parameterise data width & instantiate for all return signals @@@
  data_mux data_mux (
      .clk      (clk),              /* Master */
      .ready_i  (data_read_ok),
      .address_i(data_address_i),
      .memory_i (data_data_mem),
      .uart_i   (data_data_uart),
      .pio_i    (data_data_pio),
      .mm_io_i  (data_data_io),
      .timer_i  (data_data_timer),
      .ints_i   (data_data_ints),
      .data_o   (data_data_o)
  );

  /* Wait signals only active if selected => OR is sufficient.                  */
  assign data_wait_o = data_wait_mem || data_wait_uart  || data_wait_pio
                  || data_wait_io  || data_wait_timer || data_wait_ints;

  data_abort abort (
      .read_i         (data_read_i),      /* Master */
      .write_i        (data_write_i),
      .decoder_abort_v(decoder_abort_v),  /* These are vectors */
      .mem_abort_v    (mem_abort_v),
      .uart_abort_v   (uart_abort_v),
      .pio_abort_v    (pio_abort_v),
      .timer_abort_v  (timer_abort_v),
      .io_abort_v     (io_abort_v),
      .ints_abort_v   (ints_abort_v),
      .abort_o        (data_abort_o)
  );  /* Output is encoded */

  // periph
  dp_mem #(
      .slave(slave)
  ) ID_memory  /* Master dual port RAM */
  (
      .clk            (clk),
      .reset          (reset),
      .cs_imem_i      (cs_imem),          /* Memory select (decode)  */
      .instr_read_i   (instr_read_ok),    /* Instruction_read        */
      .instr_write_i  (instr_write_ok),   /* Dummy - no instr. write */
      .instr_address_i(instr_address_i),  /* Instruction address     */
      .instr_size_i   (instr_size_i),     /* Instruction size        */
      .instr_data_i   (instr_data_in),    /* Dummy - no instr. write */
      .instr_data_o   (instr_data_o),     /* Instruction             */

      .cs_dmem_i      (cs_dmem),         /* Memory select (decode)  */
      .data_read_i    (data_read_ok),    /* Data_read               */
      .data_write_i   (data_write_ok),   /* Data_write              */
      .data_address_i (data_address_i),  /* Data_address            */
      .data_size_i    (data_size_i),     /* Data size               */
      .data_data_st_i (data_data_i),     /* Data_data_st            */
      .data_data_mem_o(data_data_mem)
  );  /* To data multiplexer     */

  assign mem_abort_v = 3'h0;  // @@@ Replacement: vector @@@

  uart #(
      .CLOCK_FREQ(`CLOCK_FREQUENCY),
      .BAUD      (`BAUD_RATE)
  ) uart (
      .clk      (clk),             /* Genuine UART used by master for host communiation */
      .reset    (reset),
      .cs_i     (cs_uart),
      .read_i   (data_read_ok),
      .write_i  (data_write_ok),
      .address_i(data_address_i),
      .mode_i   (data_mode_i),
      .size_i   (data_size_i),
      .stall_o  (data_wait_uart),
      .abort_v_o(uart_abort_v),
      .data_in  (data_data_i),
      .data_out (data_data_uart),  /* Bus multiplexed to processor */
      .int_rx   (uart_ireq_rx),    /* Interrupt signals */
      .int_tx   (uart_ireq_tx),
      .int_error(uart_ireq_err),
      .rx_din   (rx_din),
      .tx_dout  (tx_dout)
  );

  pio pio (
      .clk      (clk),             /* Master PIO - now somewhat superfluous */
      .reset    (reset),
      .cs_i     (cs_pio),
      .read_i   (data_read_ok),
      .write_i  (data_write_ok),
      .address_i(data_address_i),
      .mode_i   (data_mode_i),
      .size_i   (data_size_i),
      .stall_o  (data_wait_pio),
      .abort_v_o(pio_abort_v),
      .data_in  (data_data_i),
      .data_out (data_data_pio),   /* Bus multiplexed to processor */
      .pin_in   (pio_pin_in),
      .pin_out  (pio_pin_out),
      .pin_en   (pio_pin_en)
  );

  timer timer (
      .clk      (clk),              /* Master timer */
      .reset    (reset),
      .cs_i     (cs_timer),
      .read_i   (data_read_ok),
      .write_i  (data_write_ok),
      .address_i(data_address_i),
      .mode_i   (data_mode_i),
      .size_i   (data_size_i),
      .stall_o  (data_wait_timer),
      .abort_v_o(timer_abort_v),
      .data_in  (data_data_i),
      .data_out (data_data_timer),  /* Bus multiplexed to processor */
      .ireq_o   (timer_ireq)
  );

  io io (
      .clk      (clk),             /* General collection of master IO */
      .reset    (reset),
      .cs_i     (cs_io),
      .read_i   (data_read_ok),
      .write_i  (data_write_ok),
      .address_i(data_address_i),
      .mode_i   (data_mode_i),
      .size_i   (data_size_i),
      .stall_o  (data_wait_io),
      .abort_v_o(io_abort_v),
      .data_in  (data_data_i),
      .data_out (data_data_io),

      .mtime     (mtime),      /* RISC-V timer */
      .mtimer_irq(mtimer_irq),

      .ctrl_x_alu_fwd(ctrl_x_alu_fwd),
      .ctrl_x_mem_fwd(ctrl_x_mem_fwd),

      .ctrl_x_periph_reset(ctrl_x_periph_reset),
      .ctrl_x_proc_reset  (ctrl_x_proc_reset),
      .ctrl_x_run         (ctrl_x_run),
      .ctrl_x_step        (ctrl_x_step),
      .ctrl_x_busy        (ctrl_x_busy),
      .ctrl_x_broken      (ctrl_x_broken),
      .ctrl_x_we          (ctrl_x_we),
      .ctrl_x_re          (ctrl_x_re),
      .ctrl_x_space       (ctrl_x_space),
      .ctrl_x_addr        (ctrl_x_addr),
      .ctrl_x_size        (ctrl_x_size),
      .ctrl_x_data_wr     (ctrl_x_data_wr),
      .ctrl_x_data_rd     (ctrl_x_data_rd),
      .ctrl_x_wait        (ctrl_x_wait),

      .fifo_full (fifo_full),   /* 'serial' comms. to slave system */
      .fifo_wr   (fifo_wr),
      .fifo_d_out(fifo_d_out),
      .fifo_empty(fifo_empty),
      .fifo_rd   (fifo_rd),
      .fifo_d_in (fifo_d_in),
      .io_out    (mm_io)
  );  // Temp. memory mapped I/O @@@

  assign interrupts_o = {{12{timer_ireq}}};

  interrupt_ctrl int_ctrl (
      .clk(clk),
      .reset(reset),
      .cs_i(cs_ints),
      .read_i(data_read_ok),
      .write_i(data_write_ok),
      .address_i(data_address_i),
      .mode_i(data_mode_i),
      .size_i(data_size_i),
      .stall_o(data_wait_ints),
      .abort_v_o(ints_abort_v),
      .data_in(data_data_i),
      .data_out(data_data_ints),  /* Bus muxed to processor */
      .ireq_i({16'h0000, timer_ireq, uart_ireq_err, uart_ireq_tx, uart_ireq_rx, mm_io[11:0]}),
      .ireq_o(ireq_o)
  );  /* Interrupt to CPU */

  mem_wait mem_wait (
      .clk         (clk),         /* Wait state generator for test stress */
      .reset       (reset),
      .stall_imem_o(instr_wait),
      .stall_dmem_o(data_wait_y)
  );

  assign instr_wait_o  = instr_wait && instr_allow;  /* Don't wait for aborts */
  assign data_wait_mem = data_wait_y && data_allow;

  wire disp_cycle;  /* Simulation debug display: for removal */
  wire disp_cs_m, disp_cs_u, disp_cs_i, disp_cs_p, disp_cs_t, disp_cs_j;

  assign disp_cycle = (data_read_i || data_write_i);
  assign disp_cs_m  = cs_dmem && disp_cycle;
  assign disp_cs_u  = cs_uart && disp_cycle;
  assign disp_cs_i  = cs_io && disp_cycle;
  assign disp_cs_p  = cs_pio && disp_cycle;
  assign disp_cs_t  = cs_timer && disp_cycle;
  assign disp_cs_j  = cs_ints && disp_cycle;

endmodule  // periph

/*----------------------------------------------------------------------------*/
//
/*----------------------------------------------------------------------------*/
/* Slave subsystem collection of memory and peripherals                       */

module periph2 (
    input wire clk,
    input wire pixclk,
    input wire clk_TMDS,
    input wire reset,

    input  wire [31:0] instr_address_i,  /* Instruction bus */
    input  wire [ 1:0] instr_mode_i,
    input  wire [ 1:0] instr_size_i,
    input  wire        instr_read_i,
    output wire [31:0] instr_data_o,     /* Instruction input bus */
    output wire        instr_wait_o,     /* Instr memory wait state */
    output wire [ 2:0] instr_abort_o,    /* Instr memory aborting */

    input  wire [31:0] data_address_i,  /* Data bus */
    input  wire [ 1:0] data_mode_i,
    input  wire [ 1:0] data_size_i,
    input  wire        data_read_i,
    input  wire        data_write_i,
    input  wire [31:0] data_data_i,     /* Data input bus */
    output wire [31:0] data_data_o,     /* Data output bus */
    output wire        data_wait_o,     /* Data memory wait state */
    output wire [ 2:0] data_abort_o,    /* Data memory aborting */
    output wire        stop_o,          /* Self-stop request */

    output wire [63:0] mtime,         /* Output from control to proc. CSR */
    output wire        mtimer_irq_o,  /* RV32 TIME interrupt request */
    output wire        ext_irq_o,     /* RV32 device interrupt request(s)*/

    input  wire [31:0] pio_pin_in,   /* User's PIO to/from pins */
    output wire [31:0] pio_pin_out,
    output wire [31:0] pio_pin_en,

    output wire [7:0] led_pin_o,  /* LED pin interface */
    input  wire [3:0] sw_pin_i,

    output wire [3:0] lcd_ctrl_o,  /* LCD pin interface */
    output wire [7:0] lcd_data_o,
    input  wire [7:0] lcd_data_i,

    output wire [31:0] pin_fn_o,  /* Pin alternative function selects */
    output wire [7:0] pin_LED_o,  /* Pin alternative func. selects */
    output wire pin_LCD_o,
    output wire pin_LCD_BL_o,

    input  wire       fifo_full,   /* 'Serial' comms. to/from master */
    output wire       fifo_wr,
    output wire [7:0] fifo_d_out,
    input  wire       fifo_empty,
    output wire       fifo_rd,
    input  wire [7:0] fifo_d_in,

    output wire        SRAM_n_CS_o,
    output wire        SRAM_n_rd_o,
    output wire        SRAM_n_wr_o,     /* Timing strobe */
    output wire [17:0] SRAM_address_o,
    output wire [ 3:0] SRAM_n_bytes_o,
    output wire        SRAM_n_write_o,  /* Data output enable */
    input  wire [31:0] SRAM_d_in_i,
    output wire [31:0] SRAM_d_out_o,

    output wire [11:0] interrupts_o,  /*            */

    output wire TMDS_shift_blue_o,
    output wire TMDS_shift_green_o,
    output wire TMDS_shift_red_o,

    input  wire [31:0] user_periph_din,
    output wire [31:0] user_periph_dout,
    output wire [31:0] user_periph_dir,

    output wire [ 7:0] user_periph_LED_o,
    input  wire [ 7:0] user_periph_LCD_i,
    output wire [11:0] user_periph_LCD_o,
    input  wire [ 3:0] user_periph_SW_i
);

  parameter slave = 0;

  wire instr_wait;
  wire data_wait_x;
  /* Subunit selects */
  wire cs_imem_m, cs_dmem_m;  /* Machine space memory selects */
  wire cs_imem_u, cs_dmem_u;  /* User space memory selects */
  wire        cs_led;  /* Peripheral device selects */
  wire        cs_lcd;
  wire        cs_timer;
  wire        cs_pio;
  wire        cs_ints;
  wire        cs_fifo;
  wire        cs_vduc;
  wire        cs_drawing;
  wire        cs_ctrl;
  wire        cs_periphu;  /* Select for user peripheral region */
  wire        cs_SRAM;
  wire        data_wait_mem;  /* Load data not ready - memory */
  wire        data_wait_led;  /* Load data not ready from peripherals */
  wire        data_wait_lcd;  /* (largely/entirely inactive) */
  wire        data_wait_timer;
  wire        data_wait_pio;
  wire        data_wait_ints;
  wire        data_wait_fifo;
  wire        data_wait_vduc;
  wire        data_wait_DE;
  wire        data_wait_ctl;
  wire        SRAM_wait;
  wire        data_wait;
  wire [ 2:0] decoder_abort_v;  /*  Abort vector from data decoder */
  wire [ 2:0] mem_abort_v;  /* Abort vector from data memory */
  wire [ 2:0] led_abort_v;  /* Abort vector from LED PIO */
  wire [ 2:0] lcd_abort_v;  /* Abort vector from LCD PIO */
  wire [ 2:0] timer_abort_v;  /* Abort vector from timer */
  wire [ 2:0] pio_abort_v;  /* Abort vector from PIO */
  wire [ 2:0] ints_abort_v;  /* Abort vector from interrupt controller */
  wire [ 2:0] fifo_abort_v;  /* Abort vector from IO */
  wire [ 2:0] vduc_abort_v;  /* Abort vector from video controller */
  wire [ 2:0] DE_abort_v;  /* Abort vector from drawing engine */
  wire [ 2:0] ctrl_abort_v;  /* Abort vector from internal controller */

  wire [31:0] instr_data_m;  /* Instruction fetched from 'machine' memory */
  wire [31:0] instr_data_u;  /* Instruction fetched from 'user' memory */

  wire [31:0] data_data_mem_m;  /* Load data from 'machine' memory */
  wire [31:0] data_data_mem_u;  /* Load data from 'user' memory */
  wire [31:0] data_data_periph;  /* Load data from peripherals to next mux. */
  wire [31:0] data_data_led;  /* Load data from LED PIO */
  wire [31:0] data_data_lcd;  /* Load data from LCD PIO */
  wire [31:0] data_data_timer;  /* Load data from timer */
  wire [31:0] data_data_pio;  /* Load data from PIO */
  wire [31:0] data_data_ints;  /* Load data from interrupt controller */
  wire [31:0] data_data_fifo;  /* Load data from I/O */
  wire [31:0] data_data_vdu;  /* Load data from VDU controller */
  wire [31:0] data_data_DE;  /* Load data from drawing engine */
  wire [31:0] data_data_ctrl;  /* Load data from misc. control */

  wire [31:0] data_data_periphu;  /* Load data from user peripherals */
  wire [31:0] data_data_SRAM;  /* Load data from external SRAM */

  wire        data_VDUC_read;  /* Bus from VDUC to FS multiplexer */
  wire        data_VDUC_wait;
  wire [17:0] data_VDUC_addr;
  wire [31:0] data_VDUC_data;

  wire        data_DE_req;  /* Bus fron drawing accelerator to FS mux. */
  wire        data_DE_RnW;
  wire [ 3:0] data_DE_nbyte;
  wire        data_DE_ack;
  wire [17:0] data_DE_address;
  wire [31:0] data_DE_wr_data;
  wire [31:0] data_DE_rd_data;
  /*
wire        data_DE_read  = 1'b0;
wire        data_DE_write = 1'b0;
wire        data_DE_wait;
wire        data_DE_size  = 2'b1;  
*/
  wire        instr_write;  /* Dummy - for completeness */
  wire [31:0] instr_data_in;  /* Dummy - imem data write bus */
  assign instr_write   = 1'b0;  /* Tied off */
  assign instr_data_in = 32'hxxxx_xxxx;  /* Who cares?  Not there really! */

  wire        timer_ireq;  /* Peripheral interrupts to interrupt controller */
  wire        fifo_Tx_ireq;
  wire        fifo_Rx_ireq;
  wire        fifo_overrun;
  wire [ 1:0] vdu_ireq;
  wire [ 2:0] serial_ints;
  wire [ 1:0] DE_ireq;
  wire [ 3:0] user_irq;

  wire        instr_allow;
  wire        data_allow;

  wire        instr_read_ok = instr_read_i && instr_allow;
  wire        instr_write_ok = 1'b0;
  wire        data_read_ok = data_read_i && data_allow;
  wire        data_write_ok = data_write_i && data_allow;

  wire [ 9:0] screen_width;  /* Display definitions */
  wire [ 9:0] screen_height;  /* Exported to drawing accelerator */
  wire [ 1:0] screen_mode;
  wire [17:0] screen_frame;

  assign instr_allow = (instr_abort_o == `ABORT_NONE);
  assign data_allow  = (data_abort_o == `ABORT_NONE);

  idec2 instr_decoder (
      .address_i      (instr_address_i),
      .mode_i         (instr_mode_i),
      .size_i         (instr_size_i),
      .read_i         (instr_read_i),
      .cs_memory_m_o  (cs_imem_m),
      .cs_memory_u_o  (cs_imem_u),
      .decoder_abort_o(instr_abort_o)
  );

  decoder2 data_decoder (
      .address_i    (data_address_i),
      .mode_i       (data_mode_i),
      .size_i       (data_size_i),
      .read_i       (data_read_i),
      .write_i      (data_write_i),
      .cs_memory_m_o(cs_dmem_m),
      .cs_memory_u_o(cs_dmem_u),
      .cs_led_pio_o (cs_led),
      .cs_lcd_pio_o (cs_lcd),
      .cs_timer_o   (cs_timer),
      .cs_pio_o     (cs_pio),
      .cs_ints_o    (cs_ints),
      .cs_fifo_o    (cs_fifo),
      .cs_vduc_o    (cs_vduc),
      .cs_drawing_o (cs_drawing),
      .cs_ctrl_o    (cs_ctrl),
      .cs_periphu_o (cs_periphu),
      .cs_SRAM_o    (cs_SRAM),

      .decoder_abort_v_o(decoder_abort_v)
  );
  // Faults here reconciled with unit aborts

  instr_mux instr_mux (
      .clk       (clk),              /* Return data multiplexer */
      .ready_i   (instr_read_ok),
      .address_i (instr_address_i),
      .memory_m_i(instr_data_m),
      .memory_u_i(instr_data_u),
      .data_o    (instr_data_o)
  );

  // Parameterise data width & instantiate for all return signals @@@
  data_mux2 data_mux (
      .clk       (clk),
      .ready_i   (data_read_ok),       /* Read proceeding */
      .address_i (data_address_i),
      .memory_m_i(data_data_mem_m),    /* Data from Machine memory */
      .memory_u_i(data_data_mem_u),    /* Data from User memory */
      .periph_i  (data_data_periph),   /* Sys. peripheral set data */
      .user_i    (data_data_periphu),  /*User peripheral set data */
      .SRAM_i    (data_data_SRAM),     /* SRAM read data */
      .data_o    (data_data_o)
  );  /* Data back to processor */

  assign data_wait_x = data_wait || data_wait_mem || SRAM_wait;
  // Temporary! @@@ (quick hack)
  //assign data_wait_x = 0; //data_wait_mem || SRAM_wait;


  data_mux2a data_mux2a (
      .clk              (clk),              /* Mux. for (internal) peripheral data */
      .ready_i          (data_read_ok),     /* Read proceeding */
      .address_i        (data_address_i),
      .data_data_led_i  (data_data_led),
      .data_data_lcd_i  (data_data_lcd),
      .data_data_timer_i(data_data_timer),
      .data_data_pio_i  (data_data_pio),
      .data_data_ints_i (data_data_ints),
      .data_data_fifo_i (data_data_fifo),
      .data_data_vdu_i  (data_data_vdu),
      .data_data_ctrl_i (data_data_ctrl),
      .data_data_DE_i   (data_data_DE),

      .data_wait_led_i  (data_wait_led),
      .data_wait_lcd_i  (data_wait_lcd),
      .data_wait_timer_i(data_wait_timer),
      .data_wait_pio_i  (data_wait_pio),
      .data_wait_ints_i (data_wait_ints),
      .data_wait_fifo_i (data_wait_fifo),
      .data_wait_vduc_i (data_wait_vduc),
      .data_wait_ctl_i  (data_wait_ctl),
      .data_wait_DE_i   (data_wait_DE),

      .data_periph_o(data_data_periph),
      .data_wait_o  (data_wait)
  );

  ///* Wait signals only active if selected => OR is sufficient.                  */
  //assign data_wait_o = data_wait_mem   || data_wait_led || data_wait_lcd
  //                  || data_wait_timer || data_wait_pio || data_wait_ints
  ////   || data_wait_fifo 
  //                  || data_wait_vduc
  //                  || data_wait_fifo    || data_wait_ctl;

  data_abort2 abort (
      .read_i         (data_read_i),
      .write_i        (data_write_i),
      .decoder_abort_v(decoder_abort_v),  /* These are vectors */
      .mem_abort_v    (mem_abort_v),
      .led_abort_v    (led_abort_v),
      .lcd_abort_v    (lcd_abort_v),
      .timer_abort_v  (timer_abort_v),
      .pio_abort_v    (pio_abort_v),
      .ints_abort_v   (ints_abort_v),
      .fifo_abort_v   (3'b000),
      .vduc_abort_v   (vduc_abort_v),
      .ctrl_abort_v   (ctrl_abort_v),
      .DE_abort_v     (DE_abort_v),
      //               .abort_o(            ));                /* Output is encoded */
      .abort_o        (data_abort_o)
  );  /* Output is encoded */

  dp_mem2 #(
      .slave(slave)
  ) ID_memory_m  /* Dual port RAM */
  (
      .clk            (clk),
      .reset          (reset),
      .cs_imem_i      (cs_imem_m),
      .instr_read_i   (instr_read_ok),               /* Instruction_read */
      .instr_write_i  (instr_write && !instr_wait),  /* Dummy */
      .instr_address_i(instr_address_i),             /* Instruction_address */
      .instr_size_i   (instr_size_i),                /* Instruction_size */
      .instr_data_i   (instr_data_in),               /* Dummy */
      .instr_data_o   (instr_data_m),                /* Instruction */

      .cs_dmem_i      (cs_dmem_m),
      .data_read_i    (data_read_ok),    /* Data_read */
      .data_write_i   (data_write_ok),   /* Data_write */
      .data_address_i (data_address_i),  /* Data_address */
      .data_size_i    (data_size_i),     /* Data_size */
      .data_data_st_i (data_data_i),     /* Data_data_st */
      .data_data_mem_o(data_data_mem_m)
  );  /* To data multiplexer */

  assign mem_abort_v = 3'h0;  // @@@ Replacement: vector @@@

  dp_mem3 #(
      .slave(slave)
  ) ID_memory_u  /* Dual port RAM */
  (
      .clk            (clk),
      .reset          (reset),
      .cs_imem_i      (cs_imem_u),
      .instr_read_i   (instr_read_ok),               /* Instruction read */
      .instr_write_i  (instr_write && !instr_wait),  /* Dummy */
      .instr_address_i(instr_address_i),             /* Instruction_address */
      .instr_size_i   (instr_size_i),                /* Instruction size */
      .instr_data_i   (instr_data_in),               /* Dummy */
      .instr_data_o   (instr_data_u),                /* Instruction */

      .cs_dmem_i      (cs_dmem_u),
      .data_read_i    (data_read_ok),    /* Data_read */
      .data_write_i   (data_write_ok),   /* Data_write */
      .data_address_i (data_address_i),  /* Data_address */
      .data_size_i    (data_size_i),     /* Data_size */
      .data_data_st_i (data_data_i),     /* Data store data */
      .data_data_mem_o(data_data_mem_u)
  );  /* Data o/p (to multiplexer) */

  assign mem_abort_v = 3'h0;  // @@@ Replacement: vector @@@

  pio pio (
      .clk      (clk),
      .reset    (reset),
      .cs_i     (cs_pio),
      .read_i   (data_read_ok),
      .write_i  (data_write_ok),
      .address_i(data_address_i),
      .mode_i   (data_mode_i),
      .size_i   (data_size_i),
      .stall_o  (data_wait_pio),
      .abort_v_o(pio_abort_v),
      .data_in  (data_data_i),
      .data_out (data_data_pio),   /* Bus multiplexed to processor */
      .pin_in   (pio_pin_in),
      .pin_out  (pio_pin_out),
      .pin_en   (pio_pin_en)
  );

  led_pio led_pio (
      .clk      (clk),             /* Specific interface for LEDs & buttons */
      .reset    (reset),
      .cs_i     (cs_led),
      .read_i   (data_read_ok),
      .write_i  (data_write_ok),
      .address_i(data_address_i),
      .size_i   (data_size_i),
      .mode_i   (data_mode_i),
      .stall_o  (data_wait_led),
      .abort_v_o(led_abort_v),
      .data_in  (data_data_i),
      .data_out (data_data_led),
      .sw_i     (sw_pin_i),
      .led_o    (led_pin_o)
  );

  lcd_pio lcd_pio (
      .clk       (clk),             /* Specialised LCD interface */
      .reset     (reset),
      .cs_i      (cs_lcd),
      .read_i    (data_read_ok),
      .write_i   (data_write_ok),
      .address_i (data_address_i),
      .size_i    (data_size_i),
      .mode_i    (data_mode_i),
      .stall_o   (data_wait_lcd),
      .abort_v_o (lcd_abort_v),
      .data_in   (data_data_i),
      .data_out  (data_data_lcd),
      .lcd_ctrl_o(lcd_ctrl_o),
      .lcd_data_o(lcd_data_o),
      .lcd_data_i(lcd_data_i)
  );

  timer timer (
      .clk      (clk),              /* Slave timer */
      .reset    (reset),
      .cs_i     (cs_timer),
      .read_i   (data_read_ok),
      .write_i  (data_write_ok),
      .address_i(data_address_i),
      .mode_i   (data_mode_i),
      .size_i   (data_size_i),
      .stall_o  (data_wait_timer),
      .abort_v_o(timer_abort_v),
      .data_in  (data_data_i),
      .data_out (data_data_timer),  /* Bus multiplexed to processor */
      .ireq_o   (timer_ireq)
  );

  fifo_uart io2 (
      .clk      (clk),
      .reset    (reset),
      .cs_i     (cs_fifo),
      .read_i   (data_read_ok),
      .write_i  (data_write_ok),
      .address_i(data_address_i),
      .mode_i   (data_mode_i),
      .size_i   (data_size_i),
      .stall_o  (data_wait_fifo),
      .abort_v_o(fifo_abort_v),
      .data_in  (data_data_i),
      .data_out (data_data_fifo),

      .int_o(serial_ints),

      //.io_out(mm_io2),
      .fifo_full (fifo_full),
      .fifo_wr   (fifo_wr),
      .fifo_d_out(fifo_d_out),
      .fifo_empty(fifo_empty),
      .fifo_rd   (fifo_rd),
      .fifo_d_in (fifo_d_in)
  );

  assign fifo_Tx_ireq = serial_ints[0];  /* Aliasing */
  assign fifo_Rx_ireq = serial_ints[1];
  assign fifo_overrun = serial_ints[2];

  // #2 is serial error
  assign interrupts_o = 12'h000;

  interrupt_ctrl2 int_ctrl (
      .clk(clk),
      .reset(reset),
      .cs_i(cs_ints),
      .read_i(data_read_ok),
      .write_i(data_write_ok),
      .address_i(data_address_i),
      .size_i(data_size_i),
      .mode_i(data_mode_i),
      .stall_o(data_wait_ints),
      .abort_v_o(ints_abort_v),
      .data_in(data_data_i),
      .data_out(data_data_ints),  /* Bus muxed to processor */
      .ireq_i({
        21'h000000,
        fifo_overrun,  /* Serial (FIFO) */
        fifo_Rx_ireq,
        fifo_Tx_ireq,
        vdu_ireq,  /* ??? & Vertical sync. */
        !sw_pin_i[0],  /* Button  (inverted) */
        timer_ireq,  /* Timer terminal count */
        user_irq
      }),  /* 4x user interrupts */

      .ireq_o(ext_irq_o)
  );

  vduc vduc (
      .clk        (clk),
      .pixclk     (clk),
      .clk_TMDS   (clk_TMDS),
      .reset      (reset),
      .cs_i       (cs_vduc),
      .read_i     (data_read_ok),
      .write_i    (data_write_ok),
      .address_i  (data_address_i),
      .size_i     (data_size_i),
      .mode_i     (data_mode_i),
      .stall_o    (data_wait_vduc),
      .abort_v_o  (vduc_abort_v),
      .data_in    (data_data_i),
      .data_out   (data_data_vdu),
      .vduc_ireq_o(vdu_ireq),

      .v_width_o (screen_width),   /* Display definitions */
      .v_height_o(screen_height),  /*     Exported for    */
      .v_mode_o  (screen_mode),    /* drawing accelerator */
      .v_frame_o (screen_frame),

      .fs_read_o(data_VDUC_read),
      .fs_wait_i(data_VDUC_wait),
      .fs_addr_o(data_VDUC_addr),
      .fs_data_i(data_VDUC_data),

      .TMDS_shift_blue_o (TMDS_shift_blue_o),
      .TMDS_shift_green_o(TMDS_shift_green_o),
      .TMDS_shift_red_o  (TMDS_shift_red_o)
  );
  User_Peripheral user_periph (
      .clk      (clk),
      .reset    (reset),
      .cs_i     (cs_periphu),
      .read_i   (data_read_i),
      .size_i   (data_size_i),
      .write_i  (data_write_i),
      .mode_i   (data_mode_i),
      .address_i(data_address_i),
      .stall_o  (),
      .abort_o  (),
      .data_in  (data_data_i),
      .data_out (data_data_periphu),

      .port_in       (user_periph_din),
      .port_out      (user_periph_dout),
      .port_direction(user_periph_dir),
      .LED_o         (user_periph_LED_o),

      .LCD_data_i(user_periph_LCD_i),
      .LCD_data_o(user_periph_LCD_o[7:0]),
      .LCD_RW_o  (user_periph_LCD_o[8]),
      .LCD_RS_o  (user_periph_LCD_o[9]),
      .LCD_E_o   (user_periph_LCD_o[10]),
      .LCD_BL_o  (user_periph_LCD_o[11]),
      .switch_i  (~user_periph_SW_i),
      .irq_o     (user_irq),

      // ── new: VDU config (already in scope from screen_* wires) ──
      .v_width_i (screen_width),
      .v_height_i(screen_height),
      .v_mode_i  (screen_mode),
      .v_base_i  (screen_frame),

      // ── new: drawing engine → SRAM bus ──
      .de_req_o    (data_DE_req),
      .de_RnW_o    (data_DE_RnW),
      .de_nbyte_o  (data_DE_nbyte),
      .de_ack_i    (data_DE_ack),
      .de_address_o(data_DE_address),
      .de_wr_data_o(data_DE_wr_data),
      .de_rd_data_i(data_DE_rd_data)
  );
  control_io control_io (
      .clk         (clk),             /* General memory-mapped I/O */
      .reset       (reset),
      .cs_i        (cs_ctrl),
      .read_i      (data_read_ok),
      .write_i     (data_write_ok),
      .address_i   (data_address_i),
      .size_i      (data_size_i),
      .mode_i      (data_mode_i),
      .stall_o     (data_wait_ctl),
      .abort_v_o   (ctrl_abort_v),
      .data_in     (data_data_i),
      .data_out    (data_data_ctrl),
      .pin_fn_o    (pin_fn_o),
      .pin_LED_o   (pin_LED_o),
      .pin_LCD_o   (pin_LCD_o),
      .pin_LCD_BL_o(pin_LCD_BL_o),
      .mtime       (mtime),           /* Slave system time */
      .mtimer_irq_o(mtimer_irq_o),
      .halt_o      (stop_o)
  );  /* Self-halt request */

  sram_ctrl sram_ctrl (
      .clk  (clk),
      .reset(reset),

      .CS_A   (1'b1),                     // Cut off - Prob. always '1'?
      .read_A (data_VDUC_read),
      .write_A(1'b0),                     /* VDUC never writes */
      .stall_A(data_VDUC_wait),
      .size_A (2'h2),                     /* Always words */
      .addr_A ({data_VDUC_addr, 2'b00}),  /* Was word address */
      .dwr_A  (32'h0000_0000),            /* Tied off */
      .drd_A  (data_VDUC_data),           /* Pixel data returned */

      .CS_B     (cs_SRAM),
      .read_B   (data_read_ok),
      .write_B  (data_write_ok),
      .stall_B  (SRAM_wait),
      .size_B   (data_size_i),
      .addr_B   (data_address_i[19:0]),
      .dwr_B    (data_data_i),
      .drd_B    (data_data_SRAM),
      /*
                    .CS_C     (1'b1),
                    .read_C   (data_DE_read),
                    .write_C  (data_DE_write),
                    .stall_C  (data_DE_wait),
	                .size_C   (data_DE_size),
                    .addr_C   (data_DE_address),
                    .dwr_C    (data_DE_wr_data),
                    .drd_C    (data_DE_rd_data),
*/
      .de_req   (data_DE_req),           /* DE bus takes different form */
      .de_ack   (data_DE_ack),
      .de_addr  ({data_DE_address}),
      .de_nbyte (data_DE_nbyte),
      .de_w_data(data_DE_wr_data),
      .de_rnw   (data_DE_RnW),
      .de_r_data(data_DE_rd_data),

      .n_CS_o   (SRAM_n_CS_o),
      .n_rd_o   (SRAM_n_rd_o),
      .n_wr_o   (SRAM_n_wr_o),     /* Used for timing strobe */
      .addr_o   (SRAM_address_o),
      .n_bytes_o(SRAM_n_bytes_o),
      .n_write_o(SRAM_n_write_o),  /* Controls data output enable */
      .d_in_i   (SRAM_d_in_i),
      .d_out_o  (SRAM_d_out_o)
  );


  mem_wait mem_wait (
      .clk         (clk),           /* Wait state generator for test stress */
      .reset       (reset),
      .stall_imem_o(instr_wait),
      .stall_dmem_o(data_wait_mem)
  );

  assign instr_wait_o = instr_wait && instr_allow;
  assign data_wait_o  = data_wait_x;  //&& data_allow;

  wire disp_cycle;
  wire disp_cs_m, disp_cs_u, disp_cs_i, disp_cs_p, disp_cs_t, disp_cs_j;

  assign disp_cycle = (data_read_i || data_write_i);
  assign disp_cs_m  = cs_dmem_m && disp_cycle;
  assign disp_cs_u  = 1'b0 && disp_cycle;
  assign disp_cs_i  = cs_fifo && disp_cycle;
  assign disp_cs_p  = cs_pio && disp_cycle;
  assign disp_cs_t  = cs_timer && disp_cycle;
  assign disp_cs_j  = cs_ints && disp_cycle;

endmodule  // periph2

/*----------------------------------------------------------------------------*/
//
/*----------------------------------------------------------------------------*/

// This module not tested 'in action' @@@
module idec (
    input  wire [31:0] address_i,       /* Address decoder for bus units */
    input  wire [ 1:0] mode_i,
    input  wire [ 1:0] size_i,
    input  wire        read_i,
    output reg         cs_memory_o,
    output reg  [ 2:0] decoder_abort_o
);  // This is a *code* not vector

  wire access;
  reg  aligned;
  reg  access_fault;
  reg  page_fault;

  assign access = read_i;

  always @(*)
    case (size_i)
      2'b00:   aligned = 1'b1;
      2'b01:   aligned = address_i[0] == 1'b0;
      2'b10:   aligned = address_i[1:0] == 2'b00;
      2'b11:   aligned = address_i[2:0] == 3'b000;  /* Not in current use */
      default: aligned = 1'bx;
    endcase

  assign misaligned = access && !aligned;

  always @(access, address_i) begin
    if (access) access_fault = address_i[31:30] == 2'b10;  // Apply mode @@@
    else access_fault = 1'b0;
    if (access) page_fault = address_i[31:30] == 2'b11;
    else page_fault = 1'b0;
  end

  always @(*) begin
    if (page_fault) decoder_abort_o = `ABORT_LD_PAGE;
    else if (access_fault) decoder_abort_o = `ABORT_LD_ACC;
    else if (misaligned) decoder_abort_o = `ABORT_LD_ALGN;
    else decoder_abort_o = `ABORT_NONE;
  end

  always @(address_i, decoder_abort_o)
    if (decoder_abort_o != 3'h0) cs_memory_o = 1'b0;
    else cs_memory_o = address_i[31:28] == 4'b0000;

endmodule  // idec

/*----------------------------------------------------------------------------*/

// This module not tested 'in action' @@@
module idec2 (
    input  wire [31:0] address_i,       /* Address decoder for bus units */
    input  wire [ 1:0] mode_i,
    input  wire [ 1:0] size_i,
    input  wire        read_i,
    output reg         cs_memory_m_o,
    output reg         cs_memory_u_o,
    output reg  [ 2:0] decoder_abort_o
);  // This is a *code* not vector

  wire access;
  reg  aligned;
  reg  access_fault;
  reg  page_fault;

  assign access = read_i;

  always @(*)
    case (size_i)
      2'b00:   aligned = 1'b1;
      2'b01:   aligned = address_i[0] == 1'b0;
      2'b10:   aligned = address_i[1:0] == 2'b00;
      2'b11:   aligned = address_i[2:0] == 3'b000;  /* Not in current use */
      default: aligned = 1'bx;
    endcase

  assign misaligned = access && !aligned;

  always @(access, address_i) begin
    if (access) access_fault = address_i[31:30] == 2'b10;  // Apply mode @@@
    else access_fault = 1'b0;
    if (access) page_fault = address_i[31:30] == 2'b11;
    else page_fault = 1'b0;
  end

  always @(*) begin
    if (page_fault) decoder_abort_o = `ABORT_LD_PAGE;
    else if (access_fault) decoder_abort_o = `ABORT_LD_ACC;
    else if (misaligned) decoder_abort_o = `ABORT_LD_ALGN;
    else decoder_abort_o = `ABORT_NONE;
  end

  always @(address_i, decoder_abort_o)
    if (decoder_abort_o != 3'h0) begin
      cs_memory_m_o = 1'b0;
      cs_memory_u_o = 1'b0;
    end else begin
      cs_memory_m_o = address_i[31:16] == 16'h0000;  /* 64 KiB system (machine) RAM */
      cs_memory_u_o = address_i[31:18] == 14'h0001;  /* 256 KiB user RAM area */
    end

endmodule  // idec2

/*----------------------------------------------------------------------------*/
//
/*----------------------------------------------------------------------------*/
/* Indicate what is allowed in which region                                   */
/* Later, expand to put tests in here @@@                                     */
//
//module mpu (input  wire [31:0] address_i,
//            input  wire  [1:0] mode_i,
//            input  wire  [1:0] size_i,
//            input  wire        read_i,
//            input  wire        write_i,
//            output reg  [15:0] abort_o,
//            output reg  [15:0] allowed_o);
//
//always @ (address_i)
//case (address_i[31:30])
//  2'h0: allowed_o = 16'b1_11_111_11_111_11_111;
//  2'h1: allowed_o = 16'b1_11_111_11_111_11_111;
//  2'h2: allowed_o = 16'b1_00_000_00_000_00_000;
//  2'h3: allowed_o = 16'b0_11_111_11_111_11_111;
//endcase
//
//// Page_present : 3x {Wr Rd : 3x sizes} for 3 privilege modes
//
//endmodule	// mpu

/*----------------------------------------------------------------------------*/
//
/*----------------------------------------------------------------------------*/

module decoder (
    input  wire [31:0] address_i,         /* Address decoder for bus units */
    input  wire [ 1:0] mode_i,
    input  wire [ 1:0] size_i,
    input  wire        read_i,
    input  wire        write_i,
    output reg         cs_memory_o,
    output reg         cs_mm_io_o,
    output reg         cs_uart_o,
    output reg         cs_pio_o,
    output reg         cs_timer_o,
    output reg         cs_ints_o,
    output reg  [ 2:0] decoder_abort_v_o
);

  wire access;
  reg  aligned;
  reg  access_fault;
  reg  page_fault;

  assign access = read_i || write_i;

  always @(*)
    case (size_i)
      2'b00:   aligned = 1'b1;
      2'b01:   aligned = address_i[0] == 1'b0;
      2'b10:   aligned = address_i[1:0] == 2'b00;
      2'b11:   aligned = address_i[2:0] == 3'b000;  /* Not in current use */
      default: aligned = 1'bx;
    endcase

  assign misaligned = access && !aligned;

  always @(access, address_i) begin
    if (access) access_fault = address_i[31:30] == 2'b10;  // Apply mode @@@
    else access_fault = 1'b0;
    if (access) page_fault = address_i[31:30] == 2'b11;
    else page_fault = 1'b0;
  end

  always @(*) begin
    decoder_abort_v_o = 3'h0;
    if (misaligned) decoder_abort_v_o[`ABORT_BIT_ALGN] = 1'b1;
    if (access_fault) decoder_abort_v_o[`ABORT_BIT_ACC] = 1'b1;
    if (page_fault) decoder_abort_v_o[`ABORT_BIT_PAGE] = 1'b1;
  end

  /*
always @ (address_i, decoder_abort_v_o)
if (decoder_abort_v_o != 3'h0) 
 cs_memory_o = 1'b0;
else
 cs_memory_o = address_i[15:28] == 4'h0;
 */

  always @(address_i, decoder_abort_v_o)
    if (decoder_abort_v_o != 3'h0)                        /* Cycle won't complete */
  begin                                        /* Suppress all select signals */
      cs_memory_o = 1'b0;
      cs_uart_o   = 1'b0;
      cs_pio_o    = 1'b0;
      cs_mm_io_o  = 1'b0;
      cs_timer_o  = 1'b0;
      cs_ints_o   = 1'b0;
    end else begin  /* Region decoder */
      cs_memory_o = address_i[31:28] == 4'h0;
      cs_uart_o   = address_i[31:24] == 8'h10;
      cs_pio_o    = address_i[31:24] == 8'h18;     // addresses => enumerated! @@@
      cs_mm_io_o  = address_i[31:24] == 8'h20;
      cs_timer_o  = address_i[31:24] == 8'h28;
      cs_ints_o   = address_i[31:24] == 8'h30;
    end

endmodule  // decoder

/*----------------------------------------------------------------------------*/

module decoder2 (
    input  wire [31:0] address_i,         /* Address decoder for bus units*/
    input  wire [ 1:0] mode_i,
    input  wire [ 1:0] size_i,
    input  wire        read_i,
    input  wire        write_i,
    output reg         cs_memory_m_o,
    output reg         cs_memory_u_o,
    output reg         cs_led_pio_o,
    output reg         cs_lcd_pio_o,
    output reg         cs_timer_o,
    output reg         cs_pio_o,
    output reg         cs_ints_o,
    output reg         cs_fifo_o,
    output reg         cs_vduc_o,
    output reg         cs_drawing_o,
    output reg         cs_ctrl_o,
    output reg         cs_periphu_o,
    output reg         cs_SRAM_o,
    output reg  [ 2:0] decoder_abort_v_o
);

  wire access;
  reg  aligned;
  reg  access_fault;
  reg  page_fault;

  reg  cs_periph;  /* Peripheral interface select */

  assign access = read_i || write_i;

  always @(*)
    case (size_i)
      2'b00:   aligned = 1'b1;
      2'b01:   aligned = address_i[0] == 1'b0;
      2'b10:   aligned = address_i[1:0] == 2'b00;
      2'b11:   aligned = address_i[2:0] == 3'b000;  /* Not in current use */
      default: aligned = 1'bx;
    endcase

  assign misaligned = access && !aligned;

  always @(access, address_i) begin
    if (access) access_fault = address_i[31:30] == 2'b10;  // Apply mode @@@
    else access_fault = 1'b0;
    if (access) page_fault = address_i[31:30] == 2'b11;
    else page_fault = 1'b0;
  end

  always @(*) begin
    decoder_abort_v_o = 3'h0;
    if (misaligned) decoder_abort_v_o[`ABORT_BIT_ALGN] = 1'b1;
    if (access_fault) decoder_abort_v_o[`ABORT_BIT_ACC] = 1'b1;
    if (page_fault) decoder_abort_v_o[`ABORT_BIT_PAGE] = 1'b1;
  end

  /*
always @ (address_i, decoder_abort_v_o)
if (decoder_abort_v_o != 3'h0) 
 cs_memory_o = 1'b0;
else
 cs_memory_o = address_i[15:28] == 4'h0;
*/

  always @(address_i, decoder_abort_v_o)
    if (decoder_abort_v_o != 3'h0)                        /* Cycle won't complete */
  begin                                        /* Suppress all select signals */
      cs_memory_m_o = 1'b0;
      cs_memory_u_o = 1'b0;
      cs_periph     = 1'b0;
      cs_periphu_o  = 1'b0;
      cs_SRAM_o     = 1'b0;
    end else begin  /* Region decoder */
      cs_memory_m_o = address_i[31:16] == `MEMORY_AREA_S0;  /* System mem. (64 KiB)*/
      cs_memory_u_o = (address_i[31:16] == `MEMORY_AREA_S1a)  /* User mem. (256 KiB)*/
      || (address_i[31:16] == `MEMORY_AREA_S1b)  // Prettify? @@@
      || (address_i[31:16] == `MEMORY_AREA_S1c) || (address_i[31:16] == `MEMORY_AREA_S1d);
      cs_periph = address_i[31:16] == `PERIPH;  /* Peripherals at 0001_xxxx */
      cs_periphu_o = address_i[31:16] == `PERIPHU;  /* Peripherals at 0002_xxxx */
      cs_SRAM_o = address_i[31:20] == `SRAM;
    end

  always @(cs_periph, address_i) begin
    cs_led_pio_o = 1'b0;
    cs_lcd_pio_o = 1'b0;
    cs_timer_o   = 1'b0;
    cs_pio_o     = 1'b0;
    cs_ints_o    = 1'b0;
    cs_fifo_o    = 1'b0;
    cs_vduc_o    = 1'b0;
    cs_drawing_o = 1'b0;
    cs_ctrl_o    = 1'b0;
    if (cs_periph)
      case (address_i[15:8])
        `P_LED:  cs_led_pio_o = 1'b1;  /*  LEDs in space 0001_00xx */
        `P_LCD:  cs_lcd_pio_o = 1'b1;  /*   LCD in space 0001_01xx */
        `P_TIM:  cs_timer_o = 1'b1;  /* Timer in space 0001_02xx */
        `P_PIO:  cs_pio_o = 1'b1;  /*   PIO in space 0001_03xx */
        `P_INT:  cs_ints_o = 1'b1;  /* Interrupt controller in space 0001_04xx */
        `P_FIFO: cs_fifo_o = 1'b1;  /* FIFO in space 0001_05xx */
        `P_VDU:  cs_vduc_o = 1'b1;  /*  VDUC in space 0001_06xx */
        `P_CTL:  cs_ctrl_o = 1'b1;  /*   PIO in space 0001_07xx */
        `P_DE:   cs_drawing_o = 1'b1;  /*    DE in space 0001_08xx */
      endcase
  end

endmodule  // decoder2

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

module data_mux (
    input  wire        clk,        /* Return data multiplexer */
    input  wire        ready_i,    /* Stall op. from pipeline */
    input  wire [31:0] address_i,
    input  wire [31:0] memory_i,
    input  wire [31:0] uart_i,
    input  wire [31:0] pio_i,
    input  wire [31:0] mm_io_i,
    input  wire [31:0] timer_i,
    input  wire [31:0] ints_i,
    output reg  [31:0] data_o
);

  reg [31:2] addr;

  always @(posedge clk) if (ready_i) addr <= address_i[31:2];  /* Delay for next cycle */

  always @(*)
    case (addr[31:27])
      5'h0:    data_o = memory_i;
      5'h1:    data_o = memory_i;
      5'h2:    data_o = uart_i;
      5'h3:    data_o = pio_i;
      5'h4:    data_o = mm_io_i;
      5'h5:    data_o = timer_i;
      5'h6:    data_o = ints_i;
      default: data_o = 32'hxxxx_xxxx;
    endcase

endmodule  // data_mux

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

module instr_mux (
    input  wire        clk,         /* Return data multiplexer */
    input  wire        ready_i,     /* Stall op. from pipeline */
    input  wire [31:0] address_i,
    input  wire [31:0] memory_m_i,
    input  wire [31:0] memory_u_i,
    output reg  [31:0] data_o
);

  reg [31:0] addr;

  always @(posedge clk) if (ready_i) addr <= address_i;  /* Delay for next cycle */

  always @(*)
    case (addr[31:18])
      14'h0000: data_o = memory_m_i;
      //  14'h0001: data_o = memory_u_i;
      14'h0001:
      data_o = (memory_u_i == 32'h0000_0000) ? 32'h0000_0001 : memory_u_i;  // ********************
      default: data_o = 32'hxxxx_xxxx;
    endcase

endmodule  // instr_mux
// Used in periph2

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

module data_mux2 (
    input  wire        clk,         /* Return data multiplexer */
    input  wire        ready_i,     /* Stall op. from pipeline */
    input  wire [31:0] address_i,
    input  wire [31:0] memory_m_i,
    input  wire [31:0] memory_u_i,
    input  wire [31:0] periph_i,
    input  wire [31:0] user_i,
    input  wire [31:0] SRAM_i,
    output reg  [31:0] data_o
);

  reg [31:0] addr;

  always @(posedge clk) if (ready_i) addr <= address_i;  /* Delay for next cycle */

  always @(*)
    if (addr[31:20] == `SRAM) data_o = SRAM_i;  /* Framestore area */
    else if (addr[31:20] == 12'h000)  /* Other used area */
      case (addr[31:16])
        `MEMORY_AREA_S0:  data_o = memory_m_i;
        `PERIPH:          data_o = periph_i;
        `PERIPHU:         data_o = user_i;
        `MEMORY_AREA_S1a: data_o = memory_u_i;
        `MEMORY_AREA_S1b: data_o = memory_u_i;
        `MEMORY_AREA_S1c: data_o = memory_u_i;
        `MEMORY_AREA_S1d: data_o = memory_u_i;
        //  default:  data_o = 32'hxxxx_xxxx;
        default:          data_o = 32'h2A2A_2A2A;  /* Empty address space */
      endcase
    else data_o = 32'h2A2A_2A2A;  /* Empty address space */

endmodule  // data_mux2
// Used in periph2


module data_mux2a (
    input wire        clk,       /* Return data multiplexer */
    input wire        ready_i,   /* Stall op. from pipeline */
    input wire [31:0] address_i,

    input wire [31:0] data_data_led_i,
    input wire [31:0] data_data_lcd_i,
    input wire [31:0] data_data_timer_i,
    input wire [31:0] data_data_pio_i,
    input wire [31:0] data_data_ints_i,
    input wire [31:0] data_data_fifo_i,
    input wire [31:0] data_data_vdu_i,
    input wire [31:0] data_data_ctrl_i,
    input wire [31:0] data_data_DE_i,

    input wire data_wait_led_i,
    input wire data_wait_lcd_i,
    input wire data_wait_timer_i,
    input wire data_wait_pio_i,
    input wire data_wait_ints_i,
    input wire data_wait_fifo_i,
    input wire data_wait_vduc_i,
    input wire data_wait_ctl_i,
    input wire data_wait_DE_i,

    output reg  [31:0] data_periph_o,
    output wire        data_wait_o
);

  reg [7:0] mux_addr;

  always @(posedge clk) if (ready_i) mux_addr <= address_i[15:8];
  /* Data is next cycle */
  always @(*)
    case (mux_addr)  // Latched address @@@
      `P_LED:  data_periph_o = data_data_led_i;
      `P_LCD:  data_periph_o = data_data_lcd_i;
      `P_TIM:  data_periph_o = data_data_timer_i;
      `P_PIO:  data_periph_o = data_data_pio_i;
      `P_INT:  data_periph_o = data_data_ints_i;
      `P_FIFO: data_periph_o = data_data_fifo_i;
      `P_VDU:  data_periph_o = data_data_vdu_i;
      `P_CTL:  data_periph_o = data_data_ctrl_i;
      `P_DE:   data_periph_o = data_data_DE_i;
      default: data_periph_o = 32'h12345678;
    endcase

  assign data_wait_o = data_wait_led_i  || data_wait_lcd_i  || data_wait_timer_i
                  || data_wait_pio_i  || data_wait_ints_i || data_wait_fifo_i
                  || data_wait_vduc_i || data_wait_ctl_i  || data_wait_DE_i;

endmodule  // data_mux2a

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
/* Reconciles potential abort issues to encoded value for processor.          */

module data_abort (
    input  wire       read_i,
    input  wire       write_i,
    input  wire [2:0] decoder_abort_v,
    input  wire [2:0] mem_abort_v,
    input  wire [2:0] uart_abort_v,
    input  wire [2:0] pio_abort_v,
    input  wire [2:0] timer_abort_v,
    input  wire [2:0] io_abort_v,
    input  wire [2:0] ints_abort_v,
    output reg  [2:0] abort_o
);

  wire [2:0] source_vector = decoder_abort_v | mem_abort_v | uart_abort_v
             | pio_abort_v | timer_abort_v | io_abort_v  | ints_abort_v;

  always @(*)  /* Priority as far as I can see :-/ */
    if (!(read_i || write_i)) abort_o = `ABORT_NONE;
    else if (source_vector[`ABORT_BIT_PAGE]) abort_o = read_i ? `ABORT_LD_PAGE : `ABORT_ST_PAGE;
    else if (source_vector[`ABORT_BIT_ACC]) abort_o = read_i ? `ABORT_LD_ACC : `ABORT_ST_ACC;
    else if (source_vector[`ABORT_BIT_ALGN]) abort_o = read_i ? `ABORT_LD_ALGN : `ABORT_ST_ALGN;
    else abort_o = `ABORT_NONE;

endmodule  // data_abort

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

module data_abort2 (
    input  wire       read_i,
    input  wire       write_i,
    input  wire [2:0] decoder_abort_v,
    input  wire [2:0] mem_abort_v,
    input  wire [2:0] led_abort_v,
    input  wire [2:0] lcd_abort_v,
    input  wire [2:0] timer_abort_v,
    input  wire [2:0] pio_abort_v,
    input  wire [2:0] ints_abort_v,
    input  wire [2:0] fifo_abort_v,
    input  wire [2:0] vduc_abort_v,
    input  wire [2:0] ctrl_abort_v,
    input  wire [2:0] DE_abort_v,
    output reg  [2:0] abort_o
);

  wire [2:0] source_vector = decoder_abort_v | mem_abort_v
             | led_abort_v  | lcd_abort_v  | timer_abort_v | pio_abort_v
             | ints_abort_v | fifo_abort_v | vduc_abort_v  | ctrl_abort_v
             | DE_abort_v;

  always @(*)  /* Priority as far as I can see :-/ */
    if (!(read_i || write_i)) abort_o = `ABORT_NONE;
    else if (source_vector[`ABORT_BIT_PAGE]) abort_o = read_i ? `ABORT_LD_PAGE : `ABORT_ST_PAGE;
    else if (source_vector[`ABORT_BIT_ACC]) abort_o = read_i ? `ABORT_LD_ACC : `ABORT_ST_ACC;
    else if (source_vector[`ABORT_BIT_ALGN]) abort_o = read_i ? `ABORT_LD_ALGN : `ABORT_ST_ALGN;
    else abort_o = `ABORT_NONE;

endmodule  // data_abort2

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

module dp_mem (
    input  wire        clk,
    input  wire        reset,
    input  wire        cs_imem_i,
    input  wire        instr_read_i,
    input  wire        instr_write_i,    // Never active -/
    input  wire [31:0] instr_address_i,
    input  wire [ 1:0] instr_size_i,
    input  wire [31:0] instr_data_i,     // Dummy here, for symmetry -/
    output wire [31:0] instr_data_o,

    input  wire        cs_dmem_i,
    input  wire        data_read_i,
    input  wire        data_write_i,
    input  wire [31:0] data_address_i,
    input  wire [ 1:0] data_size_i,
    input  wire [31:0] data_data_st_i,
    output wire [31:0] data_data_mem_o
);

  parameter slave = 0;
  localparam RAM_ADDR_BITS = 12;

  wire [              3:0] data_write;
  wire [              3:0] instr_write;  /* Inactive here: included for regularity */
  wire [RAM_ADDR_BITS-1:0] data_addr;
  wire [RAM_ADDR_BITS-1:0] instr_addr;

  wire ena, enb;

  assign ena = cs_dmem_i && (data_read_i || data_write_i);
  assign enb = cs_imem_i && (instr_read_i || instr_write_i);

  blk_mem_gen_1 dp_mem_block (
      .clka (clk),              /* Data port */
      .ena  (ena),              /* CS and can change */
      .wea  (data_write[3:0]),  /* Byte writes */
      .addra(data_addr),        /* Address */
      .dina (data_data_st_i),   /* Store data */
      .douta(data_data_mem_o),  /* Load data */

      .clkb (clk),               /* Instruction port */
      .enb  (enb),               /* CS and can change */
      .web  (instr_write[3:0]),  /* Tied inactive externally */
      .addrb(instr_addr),        /* Address */
      .dinb (instr_data_i),      /* Dummy: tied off */
      .doutb(instr_data_o)       /* Instruction output */
  );

  assign data_addr   = data_address_i[RAM_ADDR_BITS+1:2];  /* Cut to size */
  assign instr_addr  = instr_address_i[RAM_ADDR_BITS+1:2];

  assign data_write  = wr_strb(data_write_i, data_size_i, data_address_i[1:0]);
  assign instr_write = wr_strb(instr_write_i, instr_size_i, instr_address_i[1:0]);

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  function [3:0] wr_strb;  // Should only need once: Xilinx disagrees :-( @@@
    input wr;
    input [1:0] size, addr;
    begin
      if (wr)
        case (size)
          2'b00:   wr_strb = 4'b0001 << addr;
          2'b01:   wr_strb = 4'b0011 << {addr[1], 1'b0};
          2'b10:   wr_strb = 4'b1111;
          default: wr_strb = 4'b0000;
        endcase
      else wr_strb = 4'b0000;
    end
  endfunction

endmodule  // dp_mem

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
// There has to be a nicer way ...

module dp_mem2 (
    input  wire        clk,
    input  wire        reset,
    input  wire        cs_imem_i,
    input  wire        instr_read_i,
    input  wire        instr_write_i,    /* Never active */
    input  wire [31:0] instr_address_i,
    input  wire [ 1:0] instr_size_i,
    input  wire [31:0] instr_data_i,     /* Dummy here, for symmetry */
    output wire [31:0] instr_data_o,

    input  wire        cs_dmem_i,
    input  wire        data_read_i,
    input  wire        data_write_i,
    input  wire [31:0] data_address_i,
    input  wire [ 1:0] data_size_i,
    input  wire [31:0] data_data_st_i,
    output wire [31:0] data_data_mem_o
);

  parameter slave = 0;
  localparam RAM_ADDR_BITS = 12;

  wire [              3:0] data_write;
  wire [              3:0] instr_write;  /* Inactive here: included for regularity */
  wire [RAM_ADDR_BITS-1:0] data_addr;
  wire [RAM_ADDR_BITS-1:0] instr_addr;

  wire ena, enb;

  assign ena = cs_dmem_i && (data_read_i || data_write_i);
  assign enb = cs_imem_i && (instr_read_i || instr_write_i);

  blk_mem_gen_2 dp_mem_block (
      .clka (clk),              /* Data port */
      .ena  (ena),              /* CS and can change */
      .wea  (data_write[3:0]),  /* Byte writes */
      .addra(data_addr),        /* Address */
      .dina (data_data_st_i),   /* Store data */
      .douta(data_data_mem_o),  /* Load data */

      .clkb (clk),               /* Instruction port */
      .enb  (enb),               /* CS and can change */
      .web  (instr_write[3:0]),  /* Tied inactive externally */
      .addrb(instr_addr),        /* Address */
      .dinb (instr_data_i),      /* Dummy: tied off */
      .doutb(instr_data_o)       /* Instruction output */
  );

  assign data_addr   = data_address_i[RAM_ADDR_BITS+1:2];  /* Cut to size */
  assign instr_addr  = instr_address_i[RAM_ADDR_BITS+1:2];

  assign data_write  = wr_strb(data_write_i, data_size_i, data_address_i[1:0]);
  assign instr_write = wr_strb(instr_write_i, instr_size_i, instr_address_i[1:0]);

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  function [3:0] wr_strb;  // Should only need once: Xilinx disagrees :-( @@@
    input wr;
    input [1:0] size, addr;
    begin
      if (wr)
        case (size)
          2'b00:   wr_strb = 1 << addr;
          2'b01:   wr_strb = 3 << {addr[1], 1'b0};
          2'b10:   wr_strb = 4'b1111;
          default: wr_strb = 4'b0000;
        endcase
      else wr_strb = 4'b0000;
    end
  endfunction

endmodule  // dp_mem2

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
// There has to be a nicer way ...

module dp_mem3  /* Large. user RAM */
(
    input  wire        clk,
    input  wire        reset,
    input  wire        cs_imem_i,
    input  wire        instr_read_i,
    input  wire        instr_write_i,    /* Never active */
    input  wire [31:0] instr_address_i,
    input  wire [ 1:0] instr_size_i,
    input  wire [31:0] instr_data_i,     /* Dummy here, for symmetry */
    output wire [31:0] instr_data_o,

    input  wire        cs_dmem_i,
    input  wire        data_read_i,
    input  wire        data_write_i,
    input  wire [31:0] data_address_i,
    input  wire [ 1:0] data_size_i,
    input  wire [31:0] data_data_st_i,
    output wire [31:0] data_data_mem_o
);

  parameter slave = 0;
  localparam RAM_ADDR_BITS = 16;

  wire [              3:0] data_write;  /* Write lane enables */
  wire [              3:0] instr_write;  /* Inactive here: inc. for regularity */
  wire [RAM_ADDR_BITS-1:0] data_addr;
  wire [RAM_ADDR_BITS-1:0] instr_addr;

  wire ena, enb;  /* BRAM block enables */

  assign ena = cs_dmem_i && (data_read_i || data_write_i);
  assign enb = cs_imem_i && (instr_read_i || instr_write_i);

  blk_mem_gen_3 dp_mem_block  // This actual block will be larger @@@
  (
      .clka (clk),              /* Data port */
      .ena  (ena),              /* CS and can change */
      .wea  (data_write[3:0]),  /* Byte writes */
      .addra(data_addr),        /* Address */
      .dina (data_data_st_i),   /* Store data */
      .douta(data_data_mem_o),  /* Load data */

      .clkb (clk),               /* Instruction port */
      .enb  (enb),               /* CS and can change */
      .web  (instr_write[3:0]),  /* Tied inactive externally */
      .addrb(instr_addr),        /* Address */
      .dinb (instr_data_i),      /* Dummy: tied off */
      .doutb(instr_data_o)       /* Instruction output */
  );

  assign data_addr   = data_address_i[RAM_ADDR_BITS+1:2];  /* Cut to local size */
  assign instr_addr  = instr_address_i[RAM_ADDR_BITS+1:2];

  assign data_write  = wr_strb(data_write_i, data_size_i, data_address_i[1:0]);
  assign instr_write = wr_strb(instr_write_i, instr_size_i, instr_address_i[1:0]);

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  function [3:0] wr_strb;  // Should only need once: Xilinx disagrees :-( @@@
    input wr;
    input [1:0] size, addr;
    begin
      if (wr)
        case (size)
          2'b00:   wr_strb = 1 << addr;
          2'b01:   wr_strb = 3 << {addr[1], 1'b0};
          2'b10:   wr_strb = 4'b1111;
          default: wr_strb = 4'b0000;
        endcase
      else wr_strb = 4'b0000;
    end
  endfunction

endmodule  // dp_mem3

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
/* Model of Xilinx dual-port BRAM                                             */
/*
module blk_mem_gen_1 (input  wire        clka,
                      input  wire        ena,
                      input  wire  [3:0] wea,
                      input  wire [11:0] addra,
                      input  wire [31:0] dina,
                      output reg  [31:0] douta,
                      input  wire        clkb,
                      input  wire        enb,
                      input  wire  [3:0] web,
                      input  wire [11:0] addrb,
                      input  wire [31:0] dinb,
                      output reg  [31:0] doutb);

parameter slave = 0;

reg   [7:0] memory_0 [0:`MEMORY_WORDS_1-1];
reg   [7:0] memory_1 [0:`MEMORY_WORDS_1-1];
reg   [7:0] memory_2 [0:`MEMORY_WORDS_1-1];
reg   [7:0] memory_3 [0:`MEMORY_WORDS_1-1];
reg  [31:0] temp_memory [0:`MEMORY_WORDS_1-1];
int i;

initial
begin
case (slave)
  0: $readmemh("code.hex", temp_memory);
  1: $readmemh("slave.hex", temp_memory);
endcase
for (i = 0; i < `MEMORY_WORDS_1; i = i + 1)
  begin                            // Split words into byte-accessible memory //
  memory_0[i] =  temp_memory[i]        & 8'hFF;
  memory_1[i] = (temp_memory[i] >> 8)  & 8'hFF;
  memory_2[i] = (temp_memory[i] >> 16) & 8'hFF;
  memory_3[i] = (temp_memory[i] >> 24) & 8'hFF;
  end
end

always @ (posedge clka)
if (ena && !(|wea)) douta <= {memory_3[addra], memory_2[addra],
                              memory_1[addra], memory_0[addra]};

always @ (clka)
begin
if (ena && wea[3]) memory_3[addra] <= dina[31:24];
if (ena && wea[2]) memory_2[addra] <= dina[23:16];
if (ena && wea[1]) memory_1[addra] <= dina[15:8];
if (ena && wea[0]) memory_0[addra] <= dina[7:0];
end

always @ (posedge clkb)
if (enb && !(|web)) doutb <= {memory_3[addrb], memory_2[addrb],
                              memory_1[addrb], memory_0[addrb]};

always @ (clkb)
begin
if (enb && web[3]) memory_3[addrb] <= dinb[31:24];
if (enb && web[2]) memory_2[addrb] <= dinb[23:16];
if (enb && web[1]) memory_1[addrb] <= dinb[15:8];
if (enb && web[0]) memory_0[addrb] <= dinb[7:0];
end

endmodule	// blk_mem_gen_1

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -//
// Model of Xilinx dual-port BRAM                                             //

module blk_mem_gen_2 (input  wire        clka,
                      input  wire        ena,
                      input  wire  [3:0] wea,
                      input  wire [11:0] addra,
                      input  wire [31:0] dina,
                      output reg  [31:0] douta,
                      input  wire        clkb,
                      input  wire        enb,
                      input  wire  [3:0] web,
                      input  wire [11:0] addrb,
                      input  wire [31:0] dinb,
                      output reg  [31:0] doutb);

parameter slave = 0;

reg   [7:0] memory_0 [0:`MEMORY_WORDS_2-1];
reg   [7:0] memory_1 [0:`MEMORY_WORDS_2-1];
reg   [7:0] memory_2 [0:`MEMORY_WORDS_2-1];
reg   [7:0] memory_3 [0:`MEMORY_WORDS_2-1];
reg  [31:0] temp_memory [0:`MEMORY_WORDS_2-1];
int i;

initial
begin
case (slave)
  0: $readmemh("code.hex", temp_memory);
  1: $readmemh("slave.hex", temp_memory);
endcase
for (i = 0; i < `MEMORY_WORDS_2; i = i + 1)
  begin                            // Split words into byte-accessible memory //
  memory_0[i] =  temp_memory[i]        & 8'hFF;
  memory_1[i] = (temp_memory[i] >> 8)  & 8'hFF;
  memory_2[i] = (temp_memory[i] >> 16) & 8'hFF;
  memory_3[i] = (temp_memory[i] >> 24) & 8'hFF;
  end
end

always @ (posedge clka)
if (ena && !(|wea)) douta <= {memory_3[addra], memory_2[addra],
                              memory_1[addra], memory_0[addra]};

always @ (clka)
begin
if (ena && wea[3]) memory_3[addra] <= dina[31:24];
if (ena && wea[2]) memory_2[addra] <= dina[23:16];
if (ena && wea[1]) memory_1[addra] <= dina[15:8];
if (ena && wea[0]) memory_0[addra] <= dina[7:0];
end

always @ (posedge clkb)
if (enb && !(|web)) doutb <= {memory_3[addrb], memory_2[addrb],
                              memory_1[addrb], memory_0[addrb]};

always @ (clkb)
begin
if (enb && web[3]) memory_3[addrb] <= dinb[31:24];
if (enb && web[2]) memory_2[addrb] <= dinb[23:16];
if (enb && web[1]) memory_1[addrb] <= dinb[15:8];
if (enb && web[0]) memory_0[addrb] <= dinb[7:0];
end

endmodule	// blk_mem_gen_2
*/
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
//
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
/* Test wait-state injector                                                   */

module mem_wait (
    input  wire clk,
    input  wire reset,
    output wire stall_imem_o,
    output wire stall_dmem_o
);

  reg [3:0] imem_state, dmem_state;

  always @(posedge clk)
    if (reset) imem_state <= 4'h0;
    else imem_state <= imem_state + 4'h1;

  assign stall_imem_o = 0;//imem_state[2:0] ==  3'h7;             // *****************************************

  always @(posedge clk)
    if (reset) dmem_state <= 4'h0;
    //else       dmem_state <= dmem_state + 4'h1;
    else if (dmem_state == 4'hE) dmem_state <= 4'h0;
    else dmem_state <= dmem_state + 4'h1;

  assign stall_dmem_o = 0;  //dmem_state[3:0] ==  4'h9;        // ****************************

endmodule  // mem_wait

/*============================================================================*/
//
/*============================================================================*/

`define LEN_BITS (clog2(LENGTH))

module FIFO #(
    parameter LENGTH = 4,
    parameter WIDTH  = 8
) (
    input  wire             clk,
    input  wire             reset,
    output wire             empty,
    output reg              full,
    input  wire             writing,
    input  wire [WIDTH-1:0] in_data,
    input  wire             reading,
    output wire [WIDTH-1:0] out_data
);

  reg [WIDTH-1:0] buffer[0:LENGTH-1];
  reg [`LEN_BITS-1:0] head, tail;
  wire [`LEN_BITS-1:0] next_head, next_tail;
  wire [1:0] action;
  wire       writing_2;

  assign writing_2 = writing && !full;  /* A bit 'belt and braces' */
  assign action    = {reading, writing_2};

  always @(posedge clk)
    if (reset) begin
      head <= 0;
      tail <= 0;
      full <= 1'b0;
    end else begin
      if (writing_2) begin
        buffer[tail] <= in_data;
        tail <= next_tail;
      end
      if (reading && !empty) head <= next_head;
      case (action)
        2'b01: full <= (head == next_tail);  /* Writing and not reading */
        2'b10: full <= 1'b0;  /* Reading and not writing */
      endcase
    end

  assign out_data = buffer[head];  // Output multiplexer

  assign next_tail = (tail + 1) % LENGTH;  // Modulo length
  assign next_head = (head + 1) % LENGTH;  // Modulo length
  assign empty = (head == tail) && !full;

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  function integer clog2;
    input integer value;
    integer temp;
    begin
      temp = value - 1;
      for (clog2 = 0; temp > 0; clog2 = clog2 + 1) temp = temp >> 1;
    end
  endfunction

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

endmodule  // FIFO

/*----------------------------------------------------------------------------*/
//
/*----------------------------------------------------------------------------*/

//module sram_ctrl(input  wire        clk,
//                 input  wire        reset,
//
//                 input  wire        CS_A,
//                 input  wire        read_A,
//                 input  wire        write_A,
//                 output wire        stall_A,
//                 input  wire  [1:0] size_A,
//                 input  wire [19:0] addr_A,
//                 input  wire [31:0] dwr_A,
//                 output wire [31:0] drd_A,
//
//                 input  wire        CS_B,
//                 input  wire        read_B,
//                 input  wire        write_B,
//                 output wire        stall_B,
//                 input  wire  [1:0] size_B,
//                 input  wire [19:0] addr_B,
//                 input  wire [31:0] dwr_B,
//                 output wire [31:0] drd_B,
//
//                 output reg         n_CS_o,
//                 output reg         n_rd_o,
//                 output reg         n_wr_o,
//                 output reg  [17:0] addr_o,
//                 output reg   [3:0] n_bytes_o,
//                 output wire        n_write_o,
//                 input  wire [31:0] d_in_i,
//                 output wire [31:0] d_out_o);
//
//wire   [1:0] CS;
//wire   [1:0] read;
//wire   [1:0] write;
//wire   [1:0] req;
//wire   [1:0] stall;
//reg    [1:0] grant;
//reg    [1:0] granted;
//wire   [1:0] select;
//reg    [1:0] next_state;
//reg    [1:0] state;
//wire         idle;
//
//reg    [1:0] size;
//reg    [1:0] addr_l;
//reg   [31:0] d_out;
//
//assign CS    = {CS_B,    CS_A};
//assign read  = {read_B,  read_A}  & CS;
//assign write = {write_B, write_A} & CS;
//assign stall_A = stall[0];
//assign stall_B = stall[1];
//assign req = read | write;
//
//always @ (*)
//if (reset) next_state = 2'b00;
//else
//  begin
//  next_state = 2'b00;	//     default
//  if (|grant) next_state = 2'b01;
//  end
//
//always @ (posedge clk) state <= next_state;
//
//assign idle = state == 2'b00;
//
//always @ (*)                                                       /* Arbiter */
//#1 if (idle)
//  begin
//  grant = 2'b00;
//  grant[0] = req[0];
//  if (!grant[0]) grant[1] = req[1];
//  end
//else grant = 2'b00;
//
//always @ (posedge clk)
//if (reset) granted <= 2'b00;
//else if (idle) granted <= grant;
//     else if (next_state == 2'b00) granted <= 2'b00;
//
//assign select = grant | ({2{!idle}} & granted);
//
//always @ (*)           n_CS_o  = !(|(CS    & select));
//always @ (*)           n_rd_o  = !(|(read  & select));
//always @ (negedge clk) n_wr_o <= !(|(write & grant));	// Shortened pulse
//
//assign #1 stall = req & ({2{idle}}| ~granted);
//
//assign drd_A = d_in_i;
//assign drd_B = d_in_i;
//
//always @ (*)
//case (select)
//  2'b01:   begin
//           addr_o = addr_A[19:2];
//           addr_l = addr_A[1:0];
//           size   = size_A;
//           d_out  = dwr_A;
//           end
//  2'b10:   begin
//           addr_o = addr_B[19:2];
//           addr_l = addr_B[1:0];
//           size   = size_B;
//           d_out  = dwr_B;
//           end
//  default: begin
//           addr_o = 18'hxxx;
//           addr_l = 2'hx;
//           size   = 2'hx;
//           d_out  = 32'hxxxx_xxxx;
//           end
//endcase
//
//assign d_out_o = |(write & select) ? d_out : 32'hzzzz_zzzz;
//assign d_out_o = d_out;
//assign n_write_o = !(|(write & select));
//
//always @ (*)
//case (size)
//  2'h0:    case (addr_l)
//             2'h0: n_bytes_o = 4'b1110;
//             2'h1: n_bytes_o = 4'b1101;
//             2'h2: n_bytes_o = 4'b1011;
//             2'h3: n_bytes_o = 4'b0111;
//           endcase
//  2'h1:    n_bytes_o = addr_l[1] ? 4'b0011 : 4'b1100;
//  2'h2:    n_bytes_o = 4'b0000;
//  default: n_bytes_o = 4'b1111;
//endcase
//
//endmodule	// sram_ctrl

/*----------------------------------------------------------------------------*/

/*============================================================================*/
