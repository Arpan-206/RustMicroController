# ── constants ──────────────────────────────────────────────
        .equ HALT_PORT,      0x00010700
        .equ LCD_BASE,       0x00010100
        .equ MPP_MASK,       0x00001800
        .equ CAUSE_ECALL_U,  8
        .equ CAUSE_M_EXT,    0x8000000B
        .equ OS_STACK_SIZE,  256
        .equ USER_STACK_SIZE, 1024
        .equ SYS_EXIT,        0
        .equ SYS_LCD_CHAR,    1
        .equ SYS_LCD_CLEAR,   2
        .equ SYS_BTN_READ,    3
        .equ SYS_COUNTER_GET, 4
        .equ SYS_COUNTER_CLR, 5
        .equ SYS_TIMER_START, 6
        .equ SYS_KEY_READ,    7
        .equ SYS_MAX,         8
        .equ BTN_PORT,       0x00010001
        .equ PIO_BASE,       0x00010300
        .equ PIO_DATA,       0x00
        .equ PIO_DIR,        0x04
        .equ PIO_CLR,        0x08
        .equ PIO_SET,        0x0C
        .equ PIO_DIR_VAL,    0xFFFFFFF0
        .equ DEBOUNCE_MAX,   3
        .equ FIFO_SIZE,      16
        .equ KEY_NONE,       0xFF
        .equ PLIC_BASE,      0x00010400
        .equ PLIC_ENABLES,   0x04
        .equ PLIC_REQUESTS,  0x08
        .equ PLIC_MODE,      0x0C
        .equ BTN_IRQ_BIT,    0x20
        .equ TIMER_IRQ_BIT,  0x10
        .equ LED_PORT,       0x00010000
        .equ TIMER_BASE,     0x00010200
        .equ TIMER_LIMIT,    0x04
        .equ TIMER_CLR,      0x10
        .equ TIMER_SET,      0x14
        .equ TIMER_EN,       0x01
        .equ TIMER_MOD,      0x02
        .equ TIMER_IE,       0x08
        .equ TIMER_CLR_TERM, 0x10
        .equ TIMER_1S,       999999
        .equ TIMER_10MS,     9999
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

        la      t0, tick_count
        sw      zero, 0(t0)

        # PIO: rows = outputs (low), cols = inputs
        li      t0, PIO_BASE
        li      t1, PIO_DIR_VAL
        sw      t1, PIO_DIR(t0)
        sw      zero, PIO_DATA(t0)

        # Start 10ms debounce timer immediately
        li      t0, TIMER_BASE
        li      t1, TIMER_10MS
        sw      t1, TIMER_LIMIT(t0)
        li      t1, TIMER_EN | TIMER_MOD | TIMER_IE
        sw      t1, TIMER_SET(t0)

        # Store reload value
        la      t0, timer_reload
        li      t1, TIMER_10MS
        sw      t1, 0(t0)

        # Enable timer IRQ in PLIC
        li      t0, PLIC_BASE
        li      t1, TIMER_IRQ_BIT
        sw      t1, PLIC_ENABLES(t0)
        sw      zero, PLIC_MODE(t0)

        li      t0, MEIE_BIT
        csrs    MIE_CSR, t0
        li      t0, MSTATUS_MIE
        csrs    MSTATUS, t0

        call    lcd_clear

        # drop to user mode
        li      t0, MPP_MASK
        csrc    MSTATUS, t0
        la      t0, USER_CODE
        csrw    MEPC, t0
        mret

        .section .ktext, "ax"

trap_entry:
        csrrw   sp, MSCRATCH, sp
        addi    sp, sp, -24
        sw      ra,  0(sp)
        sw      t0,  4(sp)
        sw      t1,  8(sp)
        sw      t2, 12(sp)
        sw      a7, 16(sp)
        csrr    t0, MEPC
        sw      t0, 20(sp)

        csrr    t0, MCAUSE
        li      t1, CAUSE_M_EXT
        beq     t0, t1, isr_dispatch
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
        .word   sys_key_read

trap_error:
        li      t1, HALT_PORT
        li      t0, 0xDEADBEEF
        sw      t0, 0(t1)
        j       trap_error

trap_return:
        lw      t0, 20(sp)
        addi    t0, t0, 4
        csrw    MEPC, t0
        lw      a7, 16(sp)
        lw      t2, 12(sp)
        lw      t1,  8(sp)
        lw      t0,  4(sp)
        lw      ra,  0(sp)
        addi    sp,  sp, 24
        csrrw   sp,  MSCRATCH, sp
        mret

isr_dispatch:
        li      t0, PLIC_BASE
        lw      t1, PLIC_REQUESTS(t0)
        andi    t2, t1, TIMER_IRQ_BIT
        bnez    t2, timer_isr
        j       isr_return

timer_isr:
        # Clear timer terminal flag
        li      t0, TIMER_BASE
        li      t1, TIMER_CLR_TERM
        sw      t1, TIMER_CLR(t0)

        # Increment tick counter
        la      t0, tick_count
        lw      t1, 0(t0)
        addi    t1, t1, 1
        sw      t1, 0(t0)

        # Run keypad scan directly here — every 10ms tick
        addi    sp, sp, -4
        sw      ra, 0(sp)
        call    key_scan
        lw      ra, 0(sp)
        addi    sp, sp, 4

        j       isr_return

isr_return:
        lw      t0, 20(sp)
        csrw    MEPC, t0            # no +4 for interrupts
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
        sw      zero, 0(t1)
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

sys_counter_get:
        la      t0, tick_count
        lw      a0, 0(t0)
        j       trap_return

sys_counter_clr:
        la      t0, tick_count
        sw      zero, 0(t0)
        j       trap_return

        # a0 = new timer modulus — restarts timer at new rate
        # NOTE: this now also restarts the keypad scan rate.
        # If you need independent timers, split the PLIC IRQ later.
sys_timer_start:
        la      t1, timer_reload
        sw      a0, 0(t1)
        li      t0, TIMER_BASE
        sw      a0, TIMER_LIMIT(t0)
        li      t1, TIMER_EN | TIMER_MOD | TIMER_IE
        sw      t1, TIMER_SET(t0)
        j       trap_return

sys_key_read:
        # Drain one char from FIFO → a0, or -1 if empty
        la      t0, fifo_head
        lw      t1, 0(t0)
        la      t2, fifo_tail
        lw      t3, 0(t2)
        beq     t1, t3, fifo_empty
        la      t2, fifo_buf
        add     t2, t2, t1
        lbu     a0, 0(t2)
        addi    t1, t1, 1
        andi    t1, t1, FIFO_SIZE-1
        sw      t1, 0(t0)
        j       trap_return
fifo_empty:
        li      a0, -1
        j       trap_return

        # ── keypad scanner ───────────────────────────────────────────
        # Drives each row LOW one at a time, reads columns.
        # On DEBOUNCE_MAX consecutive pressed ticks → push to FIFO.
        # On release → decrement counter back toward 0.

key_scan:
        addi    sp, sp, -16
        sw      ra,  0(sp)
        sw      s0,  4(sp)
        sw      s1,  8(sp)
        sw      s2, 12(sp)

        li      s0, 0               # row index

row_loop:
        li      t1, PIO_BASE
        li      t2, 1
        sll     t2, t2, s0          # row bitmask
        sw      t2, PIO_CLR(t1)     # drive row LOW (active)
        nop
        nop
        lw      t3, PIO_DATA(t1)
        srli    t3, t3, 4           # cols into bits 3:0
        xori    t3, t3, 0x0F        # invert: 1 = pressed
        sw      t2, PIO_SET(t1)     # deactivate row

        li      t4, 10              # deactivation settle delay
1:      addi    t4, t4, -1
        bnez    t4, 1b

        li      s1, 0               # col index

col_loop:
        li      t5, 1
        sll     t5, t5, s1
        and     t5, t5, t3          # t5 = this col pressed?

        slli    s2, s0, 2
        add     s2, s2, s1          # key index = row*4 + col

        la      t1, key_debounce
        add     t1, t1, s2
        lbu     t2, 0(t1)           # current debounce counter

        beqz    t5, key_released

key_pressed_path:
        li      t5, DEBOUNCE_MAX
        bge     t2, t5, col_next    # already saturated, skip
        addi    t2, t2, 1
        sb      t2, 0(t1)
        blt     t2, t5, col_next    # not yet confirmed
        # confirmed — push ASCII to FIFO
        la      t5, key_table
        add     t5, t5, s2
        lbu     a0, 0(t5)
        call    fifo_push
        j       col_next

key_released:
        beqz    t2, col_next
        addi    t2, t2, -1
        sb      t2, 0(t1)

col_next:
        addi    s1, s1, 1
        li      t5, 4
        blt     s1, t5, col_loop

        addi    s0, s0, 1
        li      t5, 4
        blt     s0, t5, row_loop

        lw      s2, 12(sp)
        lw      s1,  8(sp)
        lw      s0,  4(sp)
        lw      ra,  0(sp)
        addi    sp,  sp, 16
        ret

fifo_push:
        la      t0, fifo_tail
        lw      t1, 0(t0)
        addi    t2, t1, 1
        andi    t2, t2, FIFO_SIZE-1
        la      t4, fifo_head
        lw      t3, 0(t4)
        beq     t2, t3, fifo_push_done  # full, drop
        la      t4, fifo_buf
        add     t4, t4, t1
        sb      a0, 0(t4)
        sw      t2, 0(t0)
fifo_push_done:
        ret

key_table:
        .byte   '1','2','3','+'
        .byte   '4','5','6','-'
        .byte   '7','8','9','='
        .byte   '*','0','#','/'

        # ── rest of OS unchanged ─────────────────────────────────────

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
1:      addi    t4, t4, -1
        bnez    t4, 1b
        ret

        .section .bss, "aw"
        .balign 4
tick_count:     .word 0
timer_reload:   .word 0
key_debounce:   .space 16
key_state:      .space 16
fifo_buf:       .space FIFO_SIZE
fifo_head:      .word 0
fifo_tail:      .word 0
scan_due:       .word 0             # kept but no longer used
                .space OS_STACK_SIZE
os_stack_top:

        # ================================================================
        # U-MODE
        # ================================================================
        .section .utext.start, "ax"
        .balign 4
        .space  USER_STACK_SIZE
user_stack_top:

        .global USER_CODE
USER_CODE:
        la      sp, user_stack_top
        call    user_main
        li      a7, SYS_EXIT
        ecall
        j       .
