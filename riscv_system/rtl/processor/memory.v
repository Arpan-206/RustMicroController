/*----------------------------------------------------------------------------*/

module memory(input  wire        clk,
              input  wire        reset,
              input  wire        forward_en_i,        /* Configuration switch */

              input  wire        ctrl_we_i,    /* Debug write watchpoint reg. */
              input  wire [31:0] ctrl_addr_i,        /* Debug R/W register ID */
              input  wire [31:0] ctrl_data_i,  /* Data for writing (debugger) */
              output reg  [31:0] ctrl_data_o,             /* Data for reading */

              input  wire        valid_in_i,                  /* Flow control */
              output wire        ready_in_o,
              input  wire  [1:0] mode_i,         /* Used only for watchpoints */
              input  wire        step_i,        /* Prevent watchpoints if set */
              input  wire  [2:0] funct3_i,     /* Used for transfer size/ext. */
              input  wire [31:0] result_i, /* Result from ALU: possibly addr. */
              input  wire [31:0] csr_data_i, /* Latched CSR output from exec. */
              input  wire  [1:0] rd_src_i,
              input  wire        mem_ld_i,                       /* Do a load */
              input  wire        mem_st_i,                      /* Do a store */
              input  wire        csr_read_i, /* There is CSR read data wanted */
              input  wire  [4:0] a_rd_i,           /* Destination register ID */

              input  wire        stall_i,           /* Memory not (yet) ready */
              input  wire  [2:0] abort_i,     /* Memory won't service request */
              input  wire        stop_i,                 /* Self-stop request */
              output wire  [2:0] abort_o,       /* Signal back to exec. stage */
              output wire        watchpoint_o,  /* Signal back to exec. stage */

              output reg         valid_out_o,      /* Output pipeline control */
              input  wire        ready_out_i,
              output reg   [1:0] mem_status_o,
              output wire  [4:0] mem_rd_o,
              output reg   [1:0] rd_mem_src_o,
              output reg   [1:0] mem_A_o,   /* Address low, for justification */
              output reg   [2:0] mem_ext_o,       /* Sign/zero extension code */
              output wire        dmem_wr_en_o,
              output wire        dmem_rd_en_o,
              output wire  [1:0] dmem_size_o,
              output reg   [4:0] a_rd_o,
              output reg   [1:0] rd_src_o,
              output reg  [31:0] mem_ex_rd_o,    /* Input data with CSR incl. */
              output reg  [31:0] result_o,  /* Latched output data (as above) */
              output wire        mem_done_o,
              input  wire [31:0] dbg_pc_i,  /* For debugging and display only */
              output reg  [31:0] dbg_pc_o); /* For debugging and display only */

localparam WP = 4;                              /* Number of watchpoints (<8) */
localparam CTRL_WTCH_EN_M  = `CTRL_WTCH_EN  & 8'hFF;       /* Masked versions */
localparam CTRL_WTCH_SRC_M = `CTRL_WTCH_SRC & 8'hFF;       /* Masked versions */

integer ii;  /* For 'iterative' watchpoint register initialisation & checking */

wire         load, store;
wire         no_output;
wire         valid_ish;          /* Valid operation but memory may be stalled */
wire         valid;                         /* Ready for operation completion */
wire         kill;
wire         abort_wp;
wire         dmem_rd_en;
wire         dmem_wr_en;

reg   [31:0] watchpoint_addr      [0:WP-1];    /* 4 WP implemented at present */
reg   [31:0] watchpoint_addr_mask [0:WP-1];
reg   [11:0] watchpoint_ctrl      [0:WP-1];
reg          watchpoint_en;                       /* Global watchpoint enable */
reg [WP-1:0] watchpoint_ens;                 /* Individual watchpoint enables */
reg [WP-1:0] watchpoint_src;                      /* Combinatorial derivation */
reg [WP-1:0] watchpoint_src_L;                                /* Sticky latch */
reg          watchpoint;                            /* Watchpoint match found */
wire  [31:0] watchpoint_rd;        /* View of watchpoints/stop for controller */
wire         watchpoint_clr;       /* Clear latest watchpoint source snapshot */
reg          stop_L;                       /* Analogous with watchpoint_src_L */

wire   [7:0] watch_field = ctrl_addr_i[3:0];        /* For coding convenience */
wire   [1:0] watch_no    = ctrl_addr_i[5:4];

assign abort_wp   = (abort_i != `ABORT_NONE) || watchpoint;
assign kill       = 1'b0;        /* Not using abort to keep ready_in inactive */
assign ready_in_o = (!valid_in_i || (ready_out_i&&!stall_i) || kill)&&!abort_wp;
assign valid_ish  = valid_in_i && !kill;
assign valid      = valid_ish && !stall_i;
assign abort_o    = abort_i;
assign watchpoint_o = watchpoint || stop_i;

assign load         = mem_ld_i;
assign store        = mem_st_i;
assign no_output    = (rd_src_i == `RD_NONE);
assign dmem_rd_en   = (valid_ish && load);
assign dmem_wr_en   = (valid_ish && store);
assign dmem_rd_en_o = dmem_rd_en && !watchpoint;
assign dmem_wr_en_o = dmem_wr_en && !watchpoint;
assign dmem_size_o  = funct3_i[1:0];
assign mem_rd_o     = a_rd_i;                      /* This is the register ID */

assign mem_done_o = valid && no_output;    // Always ready (BUT) ***

always @ (*)
if (csr_read_i) mem_ex_rd_o = csr_data_i;       /* Multiplex in CSR read data */
else            mem_ex_rd_o = result_i;     // Maybe this mux. is in exec? *****

always @ (*)
if (!valid_in_i || no_output) mem_status_o = `RD_EMPTY;
else
  if (forward_en_i)
    if (load && stall_i) mem_status_o = `RD_AWAITED;
    else                 mem_status_o = `RD_READY;
  else                   mem_status_o = `RD_PASSING;

always @ (posedge clk)
begin
if (reset)            valid_out_o <= 1'b0;
else if (ready_out_i) valid_out_o <= valid && !no_output && !abort_wp;
						// && !stall_i ********; @@@
if (valid && ready_out_i)
  begin
  a_rd_o   <= a_rd_i;
  result_o <= mem_ex_rd_o;                   /* Any result except memory load */
					// Predicate on validity for power? ****
  rd_src_o <= rd_src_i;               /* This duplicates the info below ***** */

  if (load) rd_mem_src_o <= `RD_LOAD;   /* Indicate data stream for writeback */
  else      rd_mem_src_o <= `RD_EXEC;	// Can export single 'load' signal ****

  mem_A_o   <= result_i[1:0];	// Worth reconciling? or gating if not used?****
  mem_ext_o <= funct3_i;
  dbg_pc_o  <= dbg_pc_i;                               /* Debug tracking only */
  end
end

always @ (*)                           /* Check each watchpoint (into vector) */
for (ii = 0; ii < WP; ii = ii + 1)
  watchpoint_src[ii] = watch_break(result_i, watchpoint_addr[ii],
                                             watchpoint_addr_mask[ii],
                                             watchpoint_ctrl[ii],
                                             watchpoint_ens[ii],
                                             mode_i, funct3_i[1:0],
                                             mem_ld_i, mem_st_i);

always @ (*)                          /* Watchpoint test; apply global enable */
begin
//watchpoint = 1'b0;                                             /* Default: no */
if ((dmem_rd_en || dmem_wr_en) && !step_i)   /* Active cycle: not single step */
  watchpoint = (|watchpoint_src) && watchpoint_en;
else
  watchpoint = 1'b0; 
end

assign watchpoint_clr = ctrl_we_i && (watch_field == CTRL_WTCH_SRC_M);

always @ (posedge clk)
if (watchpoint_o)                                     /* Includes stop signal */
  begin                                             /* Take snapshot of state */
  watchpoint_src_L <= watchpoint_src;
  stop_L           <= stop_i;
  end
else
  if (reset || watchpoint_clr)
    begin                                                   /* Clear snapshot */
    watchpoint_src_L <=  'h0;
    stop_L           <= 1'b0;
    end

assign watchpoint_rd = 32'h0 | (stop_L << 31) | watchpoint_src_L;

always @ (posedge clk)                           /* Watchpoint register write */
if (reset)
  begin
  for (ii = 0; ii < WP; ii = ii + 1)
    begin
    watchpoint_addr[ii]      <= 32'h0000_0000;               /* Initial value */
    watchpoint_addr_mask[ii] <= 32'hFFFF_FFFF;               /* Initial value */
    watchpoint_ctrl[ii]      <= 12'b0;                 /* Disabled by default */
    end
  watchpoint_en  <= 1'b0;     /* Initialise with global and local enables OFF */
  watchpoint_ens <=  'h0;
  end
else
  if (ctrl_we_i)                       /* External watchpoint register writes */
    case (watch_field)                 /* Note: mix of `define and localparam */
      `CTRL_WTCH_AD:     watchpoint_addr[watch_no]      <= ctrl_data_i;
      `CTRL_WTCH_AD_MSK: watchpoint_addr_mask[watch_no] <= ctrl_data_i;
      `CTRL_WTCH_CTRL:   watchpoint_ctrl[watch_no]      <= ctrl_data_i[11:0];
       CTRL_WTCH_EN_M:   begin
                         watchpoint_en                  <= ctrl_data_i[8];
                         watchpoint_ens                 <= ctrl_data_i[WP-1:0];
                         end
    endcase

always @ (*)                                      /* Watchpoint register read */
case (watch_field)                     /* Note: mix of `define and localparam */
  `CTRL_WTCH_AD:     ctrl_data_o = watchpoint_addr[watch_no];
  `CTRL_WTCH_AD_MSK: ctrl_data_o = watchpoint_addr_mask[watch_no];
  `CTRL_WTCH_CTRL:   ctrl_data_o = {20'h00000, watchpoint_ctrl[watch_no]};
   CTRL_WTCH_EN_M:   ctrl_data_o = 32'h0 | (watchpoint_en)<<8 | watchpoint_ens;
   CTRL_WTCH_SRC_M:  ctrl_data_o = watchpoint_rd;
  default:           ctrl_data_o = 32'hxxxx_xxxx;
endcase

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

function watch_break;             /* Combinatorial check for watchpoint match */
input [31:0] result, addr, mask;
input [11:0] control;
input        enable;                            /* Watchpoint specific enable */
input  [3:0] mode;
input  [1:0] size;
input        ld, st;
begin watch_break = ((result & mask) == (addr & mask))       /* Address check */
                 && (((1'b1 << mode) & control[11:8]) != 0)     /* Mode check */
                 && (((1'b1 << size) & control[7:4])  != 0)     /* Size check */
                 && ((ld && control[1]) || (st && control[0]))   /* Direction */
                 && enable;                                         /* Enable */
end
endfunction

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

endmodule	// memory

/*----------------------------------------------------------------------------*/
