/*----------------------------------------------------------------------------*/
/* Instruction decoder.  Register fields are passed to register file within   */
/* the cycle for (speculative) read(s).  Pipeline is checked for forwarding   */
/* and appropriate sources are output to steer multiplexers in next stage.    */
/* Stall cycles inserted if necessary.                                        */

module decode(input  wire clk,
              input  wire reset,

              input  wire valid_in_i,                        /* Input control */
              output wire ready_in_o,
              input  wire [31:0] pc_i,           /* Input instruction et alia */
              input  wire  [1:0] mode_i,
              input  wire        col_i,
              input  wire        step_i,
              input  wire  [2:0] abort_i,
              input  wire [31:0] interrupts_i,
              input  wire [31:0] status_i,    /* Note stall until hazard-safe */
              input  wire [31:0] isa_i,       /* Note stall until hazard-safe */
              input  wire [31:0] instr_i,                  /* The Instruction */

                     /* Next values are passed to register read in this cycle */
              output wire       want_rs1_o,                /* Request for Rs1 */
              output wire [4:0] a_rs1_o,                            /* Rs1 ID */
              output wire       want_rs2_o,                /* Request for Rs2 */
              output wire [4:0] a_rs2_o,                            /* Rs2 ID */

          /* Following inputs bring forwarding info: availability next cycle. */
              input  wire  [1:0] ex_status_i, /* Availability Rd in Ex. stage */
              input  wire  [4:0] ex_rd_i,         /* Register ID in Ex. stage */
              input  wire  [1:0] mem_status_i,/* Availability Rd in Mem stage */
              input  wire  [4:0] mem_rd_i,       /* Register ID in Mem. stage */

                    /* These outputs are latched and held for the next stage. */
              output reg        valid_out_o,                /* Output control */
              input  wire       ready_out_i,
              output wire       stall_reg_o,     /* Hold register file output */

              output reg [31:0] pc_o,                    /* PC of instruction */
              output reg  [1:0] mode_o,                /* Mode of instruction */
              output reg        col_o,
              output reg        step_o,
              output reg  [1:0] rs1_src_o,         /* Place to find Rs1 value */
              output reg  [1:0] rs2_src_o,         /* Place to find Rs2 value */
              output reg        use_imm_o,     /* Rs2 superseded by immediate */
              output reg [31:0] imm_o,                     /* Immediate value */
              output reg        auipc_o,
              output reg  [1:0] csr_op_o,
              output reg        sys_op_o,
              output reg  [5:0] trap_op_o,
              output reg [31:0] instr_o,      /* MTVAL in illegal trap (only) */
              output reg  [2:0] funct3_o,
              output reg  [4:0] alu_op_o,         /* Op. code for exec. stage */
              output reg  [1:0] branch_o,                      /* Branch type */
              output reg        mem_ld_o,               /* Memory stage loads */
              output reg        mem_st_o,              /* Memory stage stores */
              output reg  [1:0] rd_src_o,/* Stage (if any) where Rd generated */
              output reg  [4:0] a_rd_o);                        /* Rd address */

wire        valid;                         /* Going to output at end of cycle */
wire [31:0] instr;      /* Instruction currently being decoded: compact alias */
wire  [6:0] instr7;                          /* Even shorter instruction code */
wire  [2:0] funct3;
wire  [5:0] alu_op;
reg   [1:0] csr_op;                            /* Unlatched version: {Rr, Wr} */
wire        abort;
wire        illegal_x;	// Also ops. on non-existent CSRs ++ ??? *****
wire        priv;                                     /* CSR/system operation */
wire        trap;                       /* Abnormal decode: exception instead */
reg         hazard_risk;                              /* Potential for hazard */
wire        hazardous;       /* Address of CSR which may alter decoder output */
wire        hazard;     /* Prev. operation may change CSR which could be read */
wire        atomic;
wire        float;
wire        mul_div;

reg   [1:0] rd_src;                     /* Where (if anywhere) Rd is produced */
wire  [4:0] a_rs1, a_rs2, a_rd;                       /* Register identifiers */
wire  [1:0] rs1_src, rs2_src;                           /* Forwarding sources */
wire        stall;                                         /* Stall indicator */

reg         M_IE, S_IE, U_IE;          /* Mode force interrupt enable/disable */
reg  [31:0] int_mask;                       /* Mode-based vector (from above) */
reg  [31:0] ints;                    /* Interrupt inputs with enables applied */
wire        interrupt;  /* If at least one interrupt source made it this far! */
reg   [5:0] int_cause;                        /* For interrupt prioritisation */

assign instr   = instr_i;			// Alias (keep?) *****
//assign instr   = (instr_i == 'h0) ? 32'h0AB0_8093 : instr_i;		// ADDI x1 (keep?) *****
//assign instr   = (instr_i == 'h0) ? 32'h1000_0097 : (instr_i == 'h1) ? 32'h2000_0097 : instr_i;		// AIUPC *****
assign instr7  = instr[6:0];
assign funct3  = instr[14:12];
assign a_rs1   = instr[19:15];                     /* Extract register fields */
assign a_rs2   = instr[24:20];
assign a_rd    = instr[11:7];

assign atomic  =  (instr7 == 7'h27);
assign float   =  (instr7 == 7'h53);
assign mul_div = ((instr7 == 7'h33) && (instr[25] == 1'b1));

assign abort   = abort_i != `ABORT_NONE;        /* Short form for convenience */
wire illegal_z;
assign illegal_x = illegal_z && valid_in_i ;  // *******************************************

illegal illeg(.instruction_i(instr),   /* Illegal instr. detection abstracted */
                .mode_i(mode_i),
                .isa_i(isa_i),
                .csr_op_i(csr_op),
                .ext_a_i(atomic),
                .ext_f_i(float),
                .ext_m_i(mul_div),
                .illegal_o(illegal_z));

always @ (*)
begin
case (mode_i)
  2'b00: begin M_IE = 1'b1;        S_IE = 1'b1;        U_IE = status_i[0]; end
  2'b01: begin M_IE = 1'b1;        S_IE = status_i[1]; U_IE = 1'b0;        end
  2'b11: begin M_IE = status_i[3]; S_IE = 1'b0;        U_IE = 1'b0;        end
  default: begin M_IE = 1'b0;      S_IE = 1'b0;        U_IE = 1'b0;        end
endcase
int_mask = {20'h00000, {3{M_IE, 1'b0, S_IE, U_IE}}};
ints     = interrupts_i & int_mask;                /* Enabled active requests */
end

assign interrupt = |ints;
always @ (*)
if     (ints[11]) int_cause = `TRAP_INT_ME; // Delegation gets in somewhere ***
else if (ints[3]) int_cause = `TRAP_INT_MS;
else if (ints[7]) int_cause = `TRAP_INT_MT;
else if (ints[9]) int_cause = `TRAP_INT_SE;
else if (ints[1]) int_cause = `TRAP_INT_SS;
else if (ints[5]) int_cause = `TRAP_INT_ST;
else if (ints[8]) int_cause = `TRAP_INT_UE;
else if (ints[0]) int_cause = `TRAP_INT_US;
else if (ints[4]) int_cause = `TRAP_INT_UT;
else              int_cause = `TRAP_INT_US;	// Just something *****

assign priv = (instr7 == 7'h73);
assign trap = abort || illegal_x || interrupt;

assign a_rs1_o = a_rs1;              /* Alias for export (for register reads) */
assign a_rs2_o = a_rs2;

assign want_rs1_o = valid_in_i && !trap  /* Determine need for register reads */
                  && (!((instr[4:0] == 5'h17)
                     || (instr7 == 7'h6F)));    /* Ignores some CSR ops. etc. */

assign want_rs2_o = valid_in_i && !trap
             && (!((instr[4:0] == 5'h17)                    /* LUI, AUIPC (+) */
               || ((instr[6:4] == 3'h6) && (instr[2:0] == 3'h7))    /* JAL(R) */
               || ((instr[6:5] == 2'h0) && (instr[3:0] == 4'h3))));/* LD, imm */
                                                /* Ignores some CSR ops. etc. */

always @ (*)                                   /* Determine where Rd produced */
begin
if (trap) rd_src = `RD_NONE;
else
if (instr7 == 7'h03) rd_src = `RD_LOAD;
else
if (priv) rd_src = `RD_CSR;	// Small subset could be omitted: safe
else
if ((instr7 == 7'h23) || (instr7 == 7'h63)) rd_src = `RD_NONE;
else rd_src = `RD_EXEC;                                       /* Default: ALU */

if (a_rd == 5'h00) rd_src = `RD_NONE;
end


/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

wire stall_r1;
wire stall_r2;

reg_forward fwd_rs1(.want_reg_i   (want_rs1_o),
                    .a_reg_i      (a_rs1),
                    .ex_status_i  (ex_status_i),
                    .ex_rd_i      (ex_rd_i),
                    .mem_status_i (mem_status_i), 
                    .mem_rd_i     (mem_rd_i),
                    .reg_src_o    (rs1_src),
                    .stall_o      (stall_r1));

reg_forward fwd_rs2(.want_reg_i   (want_rs2_o),
                    .a_reg_i      (a_rs2),
                    .ex_status_i  (ex_status_i),
                    .ex_rd_i      (ex_rd_i),
                    .mem_status_i (mem_status_i), 
                    .mem_rd_i     (mem_rd_i),
                    .reg_src_o    (rs2_src),
                    .stall_o      (stall_r2));

assign stall = stall_r1 || stall_r2;
//stall = stall || (hazard && valid_in_i);


//always @ (*)                              /* Register forwarding check/select */
//begin
//stall = 1'b0;
//
//rs1_src = `SRC_REG;      /* Check for recent Rs1 results; default to register */
//if (want_rs1_o)
//  begin
//  if (a_rs1 != 5'h00)      /* x0 from 'reg' - never forwarded; others checked */
//    begin
//    if ((ex_status_i != `RD_EMPTY) && (a_rs1 == ex_rd_i)) /* Ex. of interest? */
//      if (ex_status_i == `RD_READY) rs1_src = `SRC_EXEC;   /* Forward path #1 */
//      else stall = stall || 1'b1;            /* Of interest but not available */
//    else
//      begin                                   /* Ex. not interesting: move on */
//      if ((mem_status_i != `RD_EMPTY) && (a_rs1 == mem_rd_i))/*Mem. interest? */
//        if (mem_status_i == `RD_READY) rs1_src = `SRC_MEM; /* Forward path #2 */
//        else stall = stall || 1'b1;          /* Of interest but not available */
//      end                                      /* Default set at top of block */
//    end
//  end
//
//rs2_src = `SRC_REG;                                  /* Same as above for Rs2 */
//if (want_rs2_o)
//  begin
//  if (a_rs2 != 5'h00)
//    begin
//    if ((ex_status_i != `RD_EMPTY) && (a_rs2 == ex_rd_i)) /* Ex. of interest? */
//      if (ex_status_i == `RD_READY) rs2_src = `SRC_EXEC;   /* Forward path #1 */
//      else stall = stall || 1'b1;            /* Of interest but not available */
//    else
//      begin
//      if ((mem_status_i != `RD_EMPTY) && (a_rs2 == mem_rd_i))/*Mem. interest? */
//        if (mem_status_i == `RD_READY) rs2_src = `SRC_MEM; /* Forward path #2 */
//        else stall = stall || 1'b1;          /* Of interest but not available */
//      end                                      /* Default set at top of block */
//    end
//  end
//
//stall = stall || (hazard && valid_in_i);
//
//end

assign valid = valid_in_i && !stall;            /* Will evaluate valid output */
assign ready_in_o = !valid_in_i || (ready_out_i && !stall);
//assign valid = valid_in_i;            // TRIAL TEST BODGES @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
//assign ready_in_o = !valid_in_i || (ready_out_i);

always @ (*)
if (priv && (funct3 != 3'b000))
  begin
  csr_op[1] = (funct3[1:0] != 2'b01) || (a_rd  != 5'h00);         /* CSR read */
  csr_op[0] = (funct3[1:0] == 2'b01) || (a_rs1 != 5'h00);        /* CSR write */
  end
else csr_op = 2'b00;

always @ (posedge clk)
begin
if (reset)
  begin
  valid_out_o <= 1'b0;
  hazard_risk <= 1'b0;                 // CLEAR IN OTHER PLACES @@@@@@@@@@
  end
else if (ready_out_i) valid_out_o <= valid;

if (valid && ready_out_i)
  begin
  auipc_o <= (instr7 == 7'h17);                         /* Ignored with traps */
  if (trap) csr_op_o <= 2'b00;                               /* Not this time */
  else      csr_op_o <= csr_op;

  if (interrupt)                          /* Interrupts highest priority (??) */
    begin
    sys_op_o  <= 1'b1;
    trap_op_o <= int_cause;
    end
  else
  if (abort)                       /* Abort higher priority than misalignment */
    begin
    sys_op_o <= 1'b1;
    case (abort_i)
      `ABORT_LD_ALGN: trap_op_o <= `TRAP_IN_ALGN;
      `ABORT_LD_ACC:  trap_op_o <= `TRAP_IN_ACC;
      `ABORT_LD_PAGE: trap_op_o <= `TRAP_IN_PAGE;
      default:        trap_op_o <= `TRAP_NONE;
    endcase
    end
  else if (illegal_x)
    begin
    sys_op_o  <= 1'b1;
    trap_op_o <= `TRAP_ILLEGAL;
    end
  else
    if (priv)
      begin
      sys_op_o <= (funct3 == 3'b000);                    /* ECALL, BREAK etc. */
	// Mode check and translate to illegal if appropriate (see module) *****
      case (instr[21:20])
        2'b00: case (mode_i)			// More to come! *****
                 2'b00:   trap_op_o <= `TRAP_U_ECALL;
                 2'b01:   trap_op_o <= `TRAP_S_ECALL;
                 2'b11:   trap_op_o <= `TRAP_M_ECALL;
                 default: trap_op_o <= `TRAP_UNKNOWN;
               endcase
        2'b01: trap_op_o <= `TRAP_BREAK;
        2'b10: case (instr[29:28])
                 2'b00:   trap_op_o <= `TRAP_URET;
                 2'b01:   trap_op_o <= `TRAP_SRET;
                 2'b11:   trap_op_o <= `TRAP_MRET;
                 default: trap_op_o <= `TRAP_UNKNOWN;
               endcase
        default: trap_op_o <= `TRAP_NONE;
      endcase
      end
    else
      begin
      sys_op_o <= 1'b0;
//    trap_op_o // Pointless to change code when infrequently used
      end

  use_imm_o <= !((instr7 == 7'h33) || (instr7 == 7'h63) || (instr7 == 7'h0F));
                /* Includes CSR addresses(?). Easier to specify what doesn't! */
                    /* Bcc excluded - imm. not for ALU (best coding??) *****  */
  case (instr7)                          /* 'sys_op' will override this field */
    7'h67:   branch_o <= `BR_REG;
    7'h6F:   branch_o <= `BR_AL;
    7'h63:   branch_o <= `BR_CC;
    default: branch_o <= `BR_NONE;
  endcase

  mem_ld_o <= (instr7 == 7'h03) && !abort;                /* Load instruction */
  mem_st_o <= (instr7 == 7'h23) && !abort;               /* Store instruction */
                       /* Accommodate aborts so op. terminates in exec. stage */

                                                       /* Immediate generator */
  casex (instr7)  // Could predicate latch opening(?) but not just use_imm*****
    7'b0x10111: imm_o <= instr & 32'hFFFF_F000;                 /* AUIPC, LUI */
    7'b1100111: imm_o <= {{20{instr[31]}}, instr[31:20]};             /* JALR */
    7'b00x0011: imm_o <= {{20{instr[31]}}, instr[31:20]};       /* Load, Imm. */
    7'b0100011: imm_o <= {{20{instr[31]}}, instr[31:25], instr[11:7]};/* Store*/
    7'b1100011: imm_o <= {{20{instr[31]}}, instr[7], instr[30:25],     /* Bcc */
                              instr[11:8], 1'b0};
    7'b1101111: imm_o <= {{12{instr[31]}}, instr[19:12],               /* JAL */
                              instr[20], instr[30:21], 1'b0};
    7'b1110011: imm_o <=  {15'h0000, instr[19:15], instr[31:20]};      /* CSR */
                      /* For CSR addresses and immediate field in case wanted */
    default:    imm_o <= 32'hxxxx_xxxx;
  endcase                   /* Note: immediates for shifts not truncated here */

                                                   /* Determine ALU operation */
    casex (instr7)				// Needs work still *****
      7'b0x0_0011: alu_op_o <= 5'h00;                     /* Load, Store: Add */
      7'b001_0011: if (instr[13:12] == 2'b01)
                     alu_op_o <= {1'b0, instr[30], funct3};         /* Shifts */
                   else
                     alu_op_o <= {2'b00, funct3};                /* Data ops. */
      7'b011_0011: if (mul_div && !illegal_x) // FSM triggered by ALU code :-/****
                     alu_op_o <= {2'b11, funct3};                  /* MUL/DIV */
                   else
                     if (instr[13:12] == 2'b01)
                       alu_op_o <= {1'b0, instr[30], funct3};       /* Shifts */
                     else
                       alu_op_o <= {instr[30], 1'b0, funct3};   /* SUB is ... */
      7'b110_0011: alu_op_o <= {2'b10, funct3};         /* ... aliased to Bcc */
      7'b001_0111: alu_op_o <= 5'h00;                                /* AUIPC */
      7'b011_0111: alu_op_o <= 5'h12;                                  /* LUI */
      default:     alu_op_o <= 5'h00;                /* Defined, safe, common */
    endcase

  pc_o      <= pc_i;   			// Could predicate on use *****
  mode_o    <= mode_i;
  col_o     <= col_i;
  step_o    <= step_i;
  rs1_src_o <= rs1_src;
  rs2_src_o <= rs2_src;
  a_rd_o    <= a_rd;
  funct3_o  <= funct3;
  rd_src_o  <= rd_src;

  hazard_risk <= !abort && hazardous;
  end

if (valid && ready_out_i) instr_o <= instr;       /* Passed for illegal traps */

end

assign stall_reg_o = !valid || !ready_out_i;

assign hazardous = (instr[31:30] != 2'b11)                       /* Writeable */
              && (((instr[27:23] == 5'b00000) && (instr[21:20] == 2'b00))
                || (instr[31:20] == 12'h301)); // Rough cut at risky writes ****

assign hazard = valid_out_o && csr_op_o[0] && hazard_risk && 0;    //****@@@@@@ FIX ME
	// Can be qualified with current op. Only Interrupts or extensions (?)

wire disp_illegal = illegal_x && valid_in_i && !abort_i;		// TEMP ****

endmodule	// decode

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
/* Module to determine if a register value is (possibly) to be forwarded and, */
/* if so, which path to take it from.                                         */

module reg_forward(input  wire       want_reg_i,          /* Register wanted? */
                   input  wire [4:0] a_reg_i,   /* Wanted register identifier */
                   input  wire [1:0] ex_status_i,/* Status of Rd in 'execute' */
                   input  wire [4:0] ex_rd_i,        /* 'execute' register ID */
                   input  wire [1:0] mem_status_i,/* Status of Rd in 'memory' */
                   input  wire [4:0] mem_rd_i,        /* 'memory' register ID */
                   output reg  [1:0] reg_src_o,           /* Chosen data path */
                   output reg        stall_o);             /* Not ready state */

always @ (*)                              /* Register forwarding check/select */
begin
if (want_reg_i && (a_reg_i != 5'h00))         /* Is forwarding a possibility? */
  if ((ex_status_i != `RD_EMPTY) && (a_reg_i == ex_rd_i)) /* Ex. of interest? */
    if (ex_status_i == `RD_READY)
      begin
      reg_src_o = `SRC_EXEC;                               /* Forward path #1 */
      stall_o = 1'b0;
      end
    else
      begin
      reg_src_o = `SRC_REG;		// Could be undefined here @@@
      stall_o = 1'b1;
      end
  else                                        /* Ex. not interesting: move on */
    if ((mem_status_i != `RD_EMPTY) && (a_reg_i == mem_rd_i))/*Mem. interest? */
      if (mem_status_i == `RD_READY)
        begin
        reg_src_o = `SRC_MEM;                              /* Forward path #2 */
        stall_o = 1'b0;
        end
      else
        begin
        reg_src_o = `SRC_REG;		// Could be undefined here @@@
        stall_o = 1'b1;
        end
    else                          /* Both forwarding paths checked and missed */
      begin
      reg_src_o = `SRC_REG;
      stall_o = 1'b0;
      end
else
  begin
  reg_src_o = `SRC_REG;                    /* Can't be undefined: includes x0 */
  stall_o = 1'b0;
  end
end

endmodule

/*============================================================================*/
