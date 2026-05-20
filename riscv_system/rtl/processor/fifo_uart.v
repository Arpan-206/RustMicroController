/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
/* Pretend UART for slave interfaced to master FIFO connection                */

module fifo_uart (input  wire        clk,
                  input  wire        reset,

                  input  wire        cs_i,
                  input  wire        read_i,
                  input  wire        write_i,
                  input  wire [31:0] address_i,
                  input  wire  [1:0] mode_i,
                  input  wire  [1:0] size_i,
                  output wire        stall_o,
                  output wire  [2:0] abort_v_o,
                  input  wire [31:0] data_in,
                  output reg  [31:0] data_out,

                  output wire  [2:0] int_o,		// ** NEW **
//                output wire        fifo_Tx_ireq_o,	// Subsumed by int_o
//                output wire        fifo_Rx_ireq_o,	// Subsumed by int_o

//                output wire [31:0] io_out,		// Deleted
                  input  wire        fifo_full,
                  input  wire        fifo_empty,
                  output wire        fifo_wr,
                  output wire  [7:0] fifo_d_out,
                  output wire        fifo_rd,
                  input  wire  [7:0] fifo_d_in);

localparam DELAY = 8'h14;                     /* Read time to simulate serdes */

reg       mux_addr;                  /* Hold address bit for read multiplexer */
wire      writing;
wire      reading;
wire      Tx_write;		// Processor write
wire      Rx_read;		// Processor read
wire      stat_write;		// Processor write
wire      stat_read;		// Processor read

reg [7:0] Tx_timer;                        /* Impose 'serial' character delay */
reg [7:0] THR;                                /* Transmitter Holding Register */
wire      THR_empty;
wire      Tx_ld;

reg [7:0] Rx_timer;                        /* Impose 'serial' character delay */
reg [7:0] RHR;                                   /* Receiver Holding Register */
reg       RHR_full;                                   /* RHR has new contents */
reg       Rx_over, Rx_over_L;                         /* Receiver has overrun */
wire      Rx_en;                                  /* Can accept an input byte */
wire      Rx_ld;                                  /* Is reading an input byte */

reg [2:0] IE;                                            /* Interrupt enables */

assign THR_empty = (Tx_timer == 8'h00) && !fifo_full;
assign Tx_ld     = THR_empty && Tx_write;               /* Accept output byte */

always @ (posedge clk) if (Tx_ld) THR <= data_in[7:0];            /* Load THR */

always @ (posedge clk)                /* Delay to simulate serialisation time */
if (reset)           Tx_timer <= 8'h00;
else if (Tx_ld)      Tx_timer <= DELAY;                      /* Reset & count */
else if (!THR_empty && !fifo_full) Tx_timer <= Tx_timer - 8'h01;
                        /* Count down interval -- stall for backpressure (?!) */

always @ (posedge clk)              /* Delay to simulate deserialisation time */
if (reset)         Rx_timer <= 8'h00;
else if (!Rx_en)   Rx_timer <= Rx_timer - 8'h01;       /* Count down interval */
else if (RHR_full || Rx_ld) Rx_timer <= DELAY;       /* Reset & keep counting */

assign Rx_en = Rx_timer == 8'h00;                       /* Receiver receptive */
assign Rx_ld = !fifo_empty && Rx_en;                              /* Load RHR */

assign writing = cs_i && write_i;                     /* Read & write enables */
assign reading = cs_i &&  read_i;
assign Tx_write   = writing && (address_i[2] == 1'h0);
assign Rx_read    = reading && (address_i[2] == 1'h0);
assign stat_write = writing && (address_i[2] == 1'h1);
assign stat_read  = reading && (address_i[2] == 1'h1);

always @ (posedge clk) if (Rx_ld) RHR <= fifo_d_in;       /* Capture Rx  data */

always @ (posedge clk)
if (reset)             RHR_full <= 1'b0;
else if (Rx_ld)        RHR_full <= 1'b1;            /* Setting takes priority */
     else if (Rx_read) RHR_full <= 1'b0;

always @ (posedge clk)
begin
Rx_over_L <= Rx_over;  /* Delayed clear for reading (not as bad as it looks!) */
if (reset)                  Rx_over <= 1'b0;
else if (Rx_ld && RHR_full) Rx_over <= 1'b1;        /* Setting takes priority */
     else if (stat_read)    Rx_over <= 1'b0;
end

always @ (posedge clk)
if (reading) mux_addr <= address_i[2];  /* Latch for (direct) read next cycle */

initial IE = 3'h0;                            /* Okay for FPGA (& simulation) */

assign fifo_wr = (Tx_timer == 8'h01);   /* Only reachable with FIFO writeable */
assign fifo_d_out = THR;

always @ (posedge clk) if (stat_write) IE <= data_in[6:4]; /* Write int. ens. */

always @ (*)                                                /* Register reads */
case (mux_addr)
  1'h0:    data_out = {24'h00_0000, RHR};
  1'h1:    data_out = {25'h0000_000, IE, 1'b0, Rx_over_L, RHR_full, THR_empty};
  default: data_out =  32'h0000_0000;
endcase

assign fifo_rd   = Rx_ld;
assign stall_o   =    cs_i   && 1'b0;
assign abort_v_o = {3{cs_i}} && 3'h0;

assign int_o = IE & {Rx_over, RHR_full, THR_empty};/* Gate status with enables*/

endmodule	// fifo_uart

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
