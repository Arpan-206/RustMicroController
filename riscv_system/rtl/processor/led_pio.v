/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
/* Custom LED interface - slave                                               */

module led_pio (input  wire        clk,
                input  wire        reset,
                input  wire        cs_i,
                input  wire        read_i,
                input  wire        write_i,
                input  wire [31:0] address_i,
                input  wire  [1:0] size_i,
                input  wire  [1:0] mode_i,
                output wire        stall_o,
                output wire  [2:0] abort_v_o,
                input  wire [31:0] data_in,
                output reg  [31:0] data_out,
                input  wire  [3:0] sw_i,
                output reg   [7:0] led_o);

initial led_o = 8'h0;

assign stall_o   =    cs_i   && 1'b0;
assign abort_v_o = {3{cs_i}} && 3'h0;

// Note : if read needed devices need to latch addr/read data for output @@@

always @ (posedge clk)
if (reset)
  led_o <= 8'h00;	// Removed 0xa5 
else
  if (cs_i && write_i)
    led_o <= data_in[7:0];
 
always @ (*) data_out = {20'h0, ~sw_i, led_o};
                                  /* Address is don't care so no need to hold */

endmodule  // led_pio

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
