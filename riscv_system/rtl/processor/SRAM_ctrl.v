/* Module provides arbitrated interface from various buses to SRAM; also      */
/* provides SRAM control timing with single cycle read and two cycle write,   */
/* with central write enables timed from negedge.                     23/8/25 */

module sram_ctrl(input  wire        clk,
                 input  wire        reset,

                 input  wire        CS_A,                     /* VDU read bus */
                 input  wire        read_A,
                 input  wire        write_A,
                 output wire        stall_A,
                 input  wire  [1:0] size_A,
                 input  wire [19:0] addr_A,
                 input  wire [31:0] dwr_A,
                 output wire [31:0] drd_A,

                 input  wire        CS_B,             /* Processor connection */
                 input  wire        read_B,
                 input  wire        write_B,
                 output wire        stall_B,
                 input  wire  [1:0] size_B,
                 input  wire [19:0] addr_B,
                 input  wire [31:0] dwr_B,
                 output wire [31:0] drd_B,
/*
                 input  wire        CS_C,
                 input  wire        read_C,
                 input  wire        write_C,
                 output wire        stall_C,
                 input  wire  [1:0] size_C,
                 input  wire [19:0] addr_C,
                 input  wire [31:0] dwr_C,
                 output wire [31:0] drd_C,
*/
                 input  wire        de_req,    /* DE bus takes different form */
                 output reg         de_ack,
                 input  wire [17:0] de_addr,
                 input  wire  [3:0] de_nbyte,
                 input  wire [31:0] de_w_data,
                 input  wire        de_rnw,
                 output wire [31:0] de_r_data,

                 output reg         n_CS_o,         /* Downdtream bus to SRAM */
                 output reg         n_rd_o,                  /* Timing strobe */
                 output reg         n_wr_o,                  /* Timing strobe */
                 output reg  [17:0] addr_o,
                 output reg   [3:0] n_bytes_o,/* Byte selects (address timing)*/
                 output wire        n_write_o,         /* Actual write strobe */
                 input  wire [31:0] d_in_i,
                 output reg  [31:0] d_out_o);

wire   [2:0] CS;               /* Signals vectorised for source code neatness */
wire   [2:0] read;
wire   [2:0] write;
wire   [2:0] req;
reg    [2:0] stall;
reg    [2:0] grant;
reg    [2:0] granted;
wire   [2:0] select;
reg          next_idle;
reg          idle;

reg    [1:0] size;
reg    [1:0] addr_l;                             /* Latched byte address bits */

reg   [31:0] d_in;

wire        CS_C;                       /* Translation of DE port for arbiter */
wire        read_C;
wire        write_C;
wire        stall_C;                              /* Dummy: not actually used */
wire  [1:0] size_C;                               /* Dummy: not actually used */
wire [19:0] addr_C;
wire [31:0] dwr_C;
wire [31:0] drd_C;

assign CS_C      = 1'b1;             /* Selection wholly on the input request */
assign read_C    = de_req &&  de_rnw;
assign write_C   = de_req && !de_rnw;
assign addr_C    = {de_addr, 2'h0};
assign dwr_C     = de_w_data;
assign de_r_data = drd_C;
assign size_C    = 2;                                    /* Dummy: not in use */

assign CS      = {CS_C,    CS_B,    CS_A};                /* Vectorise inputs */
assign read    = {read_C,  read_B,  read_A}  & CS;
assign write   = {write_C, write_B, write_A} & CS;
assign stall_A = stall[0];
assign stall_B = stall[1];
assign stall_C = stall[2];
assign req = read | write;

always @ (*)
if (reset) next_idle = 1'b1;
else       next_idle = !(|(grant & write));

always @ (posedge clk) idle <= next_idle;

always @ (*)                                                       /* Arbiter */
begin
grant = 3'b000;                                                    /* Default */
if (idle)                                                 /* Priority encoder */
  begin
  grant[0] = req[0];
  if (!grant[0]) grant[1] = req[1];
  if (!(|grant[1:0])) grant[2] = req[2];
  end
end

always @ (posedge clk)
if (reset || next_idle) granted <= 3'b000;
else if (idle)          granted <= grant;

assign select = grant | ({3{!idle}} & granted);

always @ (*)           n_CS_o  = !(|(CS    & select));
always @ (*)           n_rd_o  = !(|(read  & select));
always @ (negedge clk) n_wr_o <= !(|(write & grant));      /* Shortened pulse */

always @ (*)
if (reset) stall = 3'h7;
else
if (idle) stall = write | (read & ~grant);
else      stall = req & ~granted;
/* Write (first) cycle or request not granted (first/subsequent cycles).      */

always @ (*)                    /* DE_ack generated independently from stalls */
if (read[2])  de_ack = grant[2];      /* Reads acknowledge as soon as granted */
else
if (write[2]) de_ack = granted[2];   /* Writes delay ack to allow 2 cycle op. */
else          de_ack = 1'b0; 

assign drd_A = d_in;                          /* Return data simply broadcast */
assign drd_B = d_in;
assign drd_C = d_in;

always @ (posedge clk) d_in <= d_in_i;   /* Latch makes SRAM look synchronous */

always @ (*)                                 /* Bus multiplexers towards SRAM */
case (select)
  3'b001:  begin
           addr_o  = addr_A[19:2];
           addr_l  = addr_A[1:0];
           size    = size_A;
           d_out_o = dwr_A;
           end
  3'b010:  begin
           addr_o  = addr_B[19:2];
           addr_l  = addr_B[1:0];
           size    = size_B;
           d_out_o = dwr_B;
           end
  3'b100:  begin
           addr_o  = addr_C[19:2];
           addr_l  = addr_C[1:0];
           size    = size_C;
           d_out_o = dwr_C;
           end
  default: begin
           addr_o  = 18'hxxx;
           addr_l  = 2'hx;
           size    = 2'hx;
           d_out_o = 32'hxxxx_xxxx;
           end
endcase

always @ (*)
if (grant[2] || granted[2]) n_bytes_o = de_nbyte;       /* DE already decoded */
else
  case (size)                   /* else decode by size and lower address bits */
    2'h0:    case (addr_l)
               2'h0: n_bytes_o = 4'b1110;
               2'h1: n_bytes_o = 4'b1101;
               2'h2: n_bytes_o = 4'b1011;
               2'h3: n_bytes_o = 4'b0111;
             endcase
    2'h1:    n_bytes_o = addr_l[1] ? 4'b0011 : 4'b1100;
    2'h2:    n_bytes_o = 4'b0000;
    default: n_bytes_o = 4'b1111;
  endcase

assign n_write_o = !(|(write & select));

endmodule	// sram_ctrl

/*----------------------------------------------------------------------------*/
