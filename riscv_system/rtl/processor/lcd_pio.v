`timescale 1ns / 1ps

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
/* Specialised interface for LCD: 4 bits control & 8 bits data?!              */
 
module lcd_pio (input  wire        clk,
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
                output reg   [3:0] lcd_ctrl_o,
                output reg   [7:0] lcd_data_o,
                input  wire  [7:0] lcd_data_i);

reg       data_sel;                                           /* Byte selects */
reg       ctrl_sel;
reg [1:0] mux_addr;

assign stall_o   =    cs_i   && 1'b0;
assign abort_v_o = {3{cs_i}} && 3'h0;

//initial lcd_ctrl_o = 4'h0;
//initial lcd_data_o = 8'h00;

always @ (*)                                        /* Byte selection/enables */
begin
data_sel = 1'b0;                                                  /* Defaults */
ctrl_sel = 1'b0;
if (size_i == 2'b00)                                                 /* Byte? */
  begin
  if      (address_i[1:0] == 2'b00) data_sel = 1'b1;           /* Legal bytes */
  else if (address_i[1:0] == 2'b01) ctrl_sel = 1'b1;
  end
else
  if (address_i[1:0] == 2'b00)                         /* Legal halfword/word */
    begin
    data_sel = 1'b1;                                              /* Defaults */
    ctrl_sel = 1'b1;
    end
end

always @ (posedge clk)
if (reset)
  begin
  lcd_ctrl_o <= 4'h0;
  lcd_data_o <= 8'h00;
  end
else
  if (cs_i && write_i)
    case (address_i[3:2])
      2'h0: begin                                               /* Write bits */
            if (ctrl_sel) lcd_ctrl_o <= data_in[11:8];
            if (data_sel) lcd_data_o <= data_in[7:0];
            end
      2'h2: begin                                               /* Clear bits */
            if (ctrl_sel) lcd_ctrl_o <= lcd_ctrl_o & ~data_in[11:8];
            if (data_sel) lcd_data_o <= lcd_data_o & ~data_in[7:0];
            end
      2'h3: begin                                               /*   Set bits */
            if (ctrl_sel) lcd_ctrl_o <= lcd_ctrl_o |  data_in[11:8];
            if (data_sel) lcd_data_o <= lcd_data_o |  data_in[7:0];
            end
    endcase
 
always @ (posedge clk)
if (read_i) mux_addr <= address_i[3:2]; /* Latch for (direct) read next cycle */

always @ (*)       /* Read data - direct from registers (cycle after request) */
case (mux_addr)
  2'h0:    data_out = {20'h0, lcd_ctrl_o, lcd_data_i};/* Reads data from pins */
  2'h2:    data_out = {20'h0, lcd_ctrl_o, lcd_data_o};    /* Reads internally */
  2'h3:    data_out = {20'h0, lcd_ctrl_o, lcd_data_o};    /* Reads internally */
  default: data_out = 32'h0000_0000;
endcase

endmodule  // lcd_pio
