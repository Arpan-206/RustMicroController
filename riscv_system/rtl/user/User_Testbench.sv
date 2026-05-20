/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
/* Testbench for User_Peripheral: adder + pixel address calculator             */
/*                                                          AMM/JDG Feb. 2025 */
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

`define USER_IO_SPACE 16'h0002
`define RUN_TIME      500

module User_Testbench();

localparam CLOCK_PERIOD = 10;

reg         clk;
reg         reset;
reg         read;
reg         write;
wire        cs;
reg  [31:0] address;
reg  [ 1:0] size;
reg  [ 1:0] mode;
reg  [31:0] data_in;
wire [31:0] data_out;
wire        stall;
wire [ 2:0] abort;
wire [ 3:0] irq;

reg  [31:0] port_in;
wire [31:0] port_out;
wire [31:0] port_direction;
wire [ 7:0] LED;
reg  [ 3:0] switch;

wire [ 7:0] lcd_data_o;
wire        lcd_rw_o, lcd_rs_o, lcd_e_o, lcd_bl_o;
reg  [ 7:0] lcd_data_i;

reg         proc_read;
wire [31:0] proc_data;

/* ------------------------------------------------------------------ */
/* Clock + run limit                                                   */
/* ------------------------------------------------------------------ */
initial clk = 1'b1;
always  #(CLOCK_PERIOD/2) clk <= !clk;

initial begin
  repeat (`RUN_TIME) @ (posedge clk);
  $stop;
end

/* ------------------------------------------------------------------ */
/* Signal initialisation                                               */
/* ------------------------------------------------------------------ */
initial begin
  reset      = 1'b0;
  read       = 1'b0;
  write      = 1'b0;
  size       = 2'h2;
  mode       = 2'b11;
  address    = 32'hxxxx_xxxx;
  data_in    = 32'hxxxx_xxxx;
  port_in    = 32'hxxxx_xxxx;
  switch     = 4'h0;
  lcd_data_i = 8'h00;
end

always @ (posedge clk)
  if (reset) proc_read <= 1'b0;
  else       proc_read <= cs && read;
assign proc_data = proc_read ? data_out : 32'hxxxx_xxxx;

/* ------------------------------------------------------------------ */
/* Stimulus                                                            */
/* ------------------------------------------------------------------ */
initial begin
  reset_peripheral();

  /* ---- Test 1: Adder basic ---- */
  $display("--- Adder Test ---");
  peripheral_write_32bit(32'h0002_0000, 32'h0000_0007);  /* num1 = 7          */
  peripheral_write_32bit(32'h0002_0004, 32'h0000_0005);  /* num2 = 5          */
  @ (posedge clk);                                        /* wait for result   */
  peripheral_read_32bit (32'h0002_000C);                  /* expect 12 (0xC)   */

  @ (posedge clk);

  /* ---- Test 2: Adder overflow ---- */
  $display("--- Adder Overflow Test ---");
  peripheral_write_32bit(32'h0002_0000, 32'hFFFF_FFFF);
  peripheral_write_32bit(32'h0002_0004, 32'h0000_0001);
  @ (posedge clk);
  peripheral_read_32bit (32'h0002_000C);                  /* expect 0x00000000 */

  @ (posedge clk);

  /* ---- Test 3: Address calc — origin (0,0) ---- */
  /* Expected: 0x00100000 + 0*640 + 0 = 0x00100000 */
  $display("--- Pixel Address: (0,0) ---");
  peripheral_write_32bit(32'h0002_0014, 32'h0000_0000);  /* px_y = 0          */
  peripheral_write_32bit(32'h0002_0010, 32'h0000_0000);  /* px_x = 0          */
  @ (posedge clk);                                        /* wait for multiply */
  peripheral_read_32bit (32'h0002_0018);                  /* expect 0x00100000 */

  @ (posedge clk);

  /* ---- Test 4: Address calc — (100, 100) ---- */
  /* Expected: 0x00100000 + 100*640 + 100 = 0x00100000 + 64100 = 0x0010FA24  */
  $display("--- Pixel Address: (100,100) ---");
  peripheral_write_32bit(32'h0002_0014, 32'h0000_0064);  /* px_y = 100        */
  peripheral_write_32bit(32'h0002_0010, 32'h0000_0064);  /* px_x = 100        */
  @ (posedge clk);
  peripheral_read_32bit (32'h0002_0018);                  /* expect 0x0010FA24 */

  @ (posedge clk);

  /* ---- Test 5: Address calc — bottom-right corner (639, 479) ---- */
  /* Expected: 0x00100000 + 479*640 + 639 = 0x00100000 + 307199 = 0x0014AE7F */
  $display("--- Pixel Address: (639,479) ---");
  peripheral_write_32bit(32'h0002_0014, 32'h0000_01DF);  /* px_y = 479        */
  peripheral_write_32bit(32'h0002_0010, 32'h0000_027F);  /* px_x = 639        */
  @ (posedge clk);
  peripheral_read_32bit (32'h0002_0018);                  /* expect 0x0014AE7F */

  @ (posedge clk);

  /* ---- Test 6: Auto-increment on successive reads ---- */
  /* Set (0,0), read px_addr 4 times -> expect 0x100000, 1, 2, 3             */
  $display("--- Auto-increment test ---");
  peripheral_write_32bit(32'h0002_0014, 32'h0000_0000);  /* px_y = 0          */
  peripheral_write_32bit(32'h0002_0010, 32'h0000_0000);  /* px_x = 0          */
  @ (posedge clk);
  peripheral_read_32bit (32'h0002_0018);                  /* expect 0x00100000 */
  peripheral_read_32bit (32'h0002_0018);                  /* expect 0x00100001 */
  peripheral_read_32bit (32'h0002_0018);                  /* expect 0x00100002 */
  peripheral_read_32bit (32'h0002_0018);                  /* expect 0x00100003 */

  @ (posedge clk);

  /* ---- Test 7: px_reset cancels auto-increment ---- */
  $display("--- Reset auto-increment ---");
  peripheral_write_32bit(32'h0002_001C, 32'h0000_0001);  /* write px_reset    */
  peripheral_read_32bit (32'h0002_0018);                  /* expect 0x00100000 again */

  @ (posedge clk);

  $display("--- All tests done ---");
end

/* ------------------------------------------------------------------ */
/* CS decode                                                           */
/* ------------------------------------------------------------------ */
assign cs = address[31:16] === `USER_IO_SPACE;

/* ------------------------------------------------------------------ */
/* DUT instantiation                                                   */
/* ------------------------------------------------------------------ */
User_Peripheral DUT (
  .clk            (clk),
  .reset          (reset),
  .cs_i           (cs),
  .read_i         (read),
  .write_i        (write),
  .address_i      (address),
  .size_i         (size),
  .mode_i         (mode),
  .stall_o        (stall),
  .abort_o        (abort),
  .data_in        (data_in),
  .data_out       (data_out),
  .port_in        (port_in),
  .port_out       (port_out),
  .port_direction (port_direction),
  .LED_o          (LED),
  .LCD_data_o     (lcd_data_o),
  .LCD_data_i     (lcd_data_i),
  .LCD_RW_o       (lcd_rw_o),
  .LCD_RS_o       (lcd_rs_o),
  .LCD_E_o        (lcd_e_o),
  .LCD_BL_o       (lcd_bl_o),
  .switch_i       (switch),
  .irq_o          (irq)
);

/* ------------------------------------------------------------------ */
/* Tasks                                                               */
/* ------------------------------------------------------------------ */
task peripheral_write_32bit(input [31:0] write_address,
                             input [31:0] write_data);
begin
  $display("%t  WRITE 0x%h -> [0x%h]", $time, write_data, write_address);
  write   <= #1 1'b1;
  read    <= #1 1'b0;
  address <= #1 write_address;
  data_in <= #1 write_data;
  @ (posedge clk)
  write   <= #1 1'b0;
  address <= #1 32'hxxxx_xxxx;
  data_in <= #1 32'hxxxx_xxxx;
end
endtask

task peripheral_read_32bit(input [31:0] read_address);
begin
  write   <= #1 1'b0;
  read    <= #1 1'b1;
  address <= #1 read_address;
  data_in <= #1 32'hxxxx_xxxx;
  @ (posedge clk)
  #1 $display("%t  READ  0x%h <- [0x%h]", $time, data_out, read_address);
  read    <= #1 1'b0;
  address <= #1 32'hxxxx_xxxx;
end
endtask

task reset_peripheral();
begin
  @ (posedge clk) reset <= #1 1'b1;
  @ (posedge clk) reset <= #1 1'b0;
end
endtask

endmodule  // User_Testbench