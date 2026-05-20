/*============================================================================*/

module io (input  wire        clk,
           input  wire        reset,

           input  wire        cs_i,
           input  wire [31:0] address_i,
           input  wire  [1:0] mode_i,
           input  wire  [1:0] size_i,
           output wire        stall_o,
           output wire  [2:0] abort_v_o,
           input  wire [31:0] data_in,
           output reg  [31:0] data_out,
           input  wire        read_i,
           input  wire        write_i,

           output reg  [63:0] mtime,
           output wire        mtimer_irq,

           output wire [31:0] io_out,
           input  wire        fifo_full,
           input  wire        fifo_empty,
           output wire        fifo_wr,
           output wire  [7:0] fifo_d_out,
           output wire        fifo_rd,
           input  wire  [7:0] fifo_d_in,

           output wire        ctrl_x_alu_fwd,          /* Slave configuration */
           output wire        ctrl_x_mem_fwd,          /* Slave configuration */

           output wire        ctrl_x_proc_reset,       /* Processor reset */
           output wire        ctrl_x_periph_reset,     /* Periph    reset */

           output wire        ctrl_x_run,
           output wire        ctrl_x_step,
           input  wire        ctrl_x_busy,
           input  wire        ctrl_x_broken,
           output wire        ctrl_x_we,
           output wire        ctrl_x_re,
           output wire  [1:0] ctrl_x_space,
           output wire [31:0] ctrl_x_addr,
           output wire  [1:0] ctrl_x_size,
           output wire [31:0] ctrl_x_data_wr,
           input  wire [31:0] ctrl_x_data_rd,
           input  wire        ctrl_x_wait);


reg  waited;
wire wait_extra = ctrl_x_re && !ctrl_x_wait && !waited;
always @ (posedge clk) waited <= wait_extra;

//assign stall_o =    cs_i   && 1'b0;
assign stall_o   =    cs_i   && (ctrl_x_wait || wait_extra);
assign abort_v_o = {3{cs_i}} && 3'h0;

reg  [63:0] mtimecmp;

wire        remote;
wire        conn, regg, memm, csrr;	// Spelled to aid source-searching @@@

reg  [31:0] reg_0, reg_1;
reg  [31:0] reg_test;            /* Used for (e.g.) test interrupt generation */
wire [31:0] reg_0_rd;

always @ (posedge clk)                                     /* Register writes */
if (reset)
  begin
  reg_0 <= 32'h0000_0001;                          /* Control/status register */
  reg_1 <= 32'h0000_0000;                                          /* Address */
  reg_test <= 32'h0000_0000;
  mtime    <= 64'h0000_0000_0000_0000;
  mtimecmp <= 64'h0000_0000_0000_0000;
  end
else
  begin
  if (cs_i && write_i)
    casex (address_i[23:2])
      22'h00_0000: reg_0 <= data_in;
      22'h00_0001: reg_1 <= data_in;		// Address register @@@
      22'h00_0004: reg_0 <= reg_0 & ~data_in;
      22'h00_0005: reg_0 <= reg_0 |  data_in;
      22'h00_0007: reg_test <= data_in;
      22'h00_000A: mtimecmp[31:0]  <= data_in;
      22'h00_000B: mtimecmp[63:32] <= data_in;
    endcase
  else
    reg_0 <= reg_0 & 32'hFFFF_FFFB;                         /* Pulse step bit */
  if (cs_i && write_i && (address_i[23:3] == 21'h00_0004))
    if (address_i[2] == 1'b0) mtime[31:0]  <= data_in;
    else                      mtime[63:32] <= data_in;
  else                        mtime <= mtime + 64'h0000_0000_0000_0001;
  end

assign mtimer_irq = mtime >= mtimecmp;

always @ (posedge clk)                                      /* Register reads */
if (cs_i && read_i)
  case (address_i[23:2])
    22'h00_0000: data_out <= reg_0_rd;
    22'h00_0001: data_out <= reg_1;/* Addr. register (high) for memory access */
    22'h00_0002: data_out <= `CLOCK_FREQUENCY;
    22'h00_0003: data_out <= ctrl_x_data_rd;		// Now redundant @@@
    22'h00_0004: data_out <= 32'h476D_694A;
    22'h00_0005: data_out <= {30'h0000_0000, fifo_full, fifo_empty};//MOVE @@@R0
    22'h00_0006: data_out <= {24'h00_0000, fifo_d_in};
    22'h00_0007: data_out <= reg_test;
    22'h00_0008: data_out <= mtime[31:0];
    22'h00_0009: data_out <= mtime[63:32];
    22'h00_000A: data_out <= mtimecmp[31:0];
    22'h00_000B: data_out <= mtimecmp[63:32];
    default:     data_out <= ctrl_x_data_rd;
  endcase

/* Control/status register bit functions:  0   Reset     Default on               */
/*                                                       Reset for just the       */
/*                                                       processor / not periphs  */
/*                                         1   Run       Default off              */
/*                                         2   Step      Pulsed                   */
/*                XXXXX                    3   Write     Pulsed                   */
/*                                         4   Busy      Read only                */
/*                                         5   Broken    Read only                */
/*                XXXXX                        Space     Back end addr. space     */
/*                XXXXX                   7:6  Size      Memory Space only        */
/*                XXXXX                   9:8  Space     Back end addr. space     */
/*                XXXXX                   20   Space     Full Subsystem Reset     */
/*                                                       resets processor   and   */ 
/*                                                       peripherals              */ 
/* Bits can be cleared (R4) or set (R5) writing '1's to appropriate locations     */

assign reg_0_rd = {reg_0[31:6], ctrl_x_broken, ctrl_x_busy, reg_0[3:0]};

assign conn = (address_i[23:0] >= 16'h400) && (address_i[23:0] < 16'h1000);
assign regg = (address_i[23:7]  == 17'h00020);
assign memm = (address_i[23:20] ==  4'h1);
assign csrr = (address_i[23:16] ==  8'h01);
 
assign remote = cs_i && ((address_i[7:2] == 6'h03) || conn || regg
                                                   || memm || csrr);

wire conn_watchpoints;
assign conn_watchpoints = (address_i[23:0] >= 16'h800) && (address_i[23:0] < 16'h1000);
    
assign ctrl_x_alu_fwd   = 1'b1;       /* Slave configuration */
assign ctrl_x_mem_fwd   = 1'b1;      /* Slave configuration */
                                            
assign io_out = reg_test;
assign ctrl_x_proc_reset   = reg_0[0];
assign ctrl_x_periph_reset = reg_0[20]; 

assign ctrl_x_run          = reg_0[1];	// Step:Run (share with 'step'??)  @@@
assign ctrl_x_step         = reg_0[2];                 

assign ctrl_x_space   = conn ? 2'h0 : regg ? 2'h1 : memm ? 2'h3 : csrr ? 2'h2
                                                                : 2'hx;
assign ctrl_x_addr    = memm ? {reg_1[31:20], address_i[19:0]} : 
                        regg ? {27'h0000_000, address_i[6:2]} :
                        conn_watchpoints ? { 24'h0000_01, address_i[9:2]} :
                        conn ? {24'h0000_00,  address_i[9:2]} : // anthony
                        csrr ? {20'h0000_0,   address_i[13:2]} : reg_1;
                        
assign ctrl_x_size    = memm ? size_i : 2'h2;
assign ctrl_x_data_wr = data_in;

assign fifo_wr    = (cs_i && write_i && (address_i == 32'h2000_0018));
assign fifo_d_out = data_in[7:0];

assign fifo_rd    = (cs_i &&  read_i && (address_i == 32'h20000018)); // anthony
       		  // Decode **HACKS** (x2) not yet explained: need fixing @@@

assign ctrl_x_re = remote && read_i;
assign ctrl_x_we = remote && write_i;

endmodule	// io

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
