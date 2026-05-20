/* Instruction fetch.  This unit generates the addresses and holds the PC     */
/* output; the instruction memory is responsible for latching the instruction */
/* (i.e. IR).  NB: if memory waiting a branch can -change- the address output.*/

module fetch 
            (input  wire        clk,
             input  wire        reset,
             input  wire        ctrl_run_i,
             input  wire        ctrl_step_i,                   /* Single step */
             output wire        ctrl_busy_o,                /* Trying to step */
             output wire        ctrl_broken_o,      /* Breakpoint encountered */
             input  wire        ctrl_we_i,           /* Debug write PC (etc.) */
             input  wire [31:0] ctrl_addr_i,
             input  wire [31:0] ctrl_data_i,   /* Data for writing (debugger) */
             output reg  [31:0] ctrl_data_o,              /* Data for reading */
             input  wire        branch_i,             /* New PC input request */
             input  wire [31:0] target_i,                           /* New PC */
             input  wire  [1:0] target_mode_i,                    /* New mode */
             input  wire        target_wp_i,           /* Halt for watchpoint */
             output wire        fetching_o,              /* Want to read Imem */
             output wire [31:0] imem_address_o,   /* Fetch address this cycle */
             output wire  [1:0] imem_mode_o,         /* Fetch mode for memory */
             output wire  [1:0] imem_size_o,             /* Fetch size (word) */
             input  wire        imem_wait_i,      /* Memory will not be ready */
//           output wire        imem_ready_o,
             input  wire  [2:0] imem_abort_i,         /* Fetch success status */
             output reg         valid_out_o,     /* Valid instruction latched */
             input  wire        ready_out_i,          /* Next stage receptive */
             output reg  [31:0] pc_L_o,             /* PC from previous fetch */
             output reg   [1:0] mode_o,                     /* Mode of pc_L_o */
             output reg   [2:0] abort_o,   /* Latched abort state from pc_L_o */
             output reg         colour_o,             /* PC stream identifier */
             output reg         step_o);          /* Indicates 'do not break' */
             
localparam BP = 8;                              /* Number of breakpoints (<8) */

//wire read_req, read_en, PC_en;
//
//assign read_req = fetching_o &&  ready_out_i;
//assign read_en  = read_req   && !imem_wait_i;
//assign PC_en    = read_en    ||  branch_i;

integer ii;  /* For 'iterative' breakpoint register initialisation & checking */
genvar  jj;

reg    [31:0] pc;                               /* The true Programme Counter */
reg     [1:0] mode;                                       /* ... plus baggage */
reg           colour;
wire          imem_colour;                            /* Only used internally */
wire          kontinue;                /* Fetching okay to proceed internally */
wire          new_out;

wire          halt;
wire          step;                                        /* Force one fetch */
reg           step_L;                                 /* Step delayed by wait */
reg           step_mode;                         /* Processor fetches limited */
reg    [31:0] fetches_remaining;                   /* Processor fetches limit */
reg    [31:0] breakpoint [0:BP-1];                    /* Breakpoint addresses */
reg           breakpoint_en;                      /* Global breakpoint enable */
reg  [BP-1:0] breakpoint_ens;                /* Individual breakpoint enables */
wire [BP-1:0] breakpt;                            /* Breakpoint detect vector */
reg           watchpoint;

assign halt = step_mode && (fetches_remaining==32'h0000_0000) || ctrl_broken_o;
							// Reset as well? @@@
//assign fetching_o = (ctrl_run_i && !halt) || step || (branch_i && !target_wp_i
                 /* Complete branch; but don't (re)fetch target if watchpoint */
assign fetching_o = ((ctrl_run_i && !halt) || step) && ready_out_i;

//assign imem_ready_o   = ready_out_i || branch_i;    /* Branch trumps prefetch */
assign imem_address_o = branch_i ? target_i : pc;    /* Mux signals to 'imem' */
assign imem_mode_o    = branch_i ? target_mode_i : mode;
assign imem_colour    = branch_i ? !colour : colour;
assign imem_size_o    = 2'h2;                           /* All words, to date */

assign kontinue = !imem_wait_i && fetching_o;
assign new_out  = kontinue;                      /* ("continue" is a keyword) */

always @ (posedge clk)
if (reset)
  begin
  step_mode <= 1'b0;
  fetches_remaining <= 32'h0000_0000;
  breakpoint_en  <= 1'b0;                         /* Global breakpoint enable */
  breakpoint_ens <=  'h0;                    /* Individual breakpoint enables */
  for (ii = 0; ii < BP; ii = ii + 1)
    breakpoint[ii] <= 32'h0000_0001;      /* LSB can be used for deactivation */
  end
else
  begin
  if (ctrl_we_i && (ctrl_addr_i == `CTRL_MODE)) step_mode <= ctrl_data_i[0];

  for (ii = 0; ii < BP; ii = ii + 1)                  /* Breakpoint registers */
    if (ctrl_we_i && (ctrl_addr_i == (`CTRL_BKPT | (ii << 4))))
      breakpoint[ii] <= ctrl_data_i;

  if (ctrl_we_i && (ctrl_addr_i == `CTRL_BKPT_EN))
    begin
    breakpoint_en  <= ctrl_data_i[8];
    breakpoint_ens <= ctrl_data_i[BP-1:0];
    end

  if (ctrl_we_i && (ctrl_addr_i == `CTRL_FETCHES))
    fetches_remaining <= ctrl_data_i;
  else
    if (step_mode && (valid_out_o && ready_out_i) && !halt)
      if (fetches_remaining != 32'h0000_0000)
        fetches_remaining <= fetches_remaining - 1;
//kontinue    possibly not the appropriate signal - but double-check @@@
  end

always @ (posedge clk)                         /* Local watchpoint halt latch */
if (reset || step) watchpoint <= 1'b0;
else               watchpoint <= watchpoint || target_wp_i;

always @ (posedge clk)
if (reset) step_L <= 1'b0;
else       step_L <= step && imem_wait_i;   /* Hold step input if memory wait */

assign step = ctrl_step_i || step_L;

generate
for (jj = 0; jj < BP; jj = jj + 1)
  begin
  assign breakpt[jj] = (imem_address_o == breakpoint[jj]) && breakpoint_ens[jj]
                                                          && breakpoint_en;
  end
endgenerate

assign ctrl_broken_o = (|breakpt || watchpoint || target_wp_i) && !step;
					// Gate with breakpoint enable?? @@@
assign ctrl_busy_o   = step;         /* Ensure processor is 'active' for step */

always @ (posedge clk)
if (reset)
  begin
  pc     <= `RESET_ADDRESS;
  mode   <= 2'b11;                                            /* Machine mode */
  mode_o <= 2'b11;                                /* Neater: prob. not needed */
  colour <= 1'b0;
  step_o <= 1'b0;
  end
else
  begin
  if (ctrl_we_i && (ctrl_addr_i == `CTRL_PC)) pc <= ctrl_data_i;  /* PC write */
  else
    begin
    pc <= new_out ? imem_address_o + 4 : imem_address_o;/* Can branch if stall*/
    colour <= imem_colour;
    if (new_out)
      begin
      pc_L_o   <= imem_address_o;                 /* PC parallels instruction */
      colour_o <= imem_colour;
      abort_o  <= imem_abort_i;
      end
    end

  if (ctrl_we_i && (ctrl_addr_i == `CTRL_PRIV)) mode <= ctrl_data_i[1:0];
  else
    begin
    mode <= imem_mode_o;                     /* Will update at branch arrival */
    if (new_out) mode_o <= imem_mode_o;
    end
  step_o <= step && watchpoint;       /* Note: ignore watchpoints on this one */
  end

always @ (posedge clk)
if (reset) valid_out_o <= 1'b0;
else
  if (ready_out_i)
    valid_out_o <= kontinue;    /* Arguably, suppress if a branch is arriving */

always @ (*)
if (ctrl_addr_i[7] == 1'b0)                              /* Control registers */
  case (ctrl_addr_i)
    `CTRL_PC:      ctrl_data_o = pc;
    `CTRL_MODE:    ctrl_data_o = {31'h0000_0000, step_mode};
    `CTRL_FETCHES: ctrl_data_o = fetches_remaining;
    `CTRL_BKPT_ID: ctrl_data_o = 32'h0000_0000 | breakpt; // Other causes @@@
    `CTRL_PRIV:    ctrl_data_o = {30'h0000_0000, mode};
    `CTRL_BKPT_EN: ctrl_data_o = 32'h0 | (breakpoint_en << 8) | breakpoint_ens;
    default:       ctrl_data_o = 32'hxxxx_xxxx;
  endcase
else                                                  /* Breakpoint addresses */
  if (ctrl_addr_i[6:4] < BP) ctrl_data_o = breakpoint[ctrl_addr_i[6:4]];
  else                       ctrl_data_o = 32'hxxxx_xxxx;

endmodule	// fetch

/*----------------------------------------------------------------------------*/
