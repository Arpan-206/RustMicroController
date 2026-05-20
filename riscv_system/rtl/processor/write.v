/*----------------------------------------------------------------------------*/
/* Data writeback, including load data justification & sign extension.        */

module write(input  wire        clk,
             input  wire        reset,

             input  wire  [1:0] mem_A_i,    /* Address low, for justification */
             input  wire  [2:0] mem_ext_i,   /* Load sign/zero extension code */
             input  wire  [1:0] source_i,      /* Which input bus is relevant */
             input  wire [31:0] alu_data_i,
             input  wire [31:0] load_data_i,
             output reg  [31:0] data_o,          /* To registers & forwarding */

             input  wire        valid_in_i,
             output wire        ready_in_o,
             input  wire  [1:0] rd_src_i,	// Almost redundant? but still
						// need a 'go' signal *****
             input  wire  [4:0] a_rd, 
             output wire        wr_rd);

reg  [31:0] justified_data;
reg  [31:0] load_data;

assign ready_in_o = 1'b1;                           /* Writeback never stalls */

always @ (*)    /* First, combinatorial block to justify/extend loaded value. */
begin

case (mem_A_i)                                     /* Load data byte rotation */
  2'b00:   justified_data = load_data_i;
  2'b01:   justified_data = {load_data_i[7:0],  load_data_i[31:8]};
  2'b10:   justified_data = {load_data_i[15:0], load_data_i[31:16]};
  2'b11:   justified_data = {load_data_i[23:0], load_data_i[31:24]};
  default: justified_data = 32'hxxxx_xxxx;
endcase

case (mem_ext_i)                             /* Load data sign/zero extension */
  3'b000:  load_data = {{24{justified_data[7]}},  justified_data[7:0]};
  3'b001:  load_data = {{16{justified_data[15]}}, justified_data[15:0]};
  3'b010:  load_data =                            justified_data;
  3'b100:  load_data = {24'h000000,               justified_data[7:0]};
  3'b101:  load_data = {16'h0000,                 justified_data[15:0]};
  3'b110:  load_data =                            justified_data;      /* LWU */
  default: load_data = 32'hxxxx_xxxx;
endcase

end

always @ (*)                                          /* Result data selector */
case (source_i)				// Could reduce to 1 wire? *****
  `RD_EXEC: data_o = alu_data_i;
  `RD_LOAD: data_o = load_data;
   default: data_o = 2'bxx;
endcase

assign wr_rd = valid_in_i && (rd_src_i != `RD_NONE);   /* Enable register op. */

endmodule	// write


