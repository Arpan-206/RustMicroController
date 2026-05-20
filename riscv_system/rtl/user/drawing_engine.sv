`timescale 1ns / 1ps

/*  Drawing Engine
    ==============
    CPU register map:
      0x00  X0 / cx        [9:0]
      0x04  Y0 / cy        [9:0]
      0x08  X1 / radius    [9:0]
      0x0C  Y1             [9:0]
      0x10  COLOUR         [7:0]
      0x14  OPCODE         1=RECT  2=CIRCLE  3=LINE  4=FILL_TRIANGLE
                           5=FILL_CIRCLE
      0x18  GO             write 1 -> start
      0x1C  STATUS         bit0=BUSY (read-only)
      0x20  X2             [9:0]  (triangle only)
      0x24  Y2             [9:0]  (triangle only)
      0x28  PARAM          [9:0]  (line thickness; 0 or 1 = hairline)

    Triangle fill — edge function bounding box rasteriser (winding-order agnostic)
    Filled circle — Bresenham octant walker drawing horizontal spans
    Thick line    — Bresenham centre line, rect stamp per pixel
*/

module drawing_engine (
    input  wire        clk,
    input  wire        reset_i,
    input  wire        cs_i,
    input  wire        read_i,
    input  wire        write_i,
    input  wire [31:0] address_i,
    input  wire [ 1:0] size_i,
    input  wire [ 1:0] mode_i,
    output wire        stall_o,
    output wire [ 2:0] abort_v_o,
    input  wire [31:0] data_in,
    output reg  [31:0] data_out,
    output wire [ 1:0] ireq_o,

    input wire [ 9:0] v_width_i,
    input wire [ 9:0] v_height_i,
    input wire [ 1:0] v_mode_i,
    input wire [17:0] v_base_i,

    output reg         de_req_o,
    output wire        de_RnW_o,
    output reg  [ 3:0] de_nbyte_o,
    input  wire        de_ack_i,
    output reg  [17:0] de_address_o,
    output wire [31:0] de_wr_data_o,
    input  wire [31:0] de_rd_data_i,

    output wire busy_o
);

  assign stall_o   = 1'b0;
  assign abort_v_o = 3'b000;
  assign ireq_o    = 2'b00;
  assign de_RnW_o  = 1'b0;

  reg [7:0] active_colour;
  assign de_wr_data_o = {4{active_colour}};

  localparam CMD_RECT = 3'd1;
  localparam CMD_CIRCLE = 3'd2;
  localparam CMD_LINE = 3'd3;
  localparam CMD_FILL_TRIANGLE = 3'd4;
  localparam CMD_FILL_CIRCLE = 3'd5;

  // ── CPU register file ──────────────────────────────────────────────────────
  reg [9:0] cfg_x0, cfg_y0, cfg_x1, cfg_y1, cfg_x2, cfg_y2, cfg_param;
  reg [7:0] cfg_colour;
  reg [2:0] cfg_opcode;

  wire cpu_write = cs_i && write_i;
  wire go_strobe = cpu_write && (address_i[5:0] == 6'h18) && data_in[0];

  always_ff @(posedge clk or posedge reset_i) begin
    if (reset_i) begin
      cfg_x0 <= 0;
      cfg_y0 <= 0;
      cfg_x1 <= 0;
      cfg_y1 <= 0;
      cfg_x2 <= 0;
      cfg_y2 <= 0;
      cfg_param <= 0;
      cfg_colour <= 8'hFF;
      cfg_opcode <= 3'd0;
    end else if (cpu_write) begin
      case (address_i[5:0])
        6'h00:   cfg_x0 <= data_in[9:0];
        6'h04:   cfg_y0 <= data_in[9:0];
        6'h08:   cfg_x1 <= data_in[9:0];
        6'h0C:   cfg_y1 <= data_in[9:0];
        6'h10:   cfg_colour <= data_in[7:0];
        6'h14:   cfg_opcode <= data_in[2:0];
        6'h20:   cfg_x2 <= data_in[9:0];
        6'h24:   cfg_y2 <= data_in[9:0];
        6'h28:   cfg_param <= data_in[9:0];
        default: ;
      endcase
    end
  end

  reg [5:0] addr_latched;
  always_ff @(posedge clk) if (cs_i && read_i) addr_latched <= address_i[5:0];

  always_comb begin
    case (addr_latched)
      6'h00:   data_out = {22'h0, cfg_x0};
      6'h04:   data_out = {22'h0, cfg_y0};
      6'h08:   data_out = {22'h0, cfg_x1};
      6'h0C:   data_out = {22'h0, cfg_y1};
      6'h10:   data_out = {24'h0, cfg_colour};
      6'h14:   data_out = {29'h0, cfg_opcode};
      6'h18:   data_out = 32'h0;
      6'h1C:   data_out = {31'h0, busy_o};
      6'h20:   data_out = {22'h0, cfg_x2};
      6'h24:   data_out = {22'h0, cfg_y2};
      6'h28:   data_out = {22'h0, cfg_param};
      default: data_out = 32'h0;
    endcase
  end

  // ── pixel address ──────────────────────────────────────────────────────────
  reg [10:0] pixel_x, pixel_y;

  wire [19:0] px_baddr = {v_base_i, 2'b00} + (20'(pixel_y[9:0]) * 20'd640) + {10'b0, pixel_x[9:0]};

  wire px_oob = pixel_x[10] | pixel_y[10] | (pixel_x[9:0] >= 10'd640) | (pixel_y[9:0] >= 10'd480);

  // ── rect registers ─────────────────────────────────────────────────────────
  reg [9:0] rect_x, rect_y, rect_x0, rect_y0, rect_x1, rect_y1;

  // ── circle (outline) registers ─────────────────────────────────────────────
  reg signed [10:0] c_x, c_y, c_err;
  reg [9:0] c_cx, c_cy;
  reg [2:0] c_oct;

  // ── filled circle registers ────────────────────────────────────────────────
  // Bresenham walker, but we draw horizontal spans instead of 8 points.
  // At each (bx, by) step we draw 4 spans:
  //   row cy+by : x from cx-bx to cx+bx
  //   row cy-by : x from cx-bx to cx+bx
  //   row cy+bx : x from cx-by to cx+by
  //   row cy-bx : x from cx-by to cx+by
  // We use a sub-FSM index (0-3) to sequence the four spans per step.
  reg signed [10:0] fc_bx, fc_by, fc_err;
  reg [9:0] fc_cx, fc_cy;
  reg [1:0] fc_span_idx;  // which of the 4 spans we're drawing
  reg [9:0] fc_span_cur;  // current X within span
  reg [9:0] fc_span_x0, fc_span_x1, fc_span_y;  // span bounds

  // ── line registers ─────────────────────────────────────────────────────────
  reg signed [10:0] l_x, l_y, l_x1, l_y1;
  reg signed [11:0] l_dx, l_dy, l_err;
  reg signed [10:0] l_sx, l_sy;
  // thick line: stamp rect around each centre pixel
  reg [9:0] l_thick;  // half-thickness = (param-1)/2
  reg [9:0] l_stamp_x, l_stamp_y;  // current stamp pixel
  reg [9:0] l_stamp_x0, l_stamp_y0, l_stamp_x1, l_stamp_y1;

  // ── triangle registers ─────────────────────────────────────────────────────
  reg signed [10:0] t_x0, t_y0, t_x1, t_y1, t_x2, t_y2;
  reg [9:0] t_bb_x0, t_bb_y0, t_bb_x1, t_bb_y1;
  reg [9:0] t_px, t_py;
  reg signed [10:0] t_a0, t_b0, t_a1, t_b1, t_a2, t_b2;

  wire signed [20:0] t_e0 = ($signed(
      {1'b0, t_px}
  ) - t_x0) * t_a0 - ($signed(
      {1'b0, t_py}
  ) - t_y0) * t_b0;
  wire signed [20:0] t_e1 = ($signed(
      {1'b0, t_px}
  ) - t_x1) * t_a1 - ($signed(
      {1'b0, t_py}
  ) - t_y1) * t_b1;
  wire signed [20:0] t_e2 = ($signed(
      {1'b0, t_px}
  ) - t_x2) * t_a2 - ($signed(
      {1'b0, t_py}
  ) - t_y2) * t_b2;

  wire t_inside = (t_e0 >= 0 && t_e1 >= 0 && t_e2 >= 0) || (t_e0 <= 0 && t_e1 <= 0 && t_e2 <= 0);

  // ── FSM ───────────────────────────────────────────────────────────────────
  typedef enum logic [3:0] {
    ST_IDLE,
    ST_START,
    ST_RECT,
    ST_CIRCLE_EMIT,
    ST_CIRCLE_ADV,
    ST_LINE,
    ST_LINE_STAMP,    // draw thick rect stamp, then return to ST_LINE
    ST_FCIRCLE_SPAN,  // draw one span of filled circle
    ST_FCIRCLE_NEXT,  // advance to next span or next Bresenham step
    ST_FCIRCLE_ADV,   // Bresenham step for filled circle
    ST_TRI_SETUP,
    ST_TRI_PIXEL,
    ST_PIXEL_WAIT,
    ST_DONE
  } ctrl_t;

  ctrl_t state, return_state;

  assign busy_o = (state != ST_IDLE) && (state != ST_DONE);

  // ── clamp helpers ──────────────────────────────────────────────────────────
  function automatic [9:0] clamp10;
    input signed [10:0] v;
    input [9:0] lo, hi;
    begin
      if (v < $signed({1'b0, lo})) clamp10 = lo;
      else if (v > $signed({1'b0, hi})) clamp10 = hi;
      else clamp10 = v[9:0];
    end
  endfunction

  always_ff @(posedge clk or posedge reset_i) begin
    if (reset_i) begin
      state <= ST_IDLE;
      return_state <= ST_IDLE;
      de_req_o <= 0;
      de_address_o <= 0;
      de_nbyte_o <= 4'hF;
      active_colour <= 0;
      c_oct <= 0;
      rect_x <= 0;
      rect_y <= 0;
      pixel_x <= 0;
      pixel_y <= 0;
    end else begin
      case (state)

        ST_IDLE: begin
          de_req_o <= 0;
          if (go_strobe) state <= ST_START;
        end

        ST_START: begin
          active_colour <= cfg_colour;
          case (cfg_opcode)

            CMD_RECT: begin
              rect_x0 <= cfg_x0;
              rect_y0 <= cfg_y0;
              rect_x1 <= cfg_x1;
              rect_y1 <= cfg_y1;
              rect_x  <= cfg_x0;
              rect_y  <= cfg_y0;
              state   <= ST_RECT;
            end

            CMD_CIRCLE: begin
              c_cx  <= cfg_x0;
              c_cy  <= cfg_y0;
              c_x   <= 11'sd0;
              c_y   <= {1'b0, cfg_x1};
              c_err <= {1'b0, cfg_x1} - 11'sd1;
              c_oct <= 0;
              state <= ST_CIRCLE_EMIT;
            end

            CMD_LINE: begin
              l_x <= {1'b0, cfg_x0};
              l_y <= {1'b0, cfg_y0};
              l_x1 <= {1'b0, cfg_x1};
              l_y1 <= {1'b0, cfg_y1};
              l_dx <= (cfg_x1 >= cfg_x0) ? {2'b0, cfg_x1 - cfg_x0} : {2'b0, cfg_x0 - cfg_x1};
              l_dy <= (cfg_y1 >= cfg_y0) ? -{2'b0, cfg_y1 - cfg_y0} : -{2'b0, cfg_y0 - cfg_y1};
              l_sx <= (cfg_x0 <= cfg_x1) ? 11'sd1 : -11'sd1;
              l_sy <= (cfg_y0 <= cfg_y1) ? 11'sd1 : -11'sd1;
              l_err<=(cfg_x1>=cfg_x0)?
                {2'b0,cfg_x1-cfg_x0}-{2'b0,(cfg_y1>=cfg_y0)?cfg_y1-cfg_y0:cfg_y0-cfg_y1}:
                {2'b0,cfg_x0-cfg_x1}-{2'b0,(cfg_y1>=cfg_y0)?cfg_y1-cfg_y0:cfg_y0-cfg_y1};
              // thickness: half = (param>1)?(param-1)/2 : 0
              l_thick <= (cfg_param > 10'd1) ? ((cfg_param - 10'd1) >> 1) : 10'd0;
              state <= ST_LINE;
            end

            CMD_FILL_TRIANGLE: begin
              t_x0  <= {1'b0, cfg_x0};
              t_y0  <= {1'b0, cfg_y0};
              t_x1  <= {1'b0, cfg_x1};
              t_y1  <= {1'b0, cfg_y1};
              t_x2  <= {1'b0, cfg_x2};
              t_y2  <= {1'b0, cfg_y2};
              state <= ST_TRI_SETUP;
            end

            CMD_FILL_CIRCLE: begin
              fc_cx <= cfg_x0;
              fc_cy <= cfg_y0;
              fc_bx <= 11'sd0;
              fc_by <= {1'b0, cfg_x1};
              fc_err <= {1'b0, cfg_x1} - 11'sd1;
              fc_span_idx <= 0;
              state <= ST_FCIRCLE_SPAN;
            end

            default: state <= ST_IDLE;
          endcase
        end

        // ── RECT ──────────────────────────────────────────────────────────
        ST_RECT: begin
          pixel_x <= {1'b0, rect_x};
          pixel_y <= {1'b0, rect_y};
          return_state <= ST_RECT;
          if (rect_x < rect_x1) rect_x <= rect_x + 1'b1;
          else if (rect_y < rect_y1) begin
            rect_x <= rect_x0;
            rect_y <= rect_y + 1'b1;
          end else return_state <= ST_DONE;
          state <= ST_PIXEL_WAIT;
        end

        // ── CIRCLE OUTLINE ────────────────────────────────────────────────
        ST_CIRCLE_EMIT: begin
          case (c_oct)
            3'd0: begin
              pixel_x <= {1'b0, c_cx} + c_x;
              pixel_y <= {1'b0, c_cy} + c_y;
            end
            3'd1: begin
              pixel_x <= {1'b0, c_cx} - c_x;
              pixel_y <= {1'b0, c_cy} + c_y;
            end
            3'd2: begin
              pixel_x <= {1'b0, c_cx} + c_x;
              pixel_y <= {1'b0, c_cy} - c_y;
            end
            3'd3: begin
              pixel_x <= {1'b0, c_cx} - c_x;
              pixel_y <= {1'b0, c_cy} - c_y;
            end
            3'd4: begin
              pixel_x <= {1'b0, c_cx} + c_y;
              pixel_y <= {1'b0, c_cy} + c_x;
            end
            3'd5: begin
              pixel_x <= {1'b0, c_cx} - c_y;
              pixel_y <= {1'b0, c_cy} + c_x;
            end
            3'd6: begin
              pixel_x <= {1'b0, c_cx} + c_y;
              pixel_y <= {1'b0, c_cy} - c_x;
            end
            3'd7: begin
              pixel_x <= {1'b0, c_cx} - c_y;
              pixel_y <= {1'b0, c_cy} - c_x;
            end
          endcase
          return_state <= (c_oct == 3'd7) ? ST_CIRCLE_ADV : ST_CIRCLE_EMIT;
          c_oct <= (c_oct == 3'd7) ? 3'd0 : c_oct + 3'd1;
          state <= ST_PIXEL_WAIT;
        end

        ST_CIRCLE_ADV: begin
          if (c_x > c_y) state <= ST_DONE;
          else begin
            if (c_err <= 11'sd0) begin
              c_err <= c_err + (c_x <<< 1) + 11'sd3;
              c_x   <= c_x + 11'sd1;
            end else begin
              c_err <= c_err + ((c_x - c_y) <<< 1) + 11'sd5;
              c_x   <= c_x + 11'sd1;
              c_y   <= c_y - 11'sd1;
            end
            state <= ST_CIRCLE_EMIT;
          end
        end

        // ── FILLED CIRCLE ─────────────────────────────────────────────────
        // Four horizontal spans per Bresenham step:
        //   idx 0: row cy+by, x: cx-bx..cx+bx
        //   idx 1: row cy-by, x: cx-bx..cx+bx
        //   idx 2: row cy+bx, x: cx-by..cx+by
        //   idx 3: row cy-bx, x: cx-by..cx+by
        // Skip duplicate rows when bx==by (45-degree point).
        ST_FCIRCLE_SPAN: begin
          // Compute span for current idx
          case (fc_span_idx)
            2'd0: begin
              fc_span_y  <= clamp10({1'b0, fc_cy} + fc_by, 0, 479);
              fc_span_x0 <= clamp10({1'b0, fc_cx} - fc_bx, 0, 639);
              fc_span_x1 <= clamp10({1'b0, fc_cx} + fc_bx, 0, 639);
            end
            2'd1: begin
              fc_span_y  <= clamp10({1'b0, fc_cy} - fc_by, 0, 479);
              fc_span_x0 <= clamp10({1'b0, fc_cx} - fc_bx, 0, 639);
              fc_span_x1 <= clamp10({1'b0, fc_cx} + fc_bx, 0, 639);
            end
            2'd2: begin
              fc_span_y  <= clamp10({1'b0, fc_cy} + fc_bx, 0, 479);
              fc_span_x0 <= clamp10({1'b0, fc_cx} - fc_by, 0, 639);
              fc_span_x1 <= clamp10({1'b0, fc_cx} + fc_by, 0, 639);
            end
            2'd3: begin
              fc_span_y  <= clamp10({1'b0, fc_cy} - fc_bx, 0, 479);
              fc_span_x0 <= clamp10({1'b0, fc_cx} - fc_by, 0, 639);
              fc_span_x1 <= clamp10({1'b0, fc_cx} + fc_by, 0, 639);
            end
          endcase
          // Set cursor to left of span — draw starts next cycle
          fc_span_cur <= clamp10({1'b0, fc_cx} - (fc_span_idx[1] ? fc_by : fc_bx), 0, 639);
          state <= ST_FCIRCLE_NEXT;
        end

        ST_FCIRCLE_NEXT: begin
          if (fc_span_cur <= fc_span_x1) begin
            // Draw current pixel of span
            pixel_x <= {1'b0, fc_span_cur};
            pixel_y <= {1'b0, fc_span_y};
            fc_span_cur <= fc_span_cur + 10'd1;
            return_state <= ST_FCIRCLE_NEXT;
            state <= ST_PIXEL_WAIT;
          end else begin
            // Span done — move to next span idx or Bresenham step
            if (fc_span_idx == 2'd3) begin
              fc_span_idx <= 0;
              state <= ST_FCIRCLE_ADV;
            end else begin
              fc_span_idx <= fc_span_idx + 2'd1;
              state <= ST_FCIRCLE_SPAN;
            end
          end
        end

        ST_FCIRCLE_ADV: begin
          if (fc_bx > fc_by) state <= ST_DONE;
          else begin
            if (fc_err <= 11'sd0) begin
              fc_err <= fc_err + (fc_bx <<< 1) + 11'sd3;
              fc_bx  <= fc_bx + 11'sd1;
            end else begin
              fc_err <= fc_err + ((fc_bx - fc_by) <<< 1) + 11'sd5;
              fc_bx  <= fc_bx + 11'sd1;
              fc_by  <= fc_by - 11'sd1;
            end
            state <= ST_FCIRCLE_SPAN;
          end
        end

        // ── LINE (hairline + thick) ────────────────────────────────────────
        ST_LINE: begin
          if (l_thick == 0) begin
            // Hairline — draw single pixel
            pixel_x <= l_x;
            pixel_y <= l_y;
            return_state <= (l_x == l_x1 && l_y == l_y1) ? ST_DONE : ST_LINE;
          end else begin
            // Thick — set up stamp rect centred on (l_x, l_y)
            l_stamp_x0 <= clamp10(l_x - {1'b0, l_thick}, 0, 639);
            l_stamp_y0 <= clamp10(l_y - {1'b0, l_thick}, 0, 479);
            l_stamp_x1 <= clamp10(l_x + {1'b0, l_thick}, 0, 639);
            l_stamp_y1 <= clamp10(l_y + {1'b0, l_thick}, 0, 479);
            l_stamp_x <= clamp10(l_x - {1'b0, l_thick}, 0, 639);
            l_stamp_y <= clamp10(l_y - {1'b0, l_thick}, 0, 479);
            return_state <= (l_x == l_x1 && l_y == l_y1) ? ST_DONE : ST_LINE;
            state <= ST_LINE_STAMP;
          end
          // Advance Bresenham (runs regardless, takes effect next cycle)
          if (l_x != l_x1 || l_y != l_y1) begin
            if (($signed(
                    l_err
                ) <<< 1) > $signed(
                    l_dy
                ) && ($signed(
                    l_err
                ) <<< 1) < $signed(
                    l_dx
                )) begin
              l_err <= l_err + l_dy + l_dx;
              l_x   <= l_x + l_sx;
              l_y   <= l_y + l_sy;
            end else if (($signed(l_err) <<< 1) > $signed(l_dy)) begin
              l_err <= l_err + l_dy;
              l_x   <= l_x + l_sx;
            end else begin
              l_err <= l_err + l_dx;
              l_y   <= l_y + l_sy;
            end
          end
          if (l_thick == 0) state <= ST_PIXEL_WAIT;
        end

        // Draw stamp rect pixel by pixel, then jump to return_state
        ST_LINE_STAMP: begin
          pixel_x <= {1'b0, l_stamp_x};
          pixel_y <= {1'b0, l_stamp_y};
          if (l_stamp_x < l_stamp_x1) l_stamp_x <= l_stamp_x + 10'd1;
          else if (l_stamp_y < l_stamp_y1) begin
            l_stamp_x <= l_stamp_x0;
            l_stamp_y <= l_stamp_y + 10'd1;
          end else state <= return_state;  // stamp done — back to ST_LINE or ST_DONE
          if (state == ST_LINE_STAMP) begin
            // Only go to PIXEL_WAIT if we haven't just transitioned to return
            if (!(l_stamp_x >= l_stamp_x1 && l_stamp_y >= l_stamp_y1)) state <= ST_PIXEL_WAIT;
            return_state <= ST_LINE_STAMP;
          end
        end

        // ── TRIANGLE SETUP ────────────────────────────────────────────────
        ST_TRI_SETUP: begin
          t_a0 <= t_y1 - t_y0;
          t_b0 <= t_x1 - t_x0;
          t_a1 <= t_y2 - t_y1;
          t_b1 <= t_x2 - t_x1;
          t_a2 <= t_y0 - t_y2;
          t_b2 <= t_x0 - t_x2;
          t_bb_x0<=(cfg_x0<=cfg_x1)?((cfg_x0<=cfg_x2)?cfg_x0:cfg_x2):((cfg_x1<=cfg_x2)?cfg_x1:cfg_x2);
          t_bb_y0<=(cfg_y0<=cfg_y1)?((cfg_y0<=cfg_y2)?cfg_y0:cfg_y2):((cfg_y1<=cfg_y2)?cfg_y1:cfg_y2);
          t_bb_x1<=(cfg_x0>=cfg_x1)?((cfg_x0>=cfg_x2)?cfg_x0:cfg_x2):((cfg_x1>=cfg_x2)?cfg_x1:cfg_x2);
          t_bb_y1<=(cfg_y0>=cfg_y1)?((cfg_y0>=cfg_y2)?cfg_y0:cfg_y2):((cfg_y1>=cfg_y2)?cfg_y1:cfg_y2);
          t_px<=(cfg_x0<=cfg_x1)?((cfg_x0<=cfg_x2)?cfg_x0:cfg_x2):((cfg_x1<=cfg_x2)?cfg_x1:cfg_x2);
          t_py<=(cfg_y0<=cfg_y1)?((cfg_y0<=cfg_y2)?cfg_y0:cfg_y2):((cfg_y1<=cfg_y2)?cfg_y1:cfg_y2);
          state <= ST_TRI_PIXEL;
        end

        // ── TRIANGLE PIXEL ────────────────────────────────────────────────
        ST_TRI_PIXEL: begin
          if (t_inside) begin
            pixel_x <= {1'b0, t_px};
            pixel_y <= {1'b0, t_py};
            return_state <= ST_TRI_PIXEL;
            state <= ST_PIXEL_WAIT;
          end
          if (state == ST_TRI_PIXEL) begin
            if (t_px < t_bb_x1) t_px <= t_px + 10'd1;
            else if (t_py < t_bb_y1) begin
              t_px <= t_bb_x0;
              t_py <= t_py + 10'd1;
            end else state <= ST_DONE;
          end
        end

        // ── PIXEL WAIT ────────────────────────────────────────────────────
        ST_PIXEL_WAIT: begin
          if (!de_req_o) begin
            if (px_oob) state <= return_state;
            else begin
              de_address_o <= px_baddr[19:2];
              de_nbyte_o <= ~(4'b0001 << px_baddr[1:0]);
              de_req_o <= 1'b1;
            end
          end else if (de_ack_i) begin
            de_req_o <= 1'b0;
            state <= return_state;
          end
        end

        ST_DONE: begin
          de_req_o <= 0;
          state <= ST_IDLE;
        end
        default: state <= ST_IDLE;
      endcase
    end
  end

endmodule
