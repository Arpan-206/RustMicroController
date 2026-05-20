/*----------------------------------------------------------------------------*/

module execute(input  wire        clk,
               input  wire        reset,
               input  wire        forward_en_i,       /* Configuration switch */

               input  wire        valid_in_i,                /* Input control */
               output wire        ready_in_o,

               input  wire [31:0] pc_i,
               input  wire  [1:0] mode_i,
               input  wire        col_i,
               input  wire        step_i,
               input  wire  [1:0] rd_src_i,  /* Stage (if any) where Rd valid */
               input  wire  [1:0] rs1_src_i,       /* Place to find Rs1 value */
               input  wire [31:0] rs1_r_i,      /* Raw Rs1 from register file */
               input  wire  [1:0] rs2_src_i,       /* Place to find Rs2 value */
               input  wire [31:0] rs2_r_i,      /* Raw Rs2 from register file */
               input  wire        use_imm_i,          /* Immediate to be used */
               input  wire [31:0] imm_i,                   /* Immediate value */

               input  wire [31:0] instr_i,           /* Used in illegal traps */
               input  wire  [2:0] funct3_i,
               input  wire        mem_ld_i,               /* Load instruction */
               input  wire        mem_st_i,              /* Store instruction */
               input  wire        auipc_i,
               input  wire  [1:0] csr_op_i,
               input  wire        sys_op_i,
               input  wire  [5:0] trap_op_i,
               input  wire  [4:0] alu_op_i,
               input  wire  [1:0] branch_i,
               input  wire  [4:0] a_rd_i,

               output wire        csr_rd_o,
               output wire        csr_wr_o,
               output wire        csr_trap_o,
               output wire        csr_ret_o,
               output reg  [31:0] csr_data_in_o,

               output reg   [1:0] ex_status_o,/* Availability of contained Rd */
               output wire  [4:0] ex_rd_o,        /* Identity of contained Rd */
               input  wire [31:0] mem_ex_rd_i,/*Value from early memory stage */
               input  wire [31:0] rd_mem_ld_i,     /* Value from memory stage */

               output reg   [1:0] epc_sel_o,
               output reg   [5:0] trap_cause_o,
               output reg  [31:0] trap_val_o,
               input  wire [31:0] trap_vector_i,
               input  wire [31:0] status_i,
               input  wire  [1:0] new_mode_i,

               output reg         valid_out_o,              /* Output control */
               input  wire        ready_out_i,
               input  wire  [2:0] abort_i,       /* Indicator from mem. stage */
               input  wire        watchpoint_i,
               output reg         abort_L_o,         /* Busy completing abort */

               output reg  [31:0] dbg_instr_o,  /* For debugging/display only */
               output wire [31:0] dbg_pc_o, /* For debugging and display only */
               output reg   [1:0] mode_o,
               output reg         step_o,
               output reg   [2:0] funct3_o,
               output reg  [31:0] result_o,                     /* ALU output */
               output reg   [1:0] rd_src_o,     /* Where (any) Rd is produced */
               output reg         mem_ld_o,     /* Instruction for next stage */
               output reg         mem_st_o,     /* Instruction for next stage */
               output reg         csr_read_o,      /* CSR data to incorporate */
               output reg   [4:0] a_rd_o,            /* Identity of output Rd */
               output reg  [31:0] store_data_o,              /* What it says! */
               output reg         jump_o,           /* Request to load new PC */
               output reg  [31:0] target_o,                         /* New PC */
               output reg   [1:0] target_mode_o,   /* New mode (occasionally) */
               output reg         target_wp_o,    /* 'Branch' is a watchpoint */
               output reg         exec_done_o);/* Valid but stops in pipeline */

wire        stall;                               /* Do not proceed this cycle */
wire        kill;                                    /* Do not proceed at all */
wire        valid;
wire        valid_result;       /* Instruction will generate an Rd or address */

reg         colour;  /* Local instruction colour; check incoming against this */
wire [31:0] imm_2;   /* Immediates when truncated for shifts (SUB irrelevant) */
wire [31:0] op1;                                         /* First ALU operand */
wire [31:0] op2;                                        /* Second ALU operand */
wire [31:0] to_csr;                                       /* CSR data operand */
wire signed [31:0] op1_signed;                                       /* Alias */
reg         eq, ge, geu;                                /* Comparator outputs */
reg         branch_taken;
reg  [31:0] rs1, rs2, alu_out;
wire [31:0] link_pc;
wire        ret;
wire        memory_op;                                       /* Load or store */
reg  [31:0] pc_L;
wire        abort;
reg   [2:0] abort_cause;
reg         watchpoint_L;          /* Hold watchpoint to override everything! */
wire        abt_wtch;                  /* Either abort or watchpoint incoming */
wire        abt_wtch_L;         /* Either abort or watchpoint as latched here */
reg         new_input;
wire        mul, mul_busy;
wire [31:0] mul_result;

always @ (posedge clk)                             /* Monostable on new input */
begin
if (reset) new_input <= 1'b0;     /* Active if maybe something new to look at */
else       new_input <= ready_in_o;             /* Inactive after first cycle */
end                                    /* Can trigger FSMs e.g. MUL, DIV etc. */

assign memory_op = mem_ld_i || mem_st_i;
assign mul = (alu_op_i[4:3] == 2'b11);                       /* MUL/DIV codes */
                                                            /* Load x0 = hint */
assign abort = (abort_i != `ABORT_NONE) && !watchpoint_i;

assign stall = mul_busy;                      /* Stall whilst FSM(s) are busy */
assign abt_wtch = abort || watchpoint_i;       /* Signal 'exception' starting */
assign abt_wtch_L = abort_L_o || watchpoint_L;          /* Signal 'exception' */
assign kill = (col_i != colour) || abt_wtch || abt_wtch_L;
                                  /* Including no CSR changes from exceptions */

assign valid = valid_in_i && !stall && !kill;
assign valid_result = valid && ((rd_src_i != `RD_NONE) || memory_op);
					// Double-check CSR dests. (etc.) ****
//               || sys_op_i || |csr_op_i);	// This last a bit bodgy *****
assign ready_in_o = !stall && ready_out_i;

always @ (*)        /* Count MRET etc. but not ECALL.  Spec. seems to say so. */
if (sys_op_i && (trap_op_i[4] == 1'b0)) exec_done_o = 1'b0;
else exec_done_o = valid && ((rd_src_i == `RD_NONE) && !memory_op);
			// Beware - check CSR ops esp. Rd = x0 *****

always @ (*)                        /* Input register forwarding multiplexers */
begin

case (rs1_src_i)
  `SRC_REG:  rs1 = rs1_r_i;         /* Registers forward from writeback stage */
//`SRC_EXEC: rs1 = result_o;                         /* Local forwarding path */
  `SRC_EXEC: rs1 = mem_ex_rd_i;                  /* Non-local forwarding path */
  `SRC_MEM:  rs1 = rd_mem_ld_i;
  default:   rs1 = 32'hxxxx_xxxx;
endcase

case (rs2_src_i)
  `SRC_REG:  rs2 = rs2_r_i;
//`SRC_EXEC: rs2 = result_o;                         /* Local forwarding path */
  `SRC_EXEC: rs2 = mem_ex_rd_i;                  /* Non-local forwarding path */
  `SRC_MEM:  rs2 = rd_mem_ld_i;
  default:   rs2 = 32'hxxxx_xxxx;
endcase

end

always @ (*)                /* Determine if Rd available or what - and output */
if (!valid || (rd_src_i == `RD_NONE)) ex_status_o = `RD_EMPTY;
else
  if (forward_en_i)
    begin
    if ((rd_src_i == `RD_LOAD)) ex_status_o = `RD_PASSING;
    else
      if (stall) ex_status_o = `RD_AWAITED;
      else       ex_status_o = `RD_READY;
    end
  else ex_status_o = `RD_PASSING;   /* Disable forwarding: return `RD_PASSING */

assign ex_rd_o = a_rd_i;            /* The register ID which may be forwarded */

assign op1   = auipc_i   ? pc_i  : rs1;
assign imm_2 = (alu_op_i[4:3]==2'b01) ? {27'h00,imm_i[4:0]} : imm_i;/* Shifts */
assign op2   = use_imm_i ? imm_2 : rs2;        /* Note: Bcc doesn't "use_imm" */
                /* Note: hits 'SUB' included but never uses immediate operand */

assign op1_signed = op1;                                     /* Alias for SRA */

always @ (*)
casex (alu_op_i)
  5'b00_000: alu_out = op1  + op2;	// unfinished? *****
  5'b01_000: alu_out = op1  - op2;
  5'b00_001: alu_out = op1 << op2;
  5'b00_010: alu_out = op1  - op2;
  5'b00_011: alu_out = op1  - op2;
  5'b00_100: alu_out = op1  ^ op2;
  5'b00_101: alu_out = op1 >> op2;
  5'b01_101: alu_out = op1_signed >>> op2;
  5'b00_110: alu_out = op1  | op2;
  5'b00_111: alu_out = op1  & op2;
  5'b10_01x: alu_out =        op2;                /* Unused Bcc codes for LUI */
  5'b10_xxx: alu_out = op1  - op2;
  5'b11_xxx: alu_out = mul_result;                           /* MUL/DIV codes */
  default:   alu_out = 32'hxxxx_xxxx;
endcase

always @ (*)                                                   /* Comparators */
begin
eq = (alu_out == 32'h0000_0000);
ge = (!op1[31]&&op2[31]) || (!op1[31]&&!alu_out[31]) || (op2[31]&&!alu_out[31]);
geu= (op1[31]&&!op2[31]) || (op1[31]&&!alu_out[31]) || (!op2[31]&&!alu_out[31]);

if (abt_wtch_L) branch_taken = 1'b1;
else
  if (valid)
    begin
    if (sys_op_i) branch_taken = 1'b1;           /* ECALL, EBREAK, abort etc. */
    else
      case (branch_i)                           /* Sort out branch conditions */
        `BR_AL:  branch_taken = 1'b1;
        `BR_CC:  case (funct3_i)
                   3'b000:  branch_taken =  eq;
                   3'b001:  branch_taken = !eq;
                   3'b100:  branch_taken = !ge;
                   3'b101:  branch_taken =  ge;
                   3'b110:  branch_taken = !geu;
                   3'b111:  branch_taken =  geu;
                   default: branch_taken = 1'b0;
                 endcase
        `BR_REG: branch_taken = 1'b1;
        default: branch_taken = 1'b0;
      endcase
    end
  else branch_taken = 1'b0;                  /* Not performing this operation */

end

assign csr_rd_o = valid && ready_out_i && csr_op_i[1]; // Check readiness ****
assign csr_wr_o = valid && ready_out_i && csr_op_i[0]; // Want exactly 1 cycle

assign to_csr = funct3_i[2] ? {27'h000000, imm_i[16:12]} : rs1;
always @ (*)
if (abort_L_o)     csr_data_in_o = pc_L;     /* Recover local PC out on abort */
else if (sys_op_i) csr_data_in_o = {pc_i[31:2], 2'h0};
else               csr_data_in_o = to_csr;

assign csr_trap_o = (valid && ready_out_i && sys_op_i && !trap_op_i[4])
                  || abort_L_o;
//assign csr_ret_o  = (valid && ready_out_i && sys_op_i &&  trap_op_i[4])
assign csr_ret_o  = (valid && ready_out_i && ret)
                  && !abort_L_o;

always @ (posedge clk)		// Check timing/stalling(?), enables *****
if (reset)
  begin
  colour <= 1'b0;
  jump_o <= 1'b0;
  end
else if (ready_in_o || abt_wtch_L) // Control/timing may benefit from review ****
  begin
  jump_o <= branch_taken;
  if (branch_taken) colour <= !colour;
  end

assign ret = (sys_op_i && (trap_op_i[4] == 1'b1));

always @ (*)
begin
if (ret)
  begin
  case (trap_op_i)
    `TRAP_URET: epc_sel_o = 2'b00;	// Copy from instr/trap_code ?? ****
    `TRAP_SRET: epc_sel_o = 2'b01;
    `TRAP_MRET: epc_sel_o = 2'b11;
    default:    epc_sel_o = 2'bxx;
  endcase
  end
else epc_sel_o = 2'bxx;
end

always @ (*)
begin
if (!abort_L_o) trap_cause_o = trap_op_i;
else
  case(abort_cause)
    `ABORT_LD_ALGN: trap_cause_o = `TRAP_LD_ALGN;
    `ABORT_LD_ACC:  trap_cause_o = `TRAP_LD_ACC;
    `ABORT_LD_PAGE: trap_cause_o = `TRAP_LD_PAGE;
    `ABORT_ST_ALGN: trap_cause_o = `TRAP_ST_ALGN;
    `ABORT_ST_ACC:  trap_cause_o = `TRAP_ST_ACC;
    `ABORT_ST_PAGE: trap_cause_o = `TRAP_ST_PAGE;
    default:        trap_cause_o = trap_op_i;
  endcase

if (abort_L_o) trap_val_o = result_o;               /* Address for data abort */
else if (trap_op_i == `TRAP_ILLEGAL)
             trap_val_o = instr_i;                 /* Instruction for illegal */
else         trap_val_o = pc_i;                              /* PC for others */

end

always @ (posedge clk)
begin
if      (watchpoint_L)          target_o <= pc_L;
else if (sys_op_i || abort_L_o) target_o <= trap_vector_i;
else
  case (branch_i)
    `BR_AL:  target_o <= pc_i + imm_i;                                 /* JAL */
    `BR_CC:  target_o <= pc_i + imm_i;                                 /* Bcc */
    `BR_REG: target_o <= rs1  + imm_i;                                /* JALR */
  endcase

if (abt_wtch_L)
  target_mode_o <= new_mode_i;/* Next instruction can't have changed mode yet */
else
  if (sys_op_i)
    if (ret)
      case (trap_op_i)	// Take current mode into consideration too *****
        `TRAP_URET: target_mode_o <= 2'b00;
        `TRAP_SRET: target_mode_o <= {1'b0, status_i[8]};
        `TRAP_MRET: target_mode_o <= status_i[12:11];
        default:    target_mode_o <= 2'b00;		// Guess *****
      endcase
    else target_mode_o <= new_mode_i;                       /* Trap operation */
  else   target_mode_o <= mode_i;		// Usually *****
end

assign link_pc = {(pc_i[31:2] + 30'h0000_0001), 2'h0};	// Suppress? ****

always @ (posedge clk)
begin
abort_L_o    <= abort;                         /* Save to override next cycle */
abort_cause  <= abort_i;
watchpoint_L <= watchpoint_i;
target_wp_o  <= watchpoint_L;      /* Delayed to match time for trap CSR read */
end

always @ (posedge clk)
begin
if (reset || abort || watchpoint_i) valid_out_o <= 1'b0; /* Kill o/p if abort */
else if (ready_out_i) valid_out_o <= valid_result;

if (valid_result && ready_out_i)
  begin
  dbg_instr_o <= instr_i;                   /* For debugging and display only */
  pc_L        <= pc_i;
  mode_o      <= status_i[17] ? status_i[12:11] : mode_i;             /* MPRV */
  step_o      <= step_i;
  funct3_o    <= funct3_i;
  rd_src_o    <= rd_src_i;
  mem_ld_o    <= mem_ld_i;
  mem_st_o    <= mem_st_i;
  csr_read_o  <= csr_op_i[1];                        /* Writes are dealt with */
  a_rd_o      <= a_rd_i;
  if ((rd_src_i != `RD_NONE) || |csr_op_i) // CSR could forward inside exec.****
    begin
    if ((branch_i==`BR_AL) || (branch_i==`BR_REG)) result_o <= link_pc;/*Link */
    else
      case (alu_op_i)
        5'b00_010: result_o <= ge  ? 32'h0000_0000 : 32'h0000_0001;   /* SLT  */
        5'b00_011: result_o <= geu ? 32'h0000_0000 : 32'h0000_0001;   /* SLTU */
        default:   result_o <= alu_out;
      endcase
    end
  else result_o <= alu_out;
  if (mem_st_i) store_data_o <= rs2;              /* Avoid spurious switching */
  end
end

assign dbg_pc_o = pc_L; /* PC needed internally for aborts; output not needed */

multiply multiply(.clk(clk),                 /* Instantiate multiplier module */
                  .reset(reset || abt_wtch),

                  .start_i(new_input && valid_in_i && mul && !kill),
                  .busy_o(mul_busy),

                  .op_code_i(alu_op_i[2:0]),
                  .op_1_i(op1),
                  .op_2_i(op2),
                  .result_o(mul_result));

endmodule	// execute

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
