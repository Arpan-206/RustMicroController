/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
/* Interrupt controller for slave                                             */

module interrupt_ctrl2 (input  wire        clk,
                       input  wire        reset,

                       input  wire        cs_i,
                       input  wire        read_i,
                       input  wire        write_i,
                       input  wire [31:0] address_i,
                       input  wire  [1:0] size_i,
                       input  wire  [1:0] mode_i,
                       output wire        stall_o,
                       output wire  [2:0] abort_v_o,
                       input  wire [31:0] data_in,
                       output reg  [31:0] data_out,

                       input  wire [31:0] ireq_i,    /* Set of input requests */
                       output wire        ireq_o);     /* Output to processor */

reg   [4:0] addr;
wire        writing;

reg  [31:0] reg_ien;                                     /* Interrupt enables */
reg  [31:0] irq_L;                                  /* Previous request state */
reg  [31:0] irq_latched;                         /* Sticky bits from requests */
wire [31:0] irq_edge;                   /* Pulse to set new interrupt request */
wire [31:0] sw_clr;                               /* Software interrupt clear */
wire [31:0] sw_set;                                 /* Software interrupt set */
reg  [31:0] mode;                  /* 0 = level sensitive: 1 = edge sensitive */
wire [31:0] irq_raw;                                     /* After mode select */
wire [31:0] irq;                                              /* After enable */

assign stall_o   =    cs_i   && 1'b0;
assign abort_v_o = {3{cs_i}} && 3'h0;

assign writing = cs_i && write_i;

always @ (posedge clk)
if (reset)
  begin
  irq_L       <= 32'h0000_0000;
  irq_latched <= 32'h0000_0000;
  end
else
  begin
  irq_L       <= ireq_i;
  irq_latched <= irq_edge | sw_set | (irq_latched & ~sw_clr);
  end

assign irq_edge = ireq_i & ~irq_L;                  /* Pulses on rising edges */

assign sw_clr = {32{writing && (address_i[4:2] == 3'h4)}} & data_in;
assign sw_set = {32{writing && (address_i[4:2] == 3'h5)}} & data_in;


// 
// Generate muxes for irq_raw based on 
// edge or level sensitivity 
genvar i;
generate  
  for (i = 0; i <= 31; i = i + 1) begin 
    assign irq_raw[i] = mode[i] ? irq_latched[i] : ireq_i[i];
  end
endgenerate


assign irq     = irq_raw & reg_ien;

always @ (posedge clk)                                     /* Register writes */
if (reset)
  begin
  reg_ien <= 32'h0000_0000;
  mode    <= 32'h0000_0000;
  end
else
  begin
  if (writing)
    case (address_i[4:2])
      3'h1: reg_ien <= data_in;
      3'h3: mode    <= data_in;
    endcase
  end

always @ (posedge clk)                                    /* Address bit hold */
if (read_i) addr <= address_i[4:0];                   /* Delay for next cycle */

always @ (*)                                                /* Register reads */
case (addr[4:2])
  3'h0:    data_out = ireq_i;                                   /* Raw inputs */
  3'h1:    data_out = reg_ien;                                     /* Enables */
  3'h2:    data_out = irq;                          /* Active, allowed inputs */
  3'h3:    data_out = mode;                                  /* Level or edge */
  3'h4:    data_out = irq_latched;                    /* After edge detection */
  3'h7:    data_out = {31'h0000_0000, ireq_o};
  default: data_out = 32'h0000_0000;
endcase

assign ireq_o = |(irq & reg_ien);             /* OR enabled inputs for output */

endmodule	// interrupt_ctrl2

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
