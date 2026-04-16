        # ── constants ──────────────────────────────────────────────
        .equ HALT_PORT,      0x00010700
        .equ LCD_BASE,       0x00010100
        .equ MPP_MASK,       0x00001800
        .equ CAUSE_ECALL_U,  8
        .equ OS_STACK_SIZE,  256
        .equ SYS_EXIT,       0
        .equ SYS_LCD_CHAR,   1
        .equ SYS_LCD_CLEAR,  2
        .equ SYS_BTN_READ,   3
        .equ SYS_TIMER_INIT, 4
        .equ SYS_TIMER_POLL, 5
        .equ SYS_TIMER_ACK,  6
        .equ SYS_SHARED_GET, 7  # a0=index -> a0=shared_data[index]
        .equ SYS_SHARED_SET, 8  # a0=index, a1=value
        .equ SYS_MAX,        9

        # ── shared data indices ─────────────────────────────────────
        .equ SHARED_COUNTER, 0  # incremented by timer ISR each second
        .equ SHARED_DIRTY,   1  # set to 1 by ISR when counter updated
        .equ SHARED_RUNNING, 2  # 1 = running, 0 = paused; written by user
        .equ SHARED_SIZE,    3  # number of shared words
        .equ BTN_PORT,       0x00010001
        .equ TIMER_BASE,     0x00010200
        .equ TIMER_LIMIT,    0x04
        .equ TIMER_CTRL,     0x0C
        .equ TIMER_CLR,      0x10
        .equ TIMER_SET,      0x14
        .equ TIMER_EN,       0x01
        .equ TIMER_MOD,      0x02
        .equ TIMER_CLR_TERM, 0x10

        # ── interrupt controller ────────────────────────────────────
        .equ INTC_BASE,      0x00010400
        .equ INTC_ENABLE,    0x04        # interrupt enable register
        .equ INTC_IRQ,       0x08        # interrupt request/pending register
        .equ INTC_MODE,      0x0C        # mode register (level/edge)
        .equ TIMER_IRQ_BIT,  0x10        # bit 4 = timer interrupt line

        # ── RISC-V CSR numbers ──────────────────────────────────────
        .equ MSCRATCH,       0x340
        .equ MTVEC,          0x305
        .equ MSTATUS,        0x300
        .equ MEPC,           0x341
        .equ MCAUSE,         0x342
        .equ MIE,            0x304
        .equ MIP,            0x344

        # MIE bit 11 = MEIE (machine external interrupt enable)
        .equ MEIE_BIT,       0x800
        # MSTATUS bit 3 = MIE (global machine interrupt enable)
        .equ MSTATUS_MIE,    0x8

        # ── timer modulus ───────────────────────────────────────────
        .equ TIMER_1S,       999999      # 1 Hz at 1 MHz clock

        # ── LCD hardware ────────────────────────────────────────────
        .equ r_input,        0b1001
        .equ r_output,       0b1010
        .equ lcd_e_bit,      0x04
        .equ lcd_e_clear,    0xfb
        .equ lcd_busy_flag,  0x80
        .equ lcd_ctrl_cmd,   0b1000
        .equ lcd_cmd_clear,  0x01
        .equ lcd_cmd_home,   0x02
        .equ lcd_cmd_line1,  0x80
        .equ lcd_cmd_line2,  0xc0
        .equ delay_short,    20
        .equ delay_poll,     48
        .equ ascii_lf,       0x0a
        .equ ascii_cr,       0x0d
        .equ ascii_ff,       0x0c
        .equ ascii_zero,     48          # ASCII '0'

        .global init
        .global USER_CODE

        # ================================================================
        # M-MODE  (0x00000000)
        # ================================================================
        .section .ktext.start, "ax"

        # ----------------------------------------------------------------
        # init
        # Sets up OS stack, installs trap vector, configures timer for
        # 1-second interrupts, enables interrupt path, clears LCD,
        # drops into user mode via mret.
        # ----------------------------------------------------------------
init:
        la      sp, os_stack_top
        csrw    MSCRATCH, sp

        la      t0, trap_entry
        csrw    MTVEC, t0

        call    lcd_clear

        # ── configure timer ────────────────────────────────────────────
        li      t0, TIMER_BASE
        li      t1, TIMER_1S
        sw      t1, TIMER_LIMIT(t0)
        li      t1, (TIMER_EN | TIMER_MOD)
        sw      t1, TIMER_SET(t0)

        # ── enable timer interrupt in interrupt controller ──────────────
        li      t0, INTC_BASE
        li      t1, TIMER_IRQ_BIT
        sw      t1, INTC_ENABLE(t0)     # unmask timer line

        # ── enable machine external interrupts (MEIE in mie) ───────────
        li      t0, MEIE_BIT
        csrs    MIE, t0

        # ── drop to user mode ──────────────────────────────────────────
        li      t0, MPP_MASK
        csrc    MSTATUS, t0             # MPP = 00 (user)

        la      t0, USER_CODE
        csrw    MEPC, t0

        # enable global interrupts in mstatus AFTER setting MEPC so the
        # timer cannot fire between csrw MEPC and mret
        li      t0, MSTATUS_MIE
        csrs    MSTATUS, t0

        mret

        # ================================================================
        # Trap / interrupt entry
        # ================================================================
        .section .ktext, "ax"

        # ----------------------------------------------------------------
        # trap_entry
        # Single entry for both synchronous traps and async interrupts.
        # Saves minimal context, dispatches on mcause top bit.
        # ----------------------------------------------------------------
trap_entry:
        csrrw   sp, MSCRATCH, sp
        addi    sp, sp, -16
        sw      ra,  0(sp)
        sw      t0,  4(sp)
        sw      a7,  8(sp)
        csrr    t0,  MEPC
        sw      t0, 12(sp)

        csrr    t0,  MCAUSE
        # top bit set  → asynchronous interrupt
        bltz    t0,  handle_interrupt

        # ── synchronous exception / ECALL path ─────────────────────────
        li      t1,  CAUSE_ECALL_U
        bne     t0,  t1, trap_error

        li      t0,  SYS_MAX
        bgeu    a7,  t0, trap_error

        la      t0,  sys_table
        slli    t1,  a7, 2
        add     t0,  t0, t1
        lw      t0,  0(t0)
        jr      t0

sys_table:
        .word   sys_exit
        .word   sys_lcd_char
        .word   sys_lcd_clear
        .word   sys_btn_read
        .word   sys_timer_init
        .word   sys_timer_poll
        .word   sys_timer_ack
        .word   sys_shared_get
        .word   sys_shared_set

trap_error:
        li      t1, HALT_PORT
        li      t0, 0xDEADBEEF
        sw      t0, 0(t1)
        j       trap_error

        # ── ECALL return: advance MEPC past ecall ───────────────────────
trap_return:
        lw      t0, 12(sp)
        addi    t0,  t0, 4              # skip the ecall instruction
        csrw    MEPC, t0
        lw      a7,  8(sp)
        lw      t0,  4(sp)
        lw      ra,  0(sp)
        addi    sp,  sp, 16
        csrrw   sp,  MSCRATCH, sp
        mret

        # ================================================================
        # Interrupt handler
        # ================================================================

        # ----------------------------------------------------------------
        # handle_interrupt
        # Arrived here from trap_entry with minimal frame on OS stack.
        # We only handle the timer (external interrupt from intc).
        # Must NOT advance MEPC — resume the interrupted instruction.
        # ----------------------------------------------------------------
handle_interrupt:
        # Check intc pending register to confirm it is the timer
        li      t0, INTC_BASE
        lw      t1, INTC_IRQ(t0)
        andi    t1, t1, TIMER_IRQ_BIT
        beqz    t1, isr_return          # spurious — just return

        # ── timer ISR ──────────────────────────────────────────────────
        # Keep this minimal: ack the interrupt, update shared_data,
        # return. The foreground Rust loop does all display work.

        # ── clear interrupt sources ─────────────────────────────────────
        li      t0, TIMER_BASE
        li      t1, TIMER_CLR_TERM
        sw      t1, TIMER_CLR(t0)
        li      t0, INTC_BASE
        li      t1, TIMER_IRQ_BIT
        sw      t1, INTC_IRQ(t0)

        # ── increment counter only if running ──────────────────────────
        la      t0, shared_data
        lw      t1, 8(t0)               # shared_data[SHARED_RUNNING]
        beqz    t1, isr_return
        lw      t1, 0(t0)               # shared_data[SHARED_COUNTER]
        addi    t1, t1, 1
        sw      t1, 0(t0)
        li      t1, 1
        sw      t1, 4(t0)               # shared_data[SHARED_DIRTY] = 1

        # ── interrupt return: do NOT advance MEPC ──────────────────────
isr_return:
        lw      t0, 12(sp)              # restore saved MEPC unchanged
        csrw    MEPC, t0
        lw      a7,  8(sp)
        lw      t0,  4(sp)
        lw      ra,  0(sp)
        addi    sp,  sp, 16
        csrrw   sp,  MSCRATCH, sp
        mret

        # ================================================================
        # Syscall stubs
        # ================================================================
sys_exit:
        li      t1, HALT_PORT
        li      t0, 0
        sw      t0, 0(t1)
        j       sys_exit

sys_lcd_char:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        call    lcd_print_char
        lw      ra, 0(sp)
        addi    sp, sp, 4
        j       trap_return

sys_lcd_clear:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        call    lcd_clear
        lw      ra, 0(sp)
        addi    sp, sp, 4
        j       trap_return

sys_btn_read:
        call    btn_read
        j       trap_return

sys_timer_init:
        call    timer_init
        j       trap_return

sys_timer_poll:
        call    timer_poll
        j       trap_return

sys_timer_ack:
        call    timer_ack
        j       trap_return

        # SYS_SHARED_GET: a0 = index -> a0 = shared_data[index]
        # Bounds-checked: out-of-range index returns 0.
sys_shared_get:
        li      t0, SHARED_SIZE
        bgeu    a0, t0, ssg_oob
        la      t0, shared_data
        slli    a0, a0, 2           # index * 4
        add     t0, t0, a0
        lw      a0, 0(t0)
        j       trap_return
ssg_oob:
        li      a0, 0
        j       trap_return

        # SYS_SHARED_SET: a0 = index, a1 = value
        # Bounds-checked: out-of-range index is ignored.
sys_shared_set:
        li      t0, SHARED_SIZE
        bgeu    a0, t0, sss_oob
        la      t0, shared_data
        slli    a0, a0, 2           # index * 4
        add     t0, t0, a0
        sw      a1, 0(t0)
sss_oob:
        j       trap_return

        # ================================================================
        # Device drivers (called from syscall stubs and ISR helpers)
        # ================================================================
btn_read:
        li      t0, BTN_PORT
        lbu     a0, 0(t0)
        ret

timer_init:
        li      t0, TIMER_BASE
        sw      a0, TIMER_LIMIT(t0)
        li      t1, (TIMER_EN | TIMER_MOD)
        sw      t1, TIMER_SET(t0)
        ret

timer_poll:
        li      t0, TIMER_BASE
        lw      t1, TIMER_CTRL(t0)
        li      a0, 0
        bltz    t1, tp_fired
        ret
tp_fired:
        li      a0, 1
        slli    t1, t1, 1
        bltz    t1, tp_overrun
        ret
tp_overrun:
        li      a0, 2
        ret

timer_ack:
        li      t0, TIMER_BASE
        li      t1, TIMER_CLR_TERM
        sw      t1, TIMER_CLR(t0)
        ret

        # ================================================================
        # LCD driver
        # ================================================================
lcd_print_char:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        li      t5, ascii_lf
        beq     a0, t5, lpc_newline
        li      t5, ascii_cr
        beq     a0, t5, lpc_home
        li      t5, ascii_ff
        beq     a0, t5, lpc_clear
        li      a2, LCD_BASE
        li      a3, r_output
        call    lcd_send
        j       lpc_done
lpc_newline:
        call    lcd_new_line
        j       lpc_done
lpc_home:
        call    lcd_home_line
        j       lpc_done
lpc_clear:
        call    lcd_clear
lpc_done:
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

lcd_new_line:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        li      a2, LCD_BASE
        li      a0, lcd_cmd_line2
        li      a3, lcd_ctrl_cmd
        call    lcd_send
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

lcd_home_line:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        li      a2, LCD_BASE
        li      a0, lcd_cmd_line1
        li      a3, lcd_ctrl_cmd
        call    lcd_send
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

lcd_clear:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        li      a2, LCD_BASE
        li      a3, lcd_ctrl_cmd
        li      a0, lcd_cmd_clear
        call    lcd_send
        li      a0, lcd_cmd_home
        call    lcd_send
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

lcd_send:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        call    lcd_poll
        call    lcd_write
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

lcd_poll:
        addi    sp, sp, -4
        sw      ra, 0(sp)
lp_wait:
        li      t2, r_input
        li      a1, delay_short
        ori     t2, t2, lcd_e_bit
        sb      t2, 1(a2)
        call    delay
        lb      t3, 0(a2)
        andi    t2, t2, lcd_e_clear
        sb      t2, 1(a2)
        li      a1, delay_poll
        call    delay
        andi    t3, t3, lcd_busy_flag
        bnez    t3, lp_wait
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

lcd_write:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        mv      t2, a3
        ori     t2, t2, lcd_e_bit
        sb      a0, 0(a2)
        sb      t2, 1(a2)
        li      a1, delay_short
        call    delay
        andi    t2, t2, lcd_e_clear
        sb      t2, 1(a2)
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

delay:
        mv      t4, a1
1:
        addi    t4, t4, -1
        bnez    t4, 1b
        ret

        # ================================================================
        # OS data
        # ================================================================
        .section .bss, "aw"
        .balign 4
        .space  OS_STACK_SIZE
os_stack_top:

        .section .data, "aw"
        .balign 4
shared_data:
        .word   0                   # [0] SHARED_COUNTER
        .word   0                   # [1] SHARED_DIRTY
        .word   0                   # [2] SHARED_RUNNING

        # ================================================================
        # U-MODE entry stub  (0x00040000)
        # ================================================================
        .section .utext.start, "ax"
        .balign 4
        .space  256
user_stack_top:

        .global USER_CODE
USER_CODE:
        la      sp, user_stack_top
        call    user_main
        li      a7, SYS_EXIT
        ecall
        j       .
