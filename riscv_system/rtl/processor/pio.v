/*----------------------------------------------------------------------------*/
/* Instantiated in both subsystems although now superfluous in master         */

module pio (input  wire        clk,
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
//            output wire [31:0] data_out,

            input  wire [31:0] pin_in,
            output wire [31:0] pin_out,
            output wire [31:0] pin_en);

assign stall_o   =    cs_i   && 1'b0;
assign abort_v_o = {3{cs_i}} && 3'h0;

reg  [1:0] mux_addr;
reg [31:0] reg_data, reg_dir;

always @ (posedge clk)                                     /* Register writes */
if (reset)
  begin
  reg_data <= 32'h0000_0000;
  reg_dir  <= 32'hFFFF_FFFF;
  end
else
  if (cs_i && write_i)
    case (address_i[3:2])
      2'h0: reg_data <= data_in;
      2'h1: reg_dir  <= data_in;
      2'h2: reg_data <= reg_data & ~data_in;
      2'h3: reg_data <= reg_data |  data_in;
    endcase
 
always @ (posedge clk)
if (cs_i && read_i) mux_addr <= address_i[3:2];  /* Latch for read next cycle */

always @ (*)
case (mux_addr)
  2'h0: data_out = pin_in;
  2'h1: data_out = reg_dir;
  2'h2: data_out = reg_data;
  2'h3: data_out = reg_data;
  default: data_out = 32'h0000_0000;
endcase

assign pin_out =  reg_data;
assign pin_en  = ~reg_dir;

endmodule	// pio

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/