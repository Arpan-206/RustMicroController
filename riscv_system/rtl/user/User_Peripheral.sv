`timescale 1ns / 1ps

module User_Peripheral (
    input  wire        clk,
    input  wire        reset,
    input  wire        cs_i,
    input  wire        read_i,
    input  wire [ 1:0] size_i,
    input  wire        write_i,
    input  wire [ 1:0] mode_i,
    input  wire [31:0] address_i,
    output wire        stall_o,
    output wire [ 2:0] abort_o,
    input  wire [31:0] data_in,
    output reg  [31:0] data_out,

    input  wire [31:0] port_in,
    output wire [31:0] port_out,
    output wire [31:0] port_direction,
    output wire [ 7:0] LED_o,

    output wire [7:0] LCD_data_o,
    input  wire [7:0] LCD_data_i,
    output wire       LCD_RW_o,
    output wire       LCD_RS_o,
    output wire       LCD_E_o,
    output wire       LCD_BL_o,

    input  wire [3:0] switch_i,
    output wire [3:0] irq_o,

    input wire [ 9:0] v_width_i,
    input wire [ 9:0] v_height_i,
    input wire [ 1:0] v_mode_i,
    input wire [17:0] v_base_i,

    output wire        de_req_o,
    output wire        de_RnW_o,
    output wire [ 3:0] de_nbyte_o,
    input  wire        de_ack_i,
    output wire [17:0] de_address_o,
    output wire [31:0] de_wr_data_o,
    input  wire [31:0] de_rd_data_i
);

  assign stall_o        = 1'b0;
  assign abort_o        = 3'b000;
  assign port_out       = 32'h0;
  assign port_direction = 32'hFFFF_FFFF;
  assign LED_o          = 8'h00;
  assign irq_o          = 4'b0000;
  assign LCD_data_o     = 8'h00;
  assign LCD_RW_o       = 1'b1;
  assign LCD_RS_o       = 1'b0;
  assign LCD_E_o        = 1'b0;
  assign LCD_BL_o       = 1'b0;

  // ── CPU register file ──────────────────────────────────────────────────────
  // Word byte offsets:
  //   0x00=X0  0x04=Y0  0x08=X1  0x0C=Y1
  //   0x10=COLOUR  0x14=OPCODE  0x18=GO  0x1C=STATUS
  //   0x20=X2  0x24=Y2  0x28=PARAM
  reg [31:0] reg_x0, reg_y0, reg_x1, reg_y1;
  reg [31:0] reg_colour, reg_opcode;
  reg [31:0] reg_x2, reg_y2, reg_param;
  reg [31:0] reg_status;
  reg [ 7:0] addr_latched;

  always_ff @(posedge clk) if (cs_i && read_i) addr_latched <= address_i[7:0];

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      reg_x0 <= 0;
      reg_y0 <= 0;
      reg_x1 <= 0;
      reg_y1 <= 0;
      reg_colour <= 0;
      reg_opcode <= 0;
      reg_x2 <= 0;
      reg_y2 <= 0;
      reg_param <= 0;
    end else if (cs_i && write_i) begin
      case (address_i[5:2])
        4'd0:    reg_x0 <= data_in;
        4'd1:    reg_y0 <= data_in;
        4'd2:    reg_x1 <= data_in;
        4'd3:    reg_y1 <= data_in;
        4'd4:    reg_colour <= data_in;
        4'd5:    reg_opcode <= data_in;
        // 4'd6 = GO strobe, no register
        4'd8:    reg_x2 <= data_in;  // 0x20
        4'd9:    reg_y2 <= data_in;  // 0x24
        4'd10:   reg_param <= data_in;  // 0x28
        default: ;
      endcase
    end
  end

  always_comb begin
    case (addr_latched[5:2])
      4'd0: data_out = reg_x0;
      4'd1: data_out = reg_y0;
      4'd2: data_out = reg_x1;
      4'd3: data_out = reg_y1;
      4'd4: data_out = reg_colour;
      4'd5: data_out = reg_opcode;
      4'd6: data_out = 32'h0;
      4'd7: data_out = reg_status;
      4'd8: data_out = reg_x2;
      4'd9: data_out = reg_y2;
      4'd10: data_out = reg_param;
      default: data_out = 32'h0;
    endcase
  end

  // ── sequencer ─────────────────────────────────────────────────────────────
  reg de_cs_r, de_write_r;
  reg [31:0] de_addr_r, de_din_r;

  wire        de_stall_w;
  wire [ 2:0] de_abort_w;
  wire [31:0] de_data_out_w;
  wire [ 1:0] de_ireq_w;
  wire        de_busy_w;

  localparam [31:0] DE_X0 = 32'h00;
  localparam [31:0] DE_Y0 = 32'h04;
  localparam [31:0] DE_X1 = 32'h08;
  localparam [31:0] DE_Y1 = 32'h0C;
  localparam [31:0] DE_COLOUR = 32'h10;
  localparam [31:0] DE_OPCODE = 32'h14;
  localparam [31:0] DE_GO = 32'h18;
  localparam [31:0] DE_X2 = 32'h20;
  localparam [31:0] DE_Y2 = 32'h24;
  localparam [31:0] DE_PARAM = 32'h28;

  localparam [31:0] CMD_FILL_TRIANGLE = 32'd4;
  localparam [31:0] CMD_LINE = 32'd3;

  typedef enum logic [4:0] {
    UP_IDLE,
    UP_WR_X0,
    UP_WR_Y0,
    UP_WR_X1,
    UP_WR_Y1,
    UP_WR_COLOUR,
    UP_WR_OPCODE,
    UP_WR_X2,      // triangle only
    UP_WR_Y2,      // triangle only
    UP_WR_PARAM,   // line (thickness) only
    UP_WR_GO,
    UP_WAIT_BUSY,
    UP_WAIT_DONE
  } up_state_t;

  up_state_t up_state;

  wire cpu_go = cs_i && write_i && (address_i[5:2] == 4'd6) && data_in[0];

  reg is_triangle, is_line;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      up_state <= UP_IDLE;
      de_cs_r <= 0;
      de_write_r <= 0;
      de_addr_r <= 0;
      de_din_r <= 0;
      reg_status <= 0;
      is_triangle <= 0;
      is_line <= 0;
    end else begin
      de_cs_r <= 0;
      de_write_r <= 0;

      case (up_state)

        UP_IDLE: begin
          if (cpu_go) begin
            reg_status  <= 32'h1;
            is_triangle <= (reg_opcode == CMD_FILL_TRIANGLE);
            is_line     <= (reg_opcode == CMD_LINE);
            up_state    <= UP_WR_X0;
          end
        end

        UP_WR_X0: begin
          de_cs_r <= 1;
          de_write_r <= 1;
          de_addr_r <= DE_X0;
          de_din_r <= reg_x0;
          up_state <= UP_WR_Y0;
        end
        UP_WR_Y0: begin
          de_cs_r <= 1;
          de_write_r <= 1;
          de_addr_r <= DE_Y0;
          de_din_r <= reg_y0;
          up_state <= UP_WR_X1;
        end
        UP_WR_X1: begin
          de_cs_r <= 1;
          de_write_r <= 1;
          de_addr_r <= DE_X1;
          de_din_r <= reg_x1;
          up_state <= UP_WR_Y1;
        end
        UP_WR_Y1: begin
          de_cs_r <= 1;
          de_write_r <= 1;
          de_addr_r <= DE_Y1;
          de_din_r <= reg_y1;
          up_state <= UP_WR_COLOUR;
        end
        UP_WR_COLOUR: begin
          de_cs_r <= 1;
          de_write_r <= 1;
          de_addr_r <= DE_COLOUR;
          de_din_r <= reg_colour;
          up_state <= UP_WR_OPCODE;
        end
        UP_WR_OPCODE: begin
          de_cs_r <= 1;
          de_write_r <= 1;
          de_addr_r <= DE_OPCODE;
          de_din_r <= reg_opcode;
          // Route: triangle -> X2, line -> PARAM, else -> GO
          if (is_triangle) up_state <= UP_WR_X2;
          else if (is_line) up_state <= UP_WR_PARAM;
          else up_state <= UP_WR_GO;
        end

        UP_WR_X2: begin
          de_cs_r <= 1;
          de_write_r <= 1;
          de_addr_r <= DE_X2;
          de_din_r <= reg_x2;
          up_state <= UP_WR_Y2;
        end
        UP_WR_Y2: begin
          de_cs_r <= 1;
          de_write_r <= 1;
          de_addr_r <= DE_Y2;
          de_din_r <= reg_y2;
          up_state <= UP_WR_GO;
        end

        UP_WR_PARAM: begin
          de_cs_r <= 1;
          de_write_r <= 1;
          de_addr_r <= DE_PARAM;
          de_din_r <= reg_param;
          up_state <= UP_WR_GO;
        end

        UP_WR_GO: begin
          de_cs_r <= 1;
          de_write_r <= 1;
          de_addr_r <= DE_GO;
          de_din_r <= 32'h1;
          up_state <= UP_WAIT_BUSY;
        end
        UP_WAIT_BUSY: up_state <= UP_WAIT_DONE;
        UP_WAIT_DONE: begin
          if (!de_busy_w) begin
            reg_status <= 32'h2;
            up_state   <= UP_IDLE;
          end
        end

        default: up_state <= UP_IDLE;
      endcase
    end
  end

  // ── drawing_engine ─────────────────────────────────────────────────────────
  drawing_engine drawing_engine_i (
      .clk(clk),
      .reset_i(reset),
      .cs_i(de_cs_r),
      .read_i(1'b0),
      .write_i(de_write_r),
      .address_i(de_addr_r),
      .size_i(2'b10),
      .mode_i(mode_i),
      .stall_o(de_stall_w),
      .abort_v_o(de_abort_w),
      .data_in(de_din_r),
      .data_out(de_data_out_w),
      .ireq_o(de_ireq_w),
      .v_width_i(v_width_i),
      .v_height_i(v_height_i),
      .v_mode_i(v_mode_i),
      .v_base_i(v_base_i),
      .de_req_o(de_req_o),
      .de_RnW_o(de_RnW_o),
      .de_nbyte_o(de_nbyte_o),
      .de_ack_i(de_ack_i),
      .de_address_o(de_address_o),
      .de_wr_data_o(de_wr_data_o),
      .de_rd_data_i(de_rd_data_i),
      .busy_o(de_busy_w)
  );

endmodule
