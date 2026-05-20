/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
/* Interrupt controller used in master subsystem                              */

module interrupt_ctrl (input  wire        clk,
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

                       input  wire [31:0] ireq_i,
                       output wire        ireq_o);

reg [31:0] reg_ien;
reg  [3:0] addr;

reg [31:0] aaa, bbb;
initial aaa = 32'h33333333;

assign stall_o   =    cs_i   && 1'b0;
assign abort_v_o = {3{cs_i}} && 3'h0;

always @ (posedge clk)                                     /* Register writes */
if (reset)
  begin
  reg_ien <= 32'h0000_1234;
  end
else
  if (cs_i  && write_i)
    case (address_i[3:2])
      2'h1: reg_ien <= data_in;
      2'h2: aaa <= data_in;
      2'h3: bbb <= data_in;
    endcase

always @ (posedge clk)                                    /* Address bit hold */
if (read_i) addr <= address_i[3:0];                   /* Delay for next cycle */

always @ (*)                                                /* Register reads */
case (addr[3:2])
  2'h0:    data_out = ireq_i;
  2'h1:    data_out = reg_ien;
  2'h2:    data_out = aaa;
  2'h3:    data_out = bbb;
  default: data_out = 32'hxxxx_xxxx;
endcase

assign ireq_o = |(ireq_i & reg_ien);

endmodule	// interrupt_ctrl

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
