/*----------------------------------------------------------------------------*/
/* Combinatorial module which justifies stored data.                          */

module store_just(input  wire  [2:0] mem_ext_i, /* Low addr for justification */
                  input  wire [31:0] data_i,
                  output reg  [31:0] data_o);

always @ (*)
case (mem_ext_i)
  3'b000:  data_o = {4{data_i[7:0]}};
  3'b001:  data_o = {2{data_i[15:0]}};
  3'b010:  data_o =    data_i[31:0];
  default: data_o = 32'hxxxx_xxxx;
endcase

endmodule	// store_just

/*----------------------------------------------------------------------------*/
