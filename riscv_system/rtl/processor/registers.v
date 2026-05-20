/*----------------------------------------------------------------------------*/

module registers(input  wire        clk,
                 input  wire        reset,
                 input  wire        rd_rs1,
                 input  wire  [4:0] a_rs1,
                 output reg  [31:0] rs1,
                 input  wire        rd_rs2,
                 input  wire  [4:0] a_rs2,
                 output reg  [31:0] rs2,
                 input  wire        stall_reg_rd,
                 input  wire        wr_rd,
                 input  wire  [4:0] a_rd,
                 input  wire [31:0] rd);

reg [31:0] registers [1:31];

always @ (posedge clk)
begin

if (!stall_reg_rd)
  begin
  if (rd_rs1)
    if (a_rs1 == 5'h00) rs1 <= 32'h0000_0000;
    else
      if (wr_rd && (a_rs1 == a_rd)) rs1 <= rd;      /* Forward incoming value */
      else              rs1 <= registers[a_rs1];
  else                  rs1 <= 32'hxxxx_xxxx;

  if (rd_rs2)
    if (a_rs2 == 5'h00) rs2 <= 32'h0000_0000;
    else
      if (wr_rd && (a_rs2 == a_rd)) rs2 <= rd;      /* Forward incoming value */
      else              rs2 <= registers[a_rs2];
  else                  rs2 <= 32'hxxxx_xxxx;
  end

if (wr_rd && (a_rd != 5'h00)) registers[a_rd] <= rd;

end

endmodule	// registers

/*----------------------------------------------------------------------------*/
