/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
/* Illegal instruction detector: nasty enough to be worth abstracting!        */

module illegal(input  wire [31:0] instruction_i,
               input  wire  [1:0] mode_i,
               input  wire [31:0] isa_i,
               input  wire  [1:0] csr_op_i,
               input  wire        ext_a_i,
               input  wire        ext_f_i,
               input  wire        ext_m_i,
               output wire        illegal_o);

wire [6:0] instr7;
reg        csr_trap;

assign instr7 = instruction_i[6:0];

always @ (*)
if (csr_op_i != 2'b00)
  begin
  if ((instruction_i[31:30] == 2'b11) && (csr_op_i[0] == 1'b1)) csr_trap = 1'b1;
  else csr_trap = mode_i < instruction_i[29:28];
  // Traps for non-existent CSRs etc.			******
  end
else csr_trap = 1'b0;

assign illegal_o = (instruction_i[15:0] == 16'h0000)
                || (instruction_i[15:0] == 16'hFFFF)
                || ((instruction_i[1:0] != 2'b11) && !isa_i[2])
                || (ext_m_i && !isa_i[12])
                || (ext_f_i && !isa_i[5])	// Only 'F' here ***
                || (ext_a_i && !isa_i[0])
                || csr_trap;

endmodule	// illegal

/*----------------------------------------------------------------------------*/
