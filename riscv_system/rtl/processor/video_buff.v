module video_buff(input  wire        clk,
                  input  wire        reset,
                  input  wire        vsync,                   /* Reset buffer */
                  output wire        nfull_o,        /* Request for more data */
                  input  wire        fifo_wr_i,            /* New data strobe */
                  input  wire [31:0] data_in,
                  output wire [31:0] data_out,
                  input  wire        fifo_rd_i);        /* Taking element out */

reg  [31:0] buffer [0:3];
reg   [1:0] head;
reg   [1:0] tail;
reg         empty;
wire        full;

assign full = ((tail == head) && !empty) || (tail + 2'h1 == head);
assign nfull_o = !full;

assign data_out = buffer[head];

always @ (posedge clk)
if (reset || vsync)
  begin
  head <= 2'h0;
  tail <= 2'h0;
  end
else
  begin
  if (fifo_rd_i) head <= head + 2'h1;
  if (fifo_wr_i)
    begin
    buffer[tail] <= data_in;
    tail <= tail + 2'h1;
    end
  end

always @ (posedge clk)
if (reset || vsync) empty <= 1'b1;
else
  if (empty && fifo_wr_i) empty <= 1'b0;
  else
    if (((head + 2'h1) == tail) && fifo_rd_i && !fifo_wr_i)
      empty <= 1'b1;

endmodule

/*----------------------------------------------------------------------------*/
