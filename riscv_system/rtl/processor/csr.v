/*----------------------------------------------------------------------------*/
/* Developing .... ****                                                       */

// Make a bit map which indicates which CSRs are implemented  @@@
// Decoder can use this to insert 'illegal ops.' when not present.

module csr(input  wire        clk,
           input  wire        reset,
           input  wire [31:0] interrupts_i,
           output wire [31:0] interrupts_o,
           input  wire  [1:0] mode_i,
           input  wire        csr_rd_i,
           input  wire        csr_wr_i,
           input  wire        csr_trap_i,                  /* Exception entry */
           input  wire        csr_ret_i,                  /* Exception return */
           input  wire  [2:0] csr_fn_i,
           input  wire [31:0] data_in,
           input  wire [31:0] tval_i,
           input  wire [11:0] address_i,              /* CSR address, that is */
           output reg  [31:0] data_out,
           input  wire  [1:0] epc_sel_i,  /* Mode used to read jump addresses */
           input  wire  [5:0] trap_cause_i,   /* Used find delegate mode etc. */
           output reg   [1:0] new_mode_o,        /* Mode handler delegated to */
           output reg  [31:0] trap_vector_o,
           output wire [31:0] status_o,
           output wire [31:0] isa_o,
           input  wire [63:0] mtime_i,
           input  wire        exec_done_i, /*Instr. finished in execute stage */
           input  wire        mem_done_i,   /*Instr. finished in memory stage */
           input  wire        retiring_i);                 /* Register writes */

reg  [31:0] USTATUSH;			// Does this now exist? *****
reg  [31:0] UIE, UTVEC, USCRATCH, UEPC, UCAUSE, UTVAL;
reg  [31:0] SSTATUSH;
reg  [31:0] SSCRATCH, SEPC, SCAUSE, STVAL;
reg  [31:0] SEDELEG, SIDELEG, SIE, STVEC, SCOUNTEREN;
reg  [31:0] MISA;
reg  [31:0] MSTATUSH;
reg  [31:0] MSCRATCH, MEPC, MCAUSE, MTVAL;
reg  [31:0] MTVEC, MCOUNTEREN;
reg  [31:0] MEDELEG, MIDELEG, MIE, MIP, MCOUNTINHIBIT;
reg  [63:0] CYCLE, INSTRET;
//reg  [63:0] TIME;
wire [63:0] TIME;

// Note: unimplemented register access attempts should cause 'illegal' traps ***

reg  TSR, TW, TVM, MXR, SUM, MPRV, SPP, MPIE, UBE, SPIE, UPIE, MIEf, SIEf, UIEf;
reg   [1:0] XS, FS, MPP, VS;                                   /* Status bits */

wire [31:0] mstatus_out, sstatus_out, ustatus_out;
wire        write_status;

reg  [31:0] old_data, new_data;
wire [31:0] new_cause;

wire        csr_wr;

wire  [1:0] instr_done;           /* Count of instructions retired this cycle */

reg         vectord;                           /* Interrupt entry is vectored */
reg   [1:0] new_mode;                      /* Temporary intermediate variable */

assign TIME = mtime_i;

assign instr_done = {1'b0,exec_done_i} + {1'b0,retiring_i} + {1'b0,mem_done_i};
				// Check TRAPS, CSRs & poss. others. *****

assign csr_wr = (csr_wr_i && !(&address_i[11:10]));       /* Write protection */
					// Can incorporate mode later *****

assign mstatus_out = {(|VS || |FS || |XS), 8'h00, TSR, TW, TVM, MXR, SUM, MPRV,
                      XS, FS, MPP, VS, SPP,
                      MPIE, UBE, SPIE, UPIE, MIEf, 1'b0, SIEf, UIEf};

assign sstatus_out = mstatus_out & 32'h800D_E133;
assign ustatus_out = sstatus_out & 32'h8000_0011;

assign write_status = csr_wr_i && ((address_i == `ADDR_MSTATUS)
                                || (address_i == `ADDR_SSTATUS)
                                || (address_i == `ADDR_USTATUS));

assign interrupts_o = (MIP | interrupts_i) & MIE & `MIP_READ_MASK;

always @ (*)	// Qualify with read enable if side effects ****
case (address_i)                                          /* Read multiplexer */
  `ADDR_USTATUS:       old_data = ustatus_out;
  `ADDR_UIE:           old_data = UIE;
  `ADDR_UTVEC:         old_data = UTVEC;
  `ADDR_USTATUSH:      old_data = USTATUSH;
  `ADDR_USCRATCH:      old_data = USCRATCH;
  `ADDR_UEPC:          old_data = UEPC;
  `ADDR_UCAUSE:        old_data = UCAUSE;
  `ADDR_UTVAL:         old_data = UTVAL;
  `ADDR_SSTATUS:       old_data = sstatus_out;
  `ADDR_SEDELEG:       old_data = SEDELEG;
  `ADDR_SIDELEG:       old_data = SIDELEG;
  `ADDR_SIE:           old_data = SIE;
  `ADDR_STVEC:         old_data = STVEC;
  `ADDR_SCOUNTEREN:    old_data = SCOUNTEREN;
  `ADDR_SSTATUSH:      old_data = SSTATUSH;
  `ADDR_SSCRATCH:      old_data = SSCRATCH;
  `ADDR_SEPC:          old_data = SEPC;
  `ADDR_SCAUSE:        old_data = SCAUSE;
  `ADDR_STVAL:         old_data = STVAL;
  `ADDR_MSTATUS:       old_data = mstatus_out;
  `ADDR_MISA:          old_data = MISA;
  `ADDR_MEDELEG:       old_data = MEDELEG;
  `ADDR_MIDELEG:       old_data = MIDELEG;
  `ADDR_MIE:           old_data = MIE & `MIP_READ_MASK;
  `ADDR_MTVEC:         old_data = MTVEC;
  `ADDR_MCOUNTEREN:    old_data = MCOUNTEREN;
  `ADDR_MSTATUSH:      old_data = MSTATUSH;
  `ADDR_MCOUNTINHIBIT: old_data = MCOUNTINHIBIT;
  `ADDR_MSCRATCH:      old_data = MSCRATCH;
  `ADDR_MEPC:          old_data = MEPC;
  `ADDR_MCAUSE:        old_data = MCAUSE;
  `ADDR_MTVAL:         old_data = MTVAL;
  `ADDR_MIP:           old_data = MIP;
  `ADDR_CYCLE:         old_data = CYCLE[31:0];
  `ADDR_TIME:          old_data = TIME[31:0];
  `ADDR_INSTRET:       old_data = INSTRET[31:0];
  `ADDR_CYCLEH:        old_data = CYCLE[63:32];
  `ADDR_TIMEH:         old_data = TIME[63:32];
  `ADDR_INSTRETH:      old_data = INSTRET[63:32];
  `ADDR_MVENDORID:     old_data = 32'h0000_0000;	// NULL value
  `ADDR_MARCHID:       old_data = 32'h0000_0000;	// Not implemented
  `ADDR_MIMPID:        old_data = 32'h0000_0000;	// Not implemented
  `ADDR_MHARTID:       old_data = 32'h0000_0000;	// Only one thread
  `ADDR_MCONFIGPTR:    old_data = 32'h0000_0000;	// NULL value
  default:             old_data = 32'h0000_0000;
endcase

always @ (*)                                                      /* RMW unit */
case (csr_fn_i[1:0])
  2'b01:   new_data = data_in;
  2'b10:   new_data = old_data |  data_in;
  2'b11:   new_data = old_data & ~data_in;
  default: new_data = 32'hxxxx_xxxx;
endcase

always @ (posedge clk)                      /* Simple configuration registers */
if (reset)
  begin
  TSR  <= 1'b0;                                                /* Status bits */
  TW   <= 1'b0;
  TVM  <= 1'b0;
  MXR  <= 1'b0;
  SUM  <= 1'b0;
  MPRV <= 1'b0;
  SPP  <= 1'b0;
  MPIE <= 1'b0;
  UBE  <= 1'b0;
  SPIE <= 1'b0;
  UPIE <= 1'b0;
  MIEf <= 1'b0;
  SIEf <= 1'b0;
  UIEf <= 1'b0;
  XS   <= 2'b00;
  FS   <= 2'b00;
  MPP  <= 2'b00;
  VS   <= 2'b00;
  end
else  if (csr_trap_i)                                      /* Exception entry */
  begin
  case (new_mode_o)
    2'b11: begin		// Triple check ... *****
           MPP  <= mode_i;
           MPIE <= MIEf;
           MIEf <= 1'b0;
           end
    2'b01: begin
           SPP  <= mode_i[0];
           SPIE <= SIEf;
           SIEf <= 1'b0;
           end
    2'b00: begin
           UPIE <= UIEf;
           UIEf <= 1'b0;
           end
  endcase
  end
else if (csr_ret_i)                                       /* Exception return */
  case (trap_cause_i)
    `TRAP_MRET: begin
                MPP  <= 2'b00;
                MIEf <= MPIE;
                MPIE <= 1'b1;
                if (MPP < 2'b11) MPRV <= 1'b0;
                end
    `TRAP_SRET: begin
                SPP  <= 1'b0;
                SIEf <= SPIE;
                SPIE <= 1'b1;
                MPRV <= 1'b0;                          /* No need to test (?) */
                end
    `TRAP_URET: begin
                UIEf <= UPIE;
                UPIE <= 1'b1;
                end
  endcase
else if (write_status)
//csr_wr_i && (address_i == `ADDR_MSTATUS))	// ++ MORE *****
  begin                                               /* Status bits */
  UPIE <= new_data[4];	// ****
  UIEf <= new_data[0];	// ****
  if (mode_i != 2'b00)                               /* Privileged write bits */
    begin
    MXR  <= new_data[19];   // Illegal CSR addresses are trapped at decode ****
    SUM  <= new_data[18];
    XS   <= new_data[16:15];
    FS   <= new_data[14:13];
    SPP  <= new_data[8];
    SPIE <= new_data[5];
    SIEf <= new_data[1];
    end
  if (mode_i == 2'b11)                               /* Privileged write bits */
    begin
    TSR  <= new_data[22];
    TW   <= new_data[21];
    TVM  <= new_data[20];
    MPRV <= new_data[17];
    MPP  <= new_data[12:11];
    VS   <= new_data[10:9];
    MPIE <= new_data[7];
    UBE  <= new_data[6];
    MIEf <= new_data[3];
    end
  end

always @ (posedge clk)                      /* Simple configuration registers */
if (reset)
  begin
  USTATUSH      <= 32'h0000_0000;		// Distinctive placeholder
  SSTATUSH      <= 32'h0000_0000;		// Correct??  *****
  SEDELEG       <= 32'h0000_0000;
  SIDELEG       <= 32'h0000_0000;
  SCOUNTEREN    <= 32'h0000_0000;
  MSTATUSH      <= 32'h0000_0000;
  MISA          <= `MISA_DEFAULT;
  MTVEC         <= 32'h0000_0000;                   /* Reset to a legal value */
  MCOUNTEREN    <= 32'h0000_0000;
  MEDELEG       <= 32'h0000_0000;
  MIDELEG       <= 32'h0000_0000;
  MIE           <= 32'h0000_0000;
  MIP           <= 32'h0000_0000;
  MCOUNTINHIBIT <= 32'h0000_0000;
  end
else
  if (csr_wr)
    case (address_i)
      `ADDR_UIE:           UIE            <= new_data;
      `ADDR_UTVEC:         UTVEC          <= new_data & 32'hFFFF_FFFD;
      `ADDR_USCRATCH:      USCRATCH       <= new_data;
      `ADDR_SEDELEG:       SEDELEG        <= new_data;
      `ADDR_SIDELEG:       SIDELEG        <= new_data;
      `ADDR_SIE:           SIE            <= new_data;
      `ADDR_STVEC:         STVEC          <= new_data & 32'hFFFF_FFFD;
      `ADDR_SCOUNTEREN:    SCOUNTEREN     <= new_data;
      `ADDR_SSCRATCH:      SSCRATCH       <= new_data;
      `ADDR_MTVEC:         MTVEC          <= new_data & 32'hFFFF_FFFD;
      `ADDR_MCOUNTEREN:    MCOUNTEREN     <= new_data;
      `ADDR_MISA:          MISA           <= new_data & `MISA_MASK;
      `ADDR_MEDELEG:       MEDELEG        <= new_data & `MEDELEG_MASK;
      `ADDR_MIDELEG:       MIDELEG        <= new_data & `MIDELEG_MASK;
      `ADDR_MIE:           MIE            <= new_data & `MIP_WRITE_MASK;
      `ADDR_MIP:           MIP            <= new_data & `MIP_WRITE_MASK;
			// Is there a side effect clearing input? And how? ***
      `ADDR_MSTATUSH:      MSTATUSH       <= new_data;
      `ADDR_MCOUNTINHIBIT: MCOUNTINHIBIT  <= new_data & 32'h0000_0005;
      `ADDR_MSCRATCH:      MSCRATCH       <= new_data;
    endcase

assign new_cause  = {trap_cause_i[5], 27'h0000000, trap_cause_i[3:0]};

always @ (posedge clk)                         /* Hardware modified registers */
begin
if (reset)
  begin
  CYCLE   <= 0;
//TIME    <= 0;
  INSTRET <= 0;
  MCAUSE  <= 32'h0000_0000;                          /* Indicates reset cause */
  end
else
  begin
  if (!MCOUNTINHIBIT[0]) CYCLE <= CYCLE + 1;
//TIME <= TIME + 1;
  if (!MCOUNTINHIBIT[2])
    INSTRET <= INSTRET + {62'h0000_0000_0000_0000, instr_done};
  end

if (csr_trap_i && (new_mode_o == 2'h0))
  begin
  UEPC   <= data_in;
  UCAUSE <= new_cause;
  case (new_cause)
    `TRAP_LD_ACC,  `TRAP_ST_ACC,
    `TRAP_LD_ALGN, `TRAP_ST_ALGN,
    `TRAP_LD_PAGE, `TRAP_ST_PAGE,
    `TRAP_ILLEGAL:               /* Illegal has a different value from others */
      UTVAL <= tval_i;

    `TRAP_IN_ACC,  `TRAP_IN_ALGN, `TRAP_IN_PAGE, `TRAP_BREAK:
      UTVAL <= data_in;

    default: UTVAL  <= 32'h0000_0000;
  endcase
  end
else
  if (csr_wr_i)
    case (address_i)
      `ADDR_UEPC:   UEPC   <= new_data;
      `ADDR_UCAUSE: UCAUSE <= new_data;
      `ADDR_UTVAL:  UTVAL  <= new_data;
    endcase

if (csr_trap_i && (new_mode_o == 2'h1))
  begin
  SEPC   <= data_in;
  SCAUSE <= new_cause;
  case (new_cause)
    `TRAP_LD_ACC,  `TRAP_ST_ACC,
    `TRAP_LD_ALGN, `TRAP_ST_ALGN,
    `TRAP_LD_PAGE, `TRAP_ST_PAGE,
    `TRAP_ILLEGAL:               /* Illegal has a different value from others */
      STVAL <= tval_i;

    `TRAP_IN_ACC,  `TRAP_IN_ALGN, `TRAP_IN_PAGE, `TRAP_BREAK:
      STVAL <= data_in;

    default: STVAL  <= 32'h0000_0000;
  endcase
  end
else
  if (csr_wr_i)
    case (address_i)
      `ADDR_SEPC:   SEPC   <= new_data;
      `ADDR_SCAUSE: SCAUSE <= new_data;
      `ADDR_STVAL:  STVAL  <= new_data;
    endcase

if (csr_trap_i && (new_mode_o == 2'h3))
  begin
  MEPC   <= data_in;
  MCAUSE <= new_cause;
  case (new_cause)
    `TRAP_LD_ACC,  `TRAP_ST_ACC,
    `TRAP_LD_ALGN, `TRAP_ST_ALGN,
    `TRAP_LD_PAGE, `TRAP_ST_PAGE,
    `TRAP_ILLEGAL:               /* Illegal has a different value from others */
      MTVAL <= tval_i;

    `TRAP_IN_ACC,  `TRAP_IN_ALGN, `TRAP_IN_PAGE, `TRAP_BREAK:
      MTVAL <= data_in;

    default: MTVAL  <= 32'h0000_0000;
  endcase
  end
else
  if (csr_wr_i)
    case (address_i)
      `ADDR_MEPC:   MEPC   <= new_data;
      `ADDR_MCAUSE: MCAUSE <= new_data;		// Vet for legal values? ***
      `ADDR_MTVAL:  MTVAL  <= new_data;
    endcase

end

always @ (posedge clk)			// Qualify with read enable ****
if (csr_rd_i)                                 /* Predicated for power economy */
  case (address_i)
    `ADDR_MIP: data_out <= old_data | interrupts_i;
    default:   data_out <= old_data;
  endcase

always @ (*)                         /* Determine handler mode via delegation */
begin
if (trap_cause_i[5] == 1'b0)                         /* Synchronous exception */
  begin
  new_mode[1] = !MEDELEG[trap_cause_i[4:0]];
  if (new_mode_o[1]) new_mode[0] = 1'b1;
  else               new_mode[0] = !SEDELEG[trap_cause_i[4:0]];
  end
else                                                             /* Interrupt */
  begin
  new_mode[1] = !MIDELEG[trap_cause_i[4:0]];
  if (new_mode_o[1]) new_mode[0] = 1'b1;
  else               new_mode[0] = !SIDELEG[trap_cause_i[4:0]];
  end
                        /* 'new_mode_o' now has to be limited by current mode */
new_mode_o = new_mode | mode_i;          /* This rounds up since no priv = 10 */
end


always @ (*)
begin
if (trap_cause_i[5] == 1'b1)                                     /* Interrupt */
  case (new_mode_o)
    2'b00:   vectord = UTVEC[0];        /* Apparently "vectored" is a keyword */
    2'b01:   vectord = STVEC[0];
    2'b11:   vectord = MTVEC[0];
    default: vectord = 1'b0;
  endcase
else vectord = 1'b0;

if (csr_trap_i)                                             /* Call or return */
  begin
  case (new_mode_o)
    2'b00:   trap_vector_o = UTVEC & 32'hFFFF_FFFC;
    2'b01:   trap_vector_o = STVEC & 32'hFFFF_FFFC;
    2'b11:   trap_vector_o = MTVEC & 32'hFFFF_FFFC;
    default: trap_vector_o = 32'hxxxx_xxxx;
  endcase
  if (vectord == 1'b1)
    trap_vector_o = trap_vector_o + (trap_cause_i[3:0] << 2);
  end
else
  case (epc_sel_i)
    2'b00:   trap_vector_o = UEPC;
    2'b01:   trap_vector_o = SEPC;
    2'b11:   trap_vector_o = MEPC;
    default: trap_vector_o = 32'hxxxx_xxxx;
  endcase
end

assign status_o = mstatus_out;
assign isa_o    = MISA;

endmodule	// csr

/*----------------------------------------------------------------------------*/
