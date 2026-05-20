/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
/* True UART used only by master for host communications                      */

// Add break detector (>10 bits low)? @@@
// If so, add 'send break' too! @@@	TEST TSET TEST

module uart #(parameter CLOCK_FREQ = 32'd20_000_000,
              parameter BAUD       = 32'd115_200)
            (input  wire        clk,
             input  wire        reset,

             input  wire        cs_i,
             input  wire        read_i,
             input  wire        write_i,
             input  wire [31:0] address_i,
             input  wire  [1:0] mode_i,	// All bus signals not ported (yet?) @@@
             input  wire  [1:0] size_i,
             output wire        stall_o,
             output wire  [2:0] abort_v_o,
             input  wire [31:0] data_in,
             output reg  [31:0] data_out,

             output wire        int_rx,
             output wire        int_tx,
             output wire        int_error,

             input  wire        rx_din,                     /* Serial data in */
             output wire        tx_dout);                  /* Serial data out */

localparam BAUD_DIVISION = (CLOCK_FREQ + (8*BAUD)) / (16*BAUD); /* 16x sample */

assign stall_o   =    cs_i   && 1'b0;
assign abort_v_o = {3{cs_i}} && 3'h0;

reg  [15:0] baud_rate;
reg   [7:0] ctrl, reg_3;

reg  [15:0] divider;                            /* Baud rate divider: counter */
wire        div_wrap;                            /* Baud rate divider: output */
wire        en;                        /* Serial FSMs enable (clock division) */

reg   [3:0] rx_sample;                                      /* 16x oversample */
reg         rx_active;                                  /* Start bit detected */
reg   [3:0] rx_bits;                                     /* Input bit counter */
wire        rx_sample_point;                    /* Midway through Rx bit time */
wire        rx_stop;                            /* Rx stop bit time indicator */
reg   [7:0] rx_shift;                                    /* Rx shift register */
reg   [7:0] rx_hold;                                   /* Rx holding register */
wire        rx_rdy;                             /* Status bit - from register */
wire        rx_framing;                     /* Logic feed for status register */
wire        rx_overrun;                     /* Logic feed for status register */

reg   [3:0] tx_sample;                                      /* 16x oversample */
reg         tx_active;                                  /* Start bit detected */
reg   [3:0] tx_bits;                                     /* Input bit counter */
wire        tx_sample_point;                            /* End of Tx bit time */
wire        tx_start;                               /* Load Tx shift register */
wire        tx_stop;                                    /* End of Tx stop bit */
reg   [8:0] tx_shift;                   /* Tx shift register (inc. start bit) */
reg   [7:0] tx_hold;                                   /* Tx holding register */
wire        tx_full;                                   /* Status bit: latched */

reg   [7:0] status;                                        /* Status register */
wire        rx_rd;
wire        tx_wr;

always @ (posedge clk)                                     /* Register writes */
if (reset)
  begin
  tx_hold   <= 8'h00;
  baud_rate <= BAUD_DIVISION;
  ctrl      <= 8'h00;
  end
else
  if (cs_i && write_i)
    case (address_i[3:2])
      2'h0: baud_rate <= data_in[15:0];
      2'h1: ctrl      <= data_in[7:0];
      2'h2: tx_hold   <= data_in[7:0];
      2'h3: reg_3     <= data_in[7:0];
    endcase

always @ (posedge clk)                                      /* Register reads */
if (cs_i && read_i)
  case (address_i[3:2])
    2'h0: data_out <= {16'h0000, baud_rate};
    2'h1: data_out <= {24'h0000_00, ctrl};
    2'h2: data_out <= {24'h0000_00, rx_hold};
    2'h3: data_out <= {24'h0000_00, status};
  endcase
else      data_out <= 32'hxxxx_xxxx;

assign rx_rd = (cs_i && read_i)  && (address_i[3:2] == 2'h2);
assign tx_wr = (cs_i && write_i) && (address_i[3:2] == 2'h2);

assign int_rx    =  status[0]   && ctrl[0];              /* Interrupt enables */
assign int_error = |status[2:1] && ctrl[1];
assign int_tx    =  status[4]   && ctrl[4];

/* . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .*/
/* Baud-rate (x16) divider                                                    */

assign div_wrap = divider == 16'h0000;                /* Clock divider pulses */

always @ (posedge clk)          /* "Programmable" @@@  */
begin
if (reset)         divider <= baud_rate - 16'h0001;
else if (div_wrap) divider <= baud_rate - 16'h0001;
else               divider <= divider   - 16'h0001;
end

assign en = div_wrap;        /* Enable one clock pulse at baud rate intervals */

always @ (posedge clk)
begin
if (reset) status = 8'h10;                                 /* Tx Ready (only) */
else
  begin
  if (rx_rd) status[3:0] <= 4'h0;
  else
    if (en && rx_sample_point)
      begin
      if (rx_stop)    status[0] <= 1'b1;
      if (rx_framing) status[1] <= 1'b1;
      if (rx_overrun) status[2] <= 1'b1;
      end

    // Other (e.g. status) clears etc. @@@
    if (en && tx_start) status[4] <= 1'b1;   /* Start new Tx byte;  empty TxH */
    else if (tx_wr)     status[4] <= 1'b0;
  end
end

assign rx_rdy  =  status[0];
assign tx_full = !status[4];                 /* If not ready then TxH is full */

/* . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .*/
/* Receiver                                                                   */

assign rx_sample_point = rx_sample == 4'h7;    /* Sets position of bit sample */
assign rx_stop         = rx_bits == 4'h9;      /* 0 = start bit; 9 = stop bit */
assign rx_framing      = rx_stop && !rx_din;
assign rx_overrun      = rx_stop && rx_rdy;

always @ (posedge clk)
begin
if (reset)
  begin
  rx_sample <= 4'h0;                             /* /16 counter for baud rate */
  rx_active <= 1'b0;                                              /* Inactive */
  rx_bits   <= 4'h0;                                    /* Output bit counter */
  end
else
  if (en)                                /* Time for another serial subsample */
    begin
    if (rx_active) rx_sample <= rx_sample + 4'h1;        /* Subsample counter */
    else           rx_sample <= 4'h0;

    if ((rx_sample == 4'h0) && !rx_din)  rx_active <= 1'b1;   /* Start detect */
    else if (rx_sample_point && rx_stop) rx_active <= 1'b0;    /* Stop detect */

    if (rx_sample_point)
      if (rx_stop)        rx_bits <= 4'h0;             /* Reset for next time */
      else if (rx_active) rx_bits <= rx_bits + 4'h1;           /* Bit counter */
    end
  end

always @ (posedge clk)
if (en)
  begin
  if (rx_stop)         rx_hold  <=  rx_shift;    /* Input to holding register */
  if (rx_sample_point) rx_shift <= {rx_din, rx_shift} >> 1;     /* Rx shifter */
  end                                          /* See status[] for rx_rdy bit */

/* . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . .*/
/* Transmitter                                                                */

assign tx_sample_point = tx_sample == 4'h0;
assign tx_start        = tx_full && (!tx_active || tx_stop);
assign tx_stop         = tx_sample_point && (tx_bits == 4'h9);

always @ (posedge clk)
begin
if (reset)
  begin
  tx_sample <= 4'h0;                             /* /16 counter for baud rate */
  tx_active <= 1'b0;                                              /* Inactive */
  tx_bits   <= 4'hF;                   /* Big value - above stop bit position */
  end
else
  if (en)                                /* Time for another serial subsample */
    begin                                   /* Count while active, else reset */
    if (tx_start || (tx_active && !tx_stop)) tx_sample <= tx_sample + 4'h1;
    else                                     tx_sample <= 4'h0;

    if (tx_start) tx_active <= 1'b1; /* If there's character waiting and free */
    else if (tx_stop) tx_active <= 1'b0;     /* else done; else retain status */

    if (tx_sample_point)                    /* Change at end of 16 subsamples */
      if (tx_start)       tx_bits <= 4'h0;                  /* Tx bit counter */
      else if (tx_active) tx_bits <= tx_bits + 4'h1;
    end
  end

always @ (posedge clk)
if (reset) tx_shift <= 9'h1FF;                     /* Sets Tx output inactive */
else
  if (en)                                      /* Maybe time for another bit? */
    begin
    if (tx_start)             tx_shift <= {tx_hold, 1'b0};      /* New output */
    else if (tx_sample_point) tx_shift <= {1'b1, tx_shift} >> 1;     /* Shift */
    end                                        /* See status[] for Tx_rdy bit */

assign tx_dout = tx_shift[0];                         /* Tx output from 'LSB' */

endmodule  // uart

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
