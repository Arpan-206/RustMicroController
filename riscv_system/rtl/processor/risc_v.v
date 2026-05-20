/*----------------------------------------------------------------------------*/

module risc_v(input  wire        clk,
              input  wire        reset,
              output wire [31:0] instr_address_o,    /* Instruction fetch bus */
              output wire  [1:0] instr_mode_o,
              output wire  [1:0] instr_size_o,
              output wire        instr_read_o,
              input  wire [31:0] instr_data_i,             /* Instr input bus */
              input  wire        instr_wait_i,     /* Instr memory wait state */
              input  wire  [2:0] instr_abort_i,      /* Instr memory aborting */

              output wire [31:0] data_address_o,                  /* Data bus */
              output wire  [1:0] data_mode_o,
              output wire  [1:0] data_size_o,
              output wire        data_read_o,
              output wire        data_write_o,
              input  wire [31:0] data_data_i,               /* Data input bus */
              output wire [31:0] data_data_o,              /* Data output bus */
              input  wire        data_wait_i,       /* Data memory wait state */
              input  wire  [2:0] data_abort_i,        /* Data memory aborting */
              input  wire        stop_i,                 /* Self-stop request */

              input  wire [63:0] mtime_i,                      /* System time */
              input  wire [11:0] interrupts_i,         /* Interrupts @@@      */

              input  wire        ctrl_run,/* Instruction fetch can take place */
              input  wire        ctrl_step,
              output wire        ctrl_busy,    /* Active ops. in the pipeline */
              output wire        ctrl_broken,
              input  wire        ctrl_we,       /* Write Enable to fetch unit */
              input  wire  [1:0] ctrl_space,
              input  wire [31:0] ctrl_addr,
              input  wire  [1:0] ctrl_size,
              input  wire [31:0] ctrl_data_in,	// Mode in here too? ****
              output reg  [31:0] ctrl_data_out,     /* Current register state */
              output wire        ctrl_wait,     /* Proc. needs no extra waits */

              input  wire        ex_forward_en,
              input  wire        mem_forward_en);

wire [31:0] interrupts;                      /* After masking: CSR to decoder */

wire        jump;                                              /* Load new PC */
wire [31:0] target;                                           /* New PC value */
wire  [1:0] target_mode;                                          /* New mode */
wire        target_wp;                                     /* Watchpoint trap */

wire        valid_f;                        /* Fetch has something to pass on */
wire        ready_d;                                  /* Decoder is receptive */

wire [31:0] pc_f;                               /* PC for fetched instruction */
wire  [2:0] abort_f;                            /* imem abort state (latched) */
wire  [1:0] mode_f;                            /* Mode of fetched instruction */
wire        colour_f;                           /* Current PC stream 'colour' */
wire        step_f;         /* Instruction 'stepped' - do not take watchpoint */
wire [31:0] instruction;              /*  Instruction memory (effectively IR) */

wire        want_rs1, want_rs2;    /* Register fields needed from instruction */
wire  [4:0] a_rs1, a_rs2;       /* Read register identifiers from instruction */
wire  [4:0] ex_rd, mem_rd;                /* Register ID from pipeline stages */
wire  [1:0] ex_status, mem_status;     /* Register (Rd) availability pipeline */

wire        valid_d;                      /* Decoder has something to pass on */
wire        ready_e;                                      /* ALU is receptive */
wire        stall_reg_rd;                      /* Decode stage cannot proceed */

wire [31:0] pc_d;                        /* PC for latest instruction decoder */
wire  [1:0] mode_d;                     /* Mode of latest instruction decoder */
wire        colour_d;                        /* Stream 'colour' below decoder */
wire        step_d;                      /* Just passing down through decoder */
wire  [1:0] rs1_src, rs2_src; /* Forwarding sources: 0 = reg, 1 = ex, 2 = mem */
wire [31:0] rs1, rs2;   /* Register outputs: may be overwritten by forwarding */
wire        use_imm;                   /* Immediate field replaces Rs2 to ALU */
wire [31:0] imm;                          /* Immediate value from instruction */
  /* Bus could reduce in size (21 bits?) & sign-extend (or shift) later ***** */
wire        auipc;                       /* Particular instruction identifier */
wire  [1:0] csr_op;                                 /* Operation on CSR space */
wire        sys_op_d;                                  /* Oddities like ECALL */
wire  [5:0] trap_op_d;                                      /* Exception type */
wire [31:0] instr_d;    /* Undecoded instruction: used in illegal trap (only) */
wire  [2:0] funct3_d;
wire  [4:0] alu_op;                                           /* ALU op. code */
wire  [1:0] branch;                                /* Type of branch (if any) */
wire        mem_ld_d;                                          /* Memory load */
wire        mem_st_d;                                         /* Memory store */
wire  [1:0] rd_src_d;                  /* Stage (if any) where Rd is produced */
wire  [4:0] a_rd_d;             /* Register write identifier from instruction */

wire        csr_rd;                                   /* Control: read enable */
wire        csr_wr;                                  /* Control: write enable */
wire        csr_trap;                              /* Control: trap operation */
wire        csr_ret;                        /* Control: trap return operation */
wire [31:0] csr_data_in;                                 /* Data to CSR write */
wire [31:0] csr_data_out;                               /* Data from CSR read */

wire  [1:0] epc_sel;                                     /* Mode for EPC read */
wire  [5:0] trap_cause;                                       /* Trap type ID */
wire [31:0] trap_vector;                  /* Branch address returned from CSR */
wire [31:0] trap_val;                        /* Trap parameter - exec. to CSR */
wire [31:0] status;                          /* Current status register value */
wire [31:0] isa;                                       /* Current enabled ISA */
wire  [1:0] new_mode;                                  /* Delegated trap mode */

wire        valid_e;                        /* Exec. has something to pass on */
wire        ready_m;                                     /* Mem. is receptive */
wire  [1:0] mode_e;                          /* Mode heading for memory stage */
wire        step_e;          /* Instruction 'stepped' - ignore any watchpoint */
wire  [2:0] funct3_e;                /* Instruction function: LD/ST size etc. */
wire [31:0] result_e;                                           /* ALU output */
wire  [1:0] rd_src_e;                  /* Stage (if any) where Rd is produced */
wire        mem_ld_e;                                          /* Memory load */
wire        mem_st_e;                                         /* Memory store */
wire        csr_read;                       /* CSR value is output from exec. */
wire  [4:0] a_rd_e;                                       /* Rd write address */
wire [31:0] store_data;                                       /* What it says */
wire [31:0] store_data2;                               /* After justification */
wire        aborting;                    /* Finishing data abort(/watchpoint) */
wire [31:0] mem_ex_rd;                /* Memory stage data input inc. CSR out */
wire  [2:0] abort_m;                /* Memory signals abort (or not) to exec. */
wire        watchpoint_m;         /* Watchpoint encountered in 'memory' stage */
wire        dmem_wr_en;                         /* Write selection (in bytes) */
wire        dmem_rd_en;                                   /* Data read enable */
wire  [1:0] dmem_size;                                       /* Transfer size */

wire        valid_m;                         /* Mem. has something to pass on */
wire        ready_w;                                      /* Wr. is receptive */
wire  [1:0] rd_mem_src;           /* If forwarding memory, choose data source */
wire  [1:0] mem_A;               /* Lower address bits for data justification */
wire  [2:0] mem_ext;                               /* Load extension op. code */
wire  [4:0] a_rd_m;                                       /* Rd write address */
wire  [1:0] rd_src_m;                  /* Stage (if any) where Rd is produced */
wire [31:0] mem_result;         /* Previous exec. value for forwarding to ALU */

wire        wr_rd;                                      /* Enable write to Rd */

wire [31:0] final_result;/* Merged ALU or justified, extended load data to Rd */

wire        exec_done;            /* Instruction completed in execution stage */
wire        mem_done;                /* Instruction completed in memory stage */

wire        ctrl_active;                    /* Multiplexers to internal buses */
wire [31:0] ctrl_data_out_f;                          /* Debug read out fetch */
wire [31:0] ctrl_data_out_ms;                  /* Debug read out memory stage */
wire        ctrl_write;
wire        ctrl_we_f;
wire        ctrl_we_ms;                              /* Memory pipeline stage */
wire        ctrl_we_r;                                           /* Registers */
wire        ctrl_we_c;                                                /* CSRs */
wire        ctrl_we_m;                                     /* (Actual) memory */
wire        ctrl_busy_f;                         /* Fetch unit trying to step */

assign ctrl_active = ctrl_run || ctrl_busy; // Will assert during breakpoint @@@

assign data_address_o = result_e;                          /* Aliases for I/O */
assign data_mode_o    = mode_e;
assign data_size_o    = dmem_size;
assign data_read_o    = dmem_rd_en;
assign data_write_o   = dmem_wr_en;
assign data_data_o    = store_data2;
//assign data_ready_o   = ready_w;

assign ctrl_wait = 1'b0;                        /* Proc. needs no extra waits */

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
//
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
/* Processor top level signals purely for debugging/viewing convenience.      */

wire [31:0] dbg_pc_e, dbg_pc_m;            /* Only for display/debug tracking */
wire [31:0] dbg_instr_e;

reg   [4:0] disp_rs1, disp_rs2;                       /* Register identifiers */
wire  [4:0] disp_rd_d;
wire  [4:0] disp_rd_ex, disp_rd_mem;
wire  [4:0] disp_rd_ex_trans, disp_rd_ex_wait, disp_rd_mem_wait;
wire [31:0] disp_PC_f, disp_PC_d, disp_PC_e, disp_PC_m, disp_imm;
wire [31:0] disp_PC_f2, disp_PC_d2;
wire [31:0] disp_instr_f, disp_instr_d;
wire        disp_instr_val_f, disp_instr_val_d;
wire [31:0] disp_instr_f2, disp_instr_d2;
wire  [1:0] disp_rs1_src, disp_rs2_src;
wire  [4:0] disp_a_rd;                              /* Retirement destination */
wire [31:0] disp_rd;                                      /* Retirement value */
wire [31:0] disp_target;
wire [31:0] disp_mem_ld_addr, disp_mem_st_addr;
wire [31:0] disp_mem_ld_data, disp_mem_st_data;
reg         disp_want_rs1, disp_want_rs2;
reg         disp_ld;

always @ (posedge clk)
begin
disp_want_rs1 <= want_rs1;
disp_want_rs2 <= want_rs2;
disp_rs1      <= want_rs1 ? a_rs1 : 5'hxx;               /* Register read IDs */
disp_rs2      <= want_rs2 ? a_rs2 : 5'hxx;
disp_ld       <= dmem_rd_en;
end
assign disp_rs1_src = (disp_want_rs1) ? rs1_src : 2'hx;   /* Register sources */
assign disp_rs2_src = (disp_want_rs2) ? rs2_src : 2'hx;
assign disp_rd_d = (rd_src_d != `RD_NONE) ? a_rd_d : 5'hxx;

assign disp_PC_f      = (valid_f && ready_d) ? pc_f : 32'hxxxx_xxxx;
assign disp_PC_d      = (valid_d && ready_e) ? pc_d : 32'hxxxx_xxxx;
assign disp_PC_e      = (valid_e && ready_m) ? dbg_pc_e : 32'hxxxx_xxxx;
assign disp_PC_m      = (valid_m) ? dbg_pc_m : 32'hxxxx_xxxx;

assign disp_instr_f     = (valid_f && ready_d) ? instruction : 32'hxxxx_xxxx;
assign disp_instr_d     = (valid_d && ready_e) ? instr_d     : 32'hxxxx_xxxx;
assign disp_instr_val_f = colour_f == execute.colour;
assign disp_instr_val_d = colour_d == execute.colour;

/* These show the instruction queue subject to *known* validity.              */
assign disp_PC_f2    = disp_instr_val_f ? disp_PC_f : 32'hxxxx_xxxx;
assign disp_PC_d2    = disp_instr_val_d ? disp_PC_d : 32'hxxxx_xxxx;
assign disp_instr_f2 = disp_instr_val_f ? disp_instr_f : 32'hxxxx_xxxx;
assign disp_instr_d2 = disp_instr_val_d ? disp_instr_d : 32'hxxxx_xxxx;

assign disp_target      = (jump) ? target : 32'hxxxx_xxxx;
assign disp_rd_ex       =  (ex_status == `RD_READY)   ? ex_rd  : 5'hxx;
assign disp_rd_ex_trans =  (ex_status == `RD_PASSING) ? ex_rd  : 5'hxx;
assign disp_rd_ex_wait  =  (ex_status == `RD_AWAITED) ? ex_rd  : 5'hxx;
assign disp_rd_mem      = (mem_status == `RD_READY)   ? mem_rd : 5'hxx;
assign disp_rd_mem_wait = (mem_status == `RD_AWAITED) ? mem_rd : 5'hxx;
assign disp_imm = (use_imm && valid_d && ready_e) ? imm : 32'hxxxx_xxxx;

assign disp_a_rd = wr_rd ? a_rd_m : 5'hxx;
assign disp_rd   = wr_rd ? final_result : 32'hxxxx_xxxx;

assign disp_mem_ld_addr = dmem_rd_en ? result_e    : 32'hxxxx_xxxx;
assign disp_mem_ld_data = disp_ld    ? data_data_i : 32'hxxxx_xxxx;
assign disp_mem_st_addr = dmem_wr_en ? result_e    : 32'hxxxx_xxxx;
assign disp_mem_st_data = dmem_wr_en ? store_data2 : 32'hxxxx_xxxx;

/*----------------------------------------------------------------------------*/

/*----------------------------------------------------------------------------*/
/* Module interconnection within processor.                                   */

fetch fetch(.clk(clk),
            .reset(reset),
            .ctrl_run_i(ctrl_run),
            .ctrl_step_i(ctrl_step),
            .ctrl_busy_o(ctrl_busy_f),
            .ctrl_broken_o(ctrl_broken),
            .ctrl_we_i(ctrl_we_f),
            .ctrl_addr_i(ctrl_addr),
            .ctrl_data_i(ctrl_data_in),
            .ctrl_data_o(ctrl_data_out_f),
            .branch_i(jump),
            .target_i(target),
            .target_mode_i(target_mode),
            .target_wp_i(target_wp),
            .fetching_o(instr_read_o),
            .imem_address_o(instr_address_o),        /* To Instruction memory */
            .imem_mode_o(instr_mode_o),
            .imem_size_o(instr_size_o),                      /* Always 'word' */
            .imem_wait_i(instr_wait_i),
//          .imem_ready_o(instr_ready_o),
            .imem_abort_i(instr_abort_i),
            .valid_out_o(valid_f),
            .ready_out_i(ready_d),
            .pc_L_o(pc_f),
            .mode_o(mode_f),
            .abort_o(abort_f),
            .colour_o(colour_f),
            .step_o(step_f));

assign instruction = instr_data_i;              /* Instruction input bus (IR) */

decode decode(.clk(clk),
              .reset(reset),
              .valid_in_i(valid_f),             /* Interface from fetch stage */
              .ready_in_o(ready_d),
              .pc_i(pc_f),
              .mode_i(mode_f),
              .col_i(colour_f),
              .step_i(step_f),
              .abort_i(abort_f),
              .interrupts_i(interrupts), /* Interrupt injection & CSR support */
              .status_i(status),
              .isa_i(isa),
              .instr_i(instruction),        /* IR (register) is memory output */
              .want_rs1_o(want_rs1),              /* Outputs to register file */
              .a_rs1_o(a_rs1),
              .want_rs2_o(want_rs2),
              .a_rs2_o(a_rs2),
              .ex_status_i(ex_status),      /* Inputs to check for forwarding */
              .ex_rd_i(ex_rd),
              .mem_status_i(mem_status),
              .mem_rd_i(mem_rd),
              .valid_out_o(valid_d),             /* Output to execution stage */
              .ready_out_i(ready_e),
              .stall_reg_o(stall_reg_rd),
              .pc_o(pc_d),
              .mode_o(mode_d),
              .col_o(colour_d),
              .step_o(step_d),
              .rs1_src_o(rs1_src),
              .rs2_src_o(rs2_src),
              .use_imm_o(use_imm),
              .imm_o(imm),
              .auipc_o(auipc),
              .csr_op_o(csr_op),
              .sys_op_o(sys_op_d),
              .trap_op_o(trap_op_d),
              .instr_o(instr_d),           /* Only needed for 'illegal' traps */
              .funct3_o(funct3_d),
              .alu_op_o(alu_op),
              .branch_o(branch),
              .mem_ld_o(mem_ld_d),
              .mem_st_o(mem_st_d),
              .rd_src_o(rd_src_d),
              .a_rd_o(a_rd_d));

registers registers(.clk(clk),
                    .reset(reset),
                    .rd_rs1(want_rs1 || !ctrl_active),
                    .a_rs1(ctrl_active ? a_rs1 : ctrl_addr[4:0]),
                    .rs1(rs1),                 /* Debug readout from this bus */
                    .rd_rs2(want_rs2),
                    .a_rs2(a_rs2),
                    .rs2(rs2),
                    .stall_reg_rd(stall_reg_rd && ctrl_active),
                    .wr_rd(ctrl_active ? wr_rd : ctrl_we_r),  /* Write enable */
                    .a_rd(ctrl_active ? a_rd_m : ctrl_addr[4:0]),
                    .rd(ctrl_active ? final_result : ctrl_data_in));

execute execute(.clk(clk),
                .reset(reset),
                .forward_en_i(ex_forward_en),
                .valid_in_i(valid_d),              /* Input from decode stage */
                .ready_in_o(ready_e),
                .pc_i(pc_d),
                .mode_i(mode_d),
                .col_i(colour_d),
                .step_i(step_d),
                .rd_src_i(rd_src_d),
                .rs1_src_i(rs1_src),
                .rs1_r_i(rs1),
                .rs2_src_i(rs2_src),
                .rs2_r_i(rs2),
                .use_imm_i(use_imm),
                .imm_i(imm),
                .instr_i(instr_d),         /* Only needed for 'illegal' traps */
                .funct3_i(funct3_d),
                .mem_ld_i(mem_ld_d),
                .mem_st_i(mem_st_d),
                .auipc_i(auipc),
                .csr_op_i(csr_op),
                .sys_op_i(sys_op_d),
                .trap_op_i(trap_op_d),
                .alu_op_i(alu_op),
                .branch_i(branch),
                .a_rd_i(a_rd_d),
                .csr_rd_o(csr_rd),          /* Outputs to parallel CSR module */
                .csr_wr_o(csr_wr),
                .csr_trap_o(csr_trap),
                .csr_ret_o(csr_ret),
                .csr_data_in_o(csr_data_in),
                .ex_status_o(ex_status),           /* On offer for forwarding */
                .ex_rd_o(ex_rd),
                .mem_ex_rd_i(mem_ex_rd),                   /* Forwarding path */
                .rd_mem_ld_i(final_result),                /* Forwarding path */
                .epc_sel_o(epc_sel),
                .trap_cause_o(trap_cause),
                .trap_val_o(trap_val),
                .trap_vector_i(trap_vector),
                .status_i(status),               /* Processor status register */
                .new_mode_i(new_mode),
                .valid_out_o(valid_e),              /* Output to memory stage */
                .ready_out_i(ready_m),
                .abort_i(abort_m),                  /* Data abort code return */
                .watchpoint_i(watchpoint_m),
                .abort_L_o(aborting),    /* Finishing data abort(/watchpoint) */
                .dbg_instr_o(dbg_instr_e),  /* For debugging and display only */
                .dbg_pc_o(dbg_pc_e),        /* For debugging and display only */
                .mode_o(mode_e),     /* Goes directly out to memory interface */
                .step_o(step_e),
                .funct3_o(funct3_e),
                .result_o(result_e),
                .rd_src_o(rd_src_e),
                .mem_ld_o(mem_ld_e),
                .mem_st_o(mem_st_e),
                .csr_read_o(csr_read),
                .a_rd_o(a_rd_e),
                .store_data_o(store_data),
                .jump_o(jump),
                .target_o(target),
                .target_mode_o(target_mode),
                .target_wp_o(target_wp),
                .exec_done_o(exec_done));

memory memory(.clk(clk),
              .reset(reset),
              .forward_en_i(mem_forward_en),
            .ctrl_we_i(ctrl_we_ms),
            .ctrl_addr_i(ctrl_addr),
            .ctrl_data_i(ctrl_data_in),
            .ctrl_data_o(ctrl_data_out_ms),
              .valid_in_i(valid_e),
              .ready_in_o(ready_m),
              .mode_i(mode_e),                  /* Used for watchpoint checks */
              .step_i(step_e),
              .funct3_i(funct3_e),
              .result_i(result_e),
              .csr_data_i(csr_data_out),
              .rd_src_i(rd_src_e),
              .mem_ld_i(mem_ld_e),
              .mem_st_i(mem_st_e),
              .csr_read_i(csr_read),
              .a_rd_i(a_rd_e),
              .stall_i(data_wait_i),
              .abort_i(data_abort_i),
              .stop_i(stop_i),                           /* Self-stop request */
              .abort_o(abort_m),
              .watchpoint_o(watchpoint_m),
              .valid_out_o(valid_m),
              .ready_out_i(ready_w),
              .mem_status_o(mem_status),
              .mem_rd_o(mem_rd),
              .rd_mem_src_o(rd_mem_src),
              .mem_A_o(mem_A),
              .mem_ext_o(mem_ext),
              .dmem_wr_en_o(dmem_wr_en),
              .dmem_rd_en_o(dmem_rd_en),
              .dmem_size_o(dmem_size),
              .a_rd_o(a_rd_m),
              .rd_src_o(rd_src_m),
              .mem_ex_rd_o(mem_ex_rd),
              .result_o(mem_result),
              .mem_done_o(mem_done),
              .dbg_pc_i(dbg_pc_e),          /* For debugging and display only */
              .dbg_pc_o(dbg_pc_m));         /* For debugging and display only */

store_just store_just(.mem_ext_i(funct3_e),      /* This is done at the start */
                      .data_i(store_data),             /* of the memory stage */
                      .data_o(store_data2));

write write(.clk(clk),
            .reset(reset),
            .valid_in_i(valid_m),
            .ready_in_o(ready_w),
            .mem_A_i(mem_A),
            .mem_ext_i(mem_ext),
            .source_i(rd_mem_src),
            .alu_data_i(mem_result),
            .load_data_i(data_data_i),
            .data_o(final_result),
            .rd_src_i(rd_src_m),
            .a_rd(a_rd_m),
            .wr_rd(wr_rd));

csr csr(.clk(clk),
        .reset(reset),
        .mode_i(mode_d),
        .interrupts_i({20'h00000, interrupts_i}),   /* Interrupt input vector */
        .interrupts_o(interrupts),
        .csr_rd_i(csr_rd || !ctrl_active),		// @@@
        .csr_wr_i(ctrl_active ? csr_wr : ctrl_we_c),	// @@@
        .csr_trap_i(ctrl_active ? csr_trap : 1'b0),	// @@@
        .csr_ret_i(ctrl_active ? csr_ret : 1'b0),	// @@@
        .csr_fn_i(ctrl_active ? funct3_d : 3'b001),	// Write all bits @@@
        .address_i(ctrl_active ? imm[11:0] : ctrl_addr[11:0]),	// @@@
        .data_in(ctrl_active ? csr_data_in : ctrl_data_in),	// @@@
        .tval_i(trap_val),
        .data_out(csr_data_out),			// @@@
        .epc_sel_i(epc_sel),
        .trap_cause_i(trap_cause),
        .new_mode_o(new_mode),
        .trap_vector_o(trap_vector),
        .status_o(status),
        .isa_o(isa),
        .mtime_i(mtime_i),
        .exec_done_i(exec_done),             /* Instruction complete at exec. */
        .mem_done_i(mem_done),                /* Instruction complete at mem. */
        .retiring_i(wr_rd));             /* Instruction complete at writeback */

assign ctrl_busy = ctrl_busy_f || valid_f || valid_d || valid_e || valid_m
                               || aborting;

always @ (*)                                                    /* Debug read */
case (ctrl_space)
  2'h0: ctrl_data_out = !ctrl_addr[8] ? ctrl_data_out_f : ctrl_data_out_ms;
  2'h1: ctrl_data_out = rs1;                    /* External register read tap */
  2'h2: ctrl_data_out = csr_data_out;                      /* CSR data output */
  default: ctrl_data_out = 32'hxxxx_xxxx;  /* Memory value driven outside CPU */
endcase

 /* Unit debug writes */
assign ctrl_write = ctrl_we && !ctrl_active;
assign ctrl_we_f = ctrl_write && (ctrl_space == 2'h0) && !ctrl_addr[8];
assign ctrl_we_ms= ctrl_write && (ctrl_space == 2'h0) &&  ctrl_addr[8];
assign ctrl_we_r = ctrl_write && (ctrl_space == 2'h1);
assign ctrl_we_c = ctrl_write && (ctrl_space == 2'h2);
assign ctrl_we_m = ctrl_write && (ctrl_space == 2'h3);

endmodule                                                           /* risc_v */

