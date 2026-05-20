/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
/* Plug-in arithmetic block.  This version is certainly not optimised!        */

module multiply(input  wire        clk,
                input  wire        reset,

                input  wire        start_i,
                output wire        busy_o,         /* was reg changes to wire */
                input  wire  [2:0] op_code_i,
                input  wire [31:0] op_1_i,
                input  wire [31:0] op_2_i,
                output reg  [31:0] result_o);

reg  [64:0] op1;
wire [64:0] minus_op1;
wire signed [32:0] op2_in;          /* Shift input: convenient for multiplier */
reg  signed [32:0] op2;
reg  [63:0] result;
wire [32:0] div_sub;
reg  [5:0] tick;                                     /* Cycle counter for FSM */

always @ (posedge clk)
if (reset) tick <= 6'h00;
else
if (start_i)
  if (op_code_i[2] == 1'b0) tick <= 6'h11;
  else                      tick <= 6'h21;
else if (tick != 6'h00) tick <= tick - 6'h01;

assign busy_o = start_i || (tick != 6'h00);

assign minus_op1 = ~{{33{op_1_i[31]}}, op_1_i} + 1;
assign op2_in    = {op_2_i, 1'b0};

always @ (posedge clk)
if (start_i)
  begin
  result <= 64'h0000_0000_0000_0000;
  casex (op_code_i)
    3'b000: begin                                                      /* MUL */
            op1 <= {{33{1'b0}}, op_1_i};
            op2 <= op2_in;
            end
    3'b001: begin                                                     /* MULH */
            if (op_2_i[31])
              begin
//            op1 <= {{33{!op_1_i[31]}}, -op_1_i};	// MINT? OK so far ***
              op1 <= minus_op1;
              op2 <= -op2_in;
              end
            else
              begin
              op1 <= {{33{op_1_i[31]}}, op_1_i};
              op2 <= op2_in;
              end
            end
    3'b010: begin                                                   /* MULHSU */
            op1 <= {{33{op_1_i[31]}}, op_1_i};
            op2 <= op2_in;
            end
    3'b011: begin                                                    /* MULHU */
            op1 <= {{33{1'b0}}, op_1_i};
            op2 <= op2_in;
            end
    3'b1x0: begin                                                  /* DIV/REM */
            if (op_1_i[31] == 1'b0) op1 <= {{33{1'b0}}, op_1_i};
            else                    op1 <= minus_op1;
            if (op_2_i[31] == 1'b0) op2 <=  op2_in;
            else                    op2 <= -op2_in;
            end
    3'b1x1: begin                                                /* DIVU/REMU */
            op1 <= {{33{1'b0}}, op_1_i};
            op2 <= op2_in;
            end
  endcase
  end
else
  if (tick > 0)
    if (op_code_i[2] == 1'b0)              /* 2-bit modified Booth multiplier */
      begin
      case (op2[2:0])
        3'b100:         result <= result - (op1[63:0] << 1);
        3'b101, 3'b110: result <= result -  op1[63:0];
        3'b001, 3'b010: result <= result +  op1[63:0];
        3'b011:         result <= result + (op1[63:0] << 1);
      endcase

      op1 <= op1 << 2;
      op2 <= op2 >> 2;
      end
    else
      begin                                                  /* Naive divider */
      if (div_sub[32] == 1'b0) op1 <= {div_sub, op1[31:0], 1'b1};
      else                     op1 <= op1 << 1;
      end

assign div_sub = op1[64:32] - {1'b0, op2[32:1]};
assign sign = (op_1_i[31] != op_2_i[31]) && !op_code_i[0];

always @ (*)
casex (op_code_i)
  3'b000:  result_o = result[31:0];
  3'b0xx:  result_o = result[63:32];
  3'b100:  result_o = sign ? -op1[31:0] : op1[31:0];
  3'b101:  result_o = op1[31:0];
  3'b110:  result_o = op_1_i[31] ? -op1[64:33] : op1[64:33];
  3'b111:  result_o = op1[64:33]; /* There was an extra shift so 1 bit higher */
  default: result_o = 32'hxxxx_xxxx;
endcase

endmodule	// multiply

/*----------------------------------------------------------------------------*/
