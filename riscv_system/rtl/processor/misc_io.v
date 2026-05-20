/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
/* Miscellaneous slave only I/O: system timer and I/O pin selector (++?)      */

module control_io(input  wire        clk,
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

                  output reg  [31:0] pin_fn_o,
                  output reg   [7:0] pin_LED_o,
                  output reg         pin_LCD_o, 
                  output reg         pin_LCD_BL_o,
                  output reg  [63:0] mtime,
                  output wire        mtimer_irq_o,
                  output wire        halt_o);           /* Stop own execution */

reg  [63:0] mtimecmp;
wire        writing;
reg   [7:0] addr;

initial pin_fn_o = 32'h0000_0000;
initial pin_LED_o = 8'h00;

assign stall_o   =    cs_i   && 1'b0;
assign abort_v_o = {3{cs_i}} && 3'h0;

// Note : if read needed devices need to latch addr/read data for output @@@

assign writing = cs_i && write_i;

always @ (posedge clk)
if (reset)
  begin
  pin_fn_o  <= 32'h0000_0000;
  pin_LED_o <=  8'h00;
  mtime     <= 64'h0000_0000_0000_0000;
  mtimecmp  <= 64'h0000_0000_0000_0000;
  end
else
  begin
  if (writing)
    case (address_i[7:2])
      6'h02: pin_fn_o        <= data_in;
      6'h03: begin 
                    pin_LED_o <= data_in[7:0];
                    pin_LCD_o <= data_in[8];  
                    pin_LCD_BL_o <= data_in[9]; 
             end
      6'h06: mtimecmp[31:0]  <= data_in;
      6'h07: mtimecmp[63:32] <= data_in;
    endcase

  if (writing && address_i[7:3] == 5'h02)
    if (address_i[2] == 1'b0) mtime[31:0]  <= data_in;
    else                      mtime[63:32] <= data_in;
  else                        mtime <= mtime + 64'h0000_0000_0000_0001;
// Wall-clock time maybe should be subject to ctrl_run, ctrl_step etc(?) @@@
  end					// Also reset w.r.t. subsystem @@@

assign halt_o = (writing && address_i[7:2] == 6'h00);

always @ (posedge clk)                                    /* Address bit hold */
if (read_i) addr <= address_i[7:0];                   /* Delay for next cycle */

always @ (*)
case (addr[7:2])
  6'h00: data_out = `VERSION_ID;
  6'h01: data_out = `CLOCK_FREQUENCY;
  6'h02: data_out = pin_fn_o;
  6'h03: data_out = {22'h0 , pin_LCD_BL_o, pin_LCD_o, pin_LED_o};
  6'h04: data_out = mtime[31:0];
  6'h05: data_out = mtime[63:32];
  6'h06: data_out = mtimecmp[31:0];
  6'h07: data_out = mtimecmp[63:32];
  default: data_out = 32'h0000_0000;
endcase

assign mtimer_irq_o = (mtime >= mtimecmp);

endmodule  // control_io

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
