/*----------------------------------------------------------------------------*/

module mmu #(parameter DATA_BUS = 0)
             (input  wire [31:0] address_i,
              input  wire  [1:0] mode_i,
              input  wire  [1:0] size_i,
              input  wire        read_i,
              input  wire        write_i,
              output reg   [2:0] abort_o,
              output reg         write_o,
              output reg         read_o);

reg abort_align, abort_access;

always @ (*)
begin

if (read_i || write_i)
  case (size_i)
    2'h1:    abort_align = (address_i[0]   != 1'h0);              /* Halfword */
    2'h2:    abort_align = (address_i[1:0] != 2'h0);              /* Word     */
    2'h3:    abort_align = (address_i[2:0] != 3'h0);              /* Double   */
    default: abort_align = 1'b0;
  endcase
else         abort_align = 1'b0;

abort_access = (read_i || write_i)
            && (mode_i == 2'h0) && (address_i[31:18] == 14'h0000);

if (abort_align)
  if (read_i) abort_o = `ABORT_LD_ALGN;
  else        abort_o = `ABORT_ST_ALGN;
else if (abort_access)                                 /* Prioritisation? @@@ */
  if (read_i) abort_o = `ABORT_LD_ACC;
  else        abort_o = `ABORT_ST_ACC;
else          abort_o = `ABORT_NONE;

read_o  = read_i  && (abort_o == `ABORT_NONE);
write_o = write_i && (abort_o == `ABORT_NONE);

end

endmodule

/*----------------------------------------------------------------------------*/
