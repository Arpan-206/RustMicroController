        # ── constants ──────────────────────────────────────────────
        .equ HALT_PORT,      0x00010700
        .equ LCD_BASE,       0x00010100
        .equ MPP_MASK,       0x00001800
        .equ CAUSE_ECALL_U,  8
        .equ CAUSE_M_EXT,    0x8000000B
        .equ OS_STACK_SIZE,  256
        .equ SYS_EXIT,        0
        .equ SYS_LCD_CHAR,    1
        .equ SYS_LCD_CLEAR,   2
        .equ SYS_BTN_READ,    3
        .equ SYS_COUNTER_GET, 4
        .equ SYS_COUNTER_CLR, 5
        .equ SYS_TIMER_START, 6
        .equ SYS_MAX,         7
        .equ BTN_PORT,       0x00010001
        # External interrupt controller
        .equ PLIC_BASE,      0x00010400
        .equ PLIC_ENABLES,   0x04
        .equ PLIC_REQUESTS,  0x08
        .equ PLIC_MODE,      0x0C
        .equ BTN_IRQ_BIT,    0x20        # bit 5 = button
        .equ TIMER_IRQ_BIT,  0x10        # bit 4 = timer
        .equ LED_PORT,       0x00010000
        # Timer
        .equ TIMER_BASE,     0x00010200
        .equ TIMER_LIMIT,    0x04
        .equ TIMER_CLR,      0x10
        .equ TIMER_SET,      0x14
        .equ TIMER_EN,       0x01
        .equ TIMER_MOD,      0x02
        .equ TIMER_IE,       0x08
        .equ TIMER_CLR_TERM, 0x10
        .equ TIMER_1S,       999999
        # CSR addresses
        .equ MSCRATCH,       0x340
        .equ MTVEC,          0x305
        .equ MSTATUS,        0x300
        .equ MEPC,           0x341
        .equ MCAUSE,         0x342
        .equ MIE_CSR,        0x304
        .equ MEIE_BIT,       0x800
        .equ MSTATUS_MIE,    0x8
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

        .global init
        .global USER_CODE

        # ================================================================
        # M-MODE
        # ================================================================
        .section .ktext.start, "ax"

init:
        la      sp, os_stack_top
        csrw    MSCRATCH, sp

        la      t0, trap_entry
        csrw    MTVEC, t0

        # Enable timer interrupt in PLIC (button is polled)
        li      t0, PLIC_BASE
        li      t1, TIMER_IRQ_BIT
        sw      t1, PLIC_ENABLES(t0)
        sw      zero, PLIC_MODE(t0)

        li      t0, MEIE_BIT
        csrs    MIE_CSR, t0
        li      t0, MSTATUS_MIE
        csrs    MSTATUS, t0

        call    lcd_clear

        # ── drop to user mode ────────────────────────────────────────
        li      t0, MPP_MASK
        csrc    MSTATUS, t0
        la      t0, USER_CODE
        csrw    MEPC, t0
        mret

        .section .ktext, "ax"

        # ── trap entry — identical to lab5-works ─────────────────────
        # Saves ra, t0, a7, MEPC. Dispatches on MCAUSE.
        # Interrupts branch to isr_dispatch; ECALLs go to sys_table.
trap_entry:
        csrrw   sp, MSCRATCH, sp
        addi    sp, sp, -24
        sw      ra,  0(sp)
        sw      t0,  4(sp)
        sw      t1,  8(sp)
        sw      t2, 12(sp)
        sw      a7, 16(sp)
        csrr    t0,  MEPC
        sw      t0, 20(sp)

        csrr    t0, MCAUSE

        # external interrupt?
        li      t1, CAUSE_M_EXT
        beq     t0, t1, isr_dispatch

        # synchronous — must be ECALL U
        li      t1, CAUSE_ECALL_U
        bne     t0, t1, trap_error

        li      t0, SYS_MAX
        bgeu    a7, t0, trap_error

        la      t0, sys_table
        slli    t1, a7, 2
        add     t0, t0, t1
        lw      t0, 0(t0)
        jr      t0

sys_table:
        .word   sys_exit
        .word   sys_lcd_char
        .word   sys_lcd_clear
        .word   sys_btn_read
        .word   sys_counter_get
        .word   sys_counter_clr
        .word   sys_timer_start

trap_error:
        li      t1, HALT_PORT
        li      t0, 0xDEADBEEF
        sw      t0, 0(t1)
        j       trap_error

        # ECALL return — identical to lab5-works
trap_return:
        lw      t0, 20(sp)
        addi    t0,  t0, 4
        csrw    MEPC, t0
        lw      a7, 16(sp)
        lw      t2, 12(sp)
        lw      t1,  8(sp)
        lw      t0,  4(sp)
        lw      ra,  0(sp)
        addi    sp,  sp, 24
        csrrw   sp,  MSCRATCH, sp
        mret

        # ── interrupt dispatcher ─────────────────────────────────────
isr_dispatch:
        # Read PLIC requests to determine source
        li      t0, PLIC_BASE
        lw      t1, PLIC_REQUESTS(t0)

        # Timer?
        andi    t2, t1, TIMER_IRQ_BIT
        bnez    t2, timer_isr

        j       isr_return


timer_isr:
        # Clear terminal count
        li      t0, TIMER_BASE
        li      t1, TIMER_CLR_TERM
        sw      t1, TIMER_CLR(t0)

        # Reload for next tick
        li      t1, TIMER_1S
        sw      t1, TIMER_LIMIT(t0)
        li      t1, TIMER_EN | TIMER_MOD | TIMER_IE
        sw      t1, TIMER_SET(t0)

        # Increment shared tick counter
        la      t0, tick_count
        lw      t1, 0(t0)
        addi    t1, t1, 1
        sw      t1, 0(t0)

isr_return:
        # Interrupt return — go back to interrupted instruction (no MEPC+4)
        lw      t0, 20(sp)
        csrw    MEPC, t0
        lw      a7, 16(sp)
        lw      t2, 12(sp)
        lw      t1,  8(sp)
        lw      t0,  4(sp)
        lw      ra,  0(sp)
        addi    sp,  sp, 24
        csrrw   sp,  MSCRATCH, sp
        mret

        # ── syscall implementations ──────────────────────────────────

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

        # a0 ← tick_count
sys_counter_get:
        la      t0, tick_count
        lw      a0, 0(t0)
        j       trap_return

        # tick_count ← 0
sys_counter_clr:
        la      t0, tick_count
        sw      zero, 0(t0)
        j       trap_return

        # start 1Hz timer (a0 = modulus)
sys_timer_start:
        li      t0, TIMER_BASE
        sw      a0, TIMER_LIMIT(t0)
        li      t1, TIMER_EN | TIMER_MOD | TIMER_IE
        sw      t1, TIMER_SET(t0)
        j       trap_return

btn_read:
        li      t0, BTN_PORT
        lbu     a0, 0(t0)
        ret

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

        .section .bss, "aw"
        .balign 4
tick_count: .word 0
        .space  OS_STACK_SIZE
os_stack_top:

        # ================================================================
        # U-MODE (0x00040000)
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
