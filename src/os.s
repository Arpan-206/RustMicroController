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
        .equ SYS_SHARED_GET, 4
        .equ SYS_SHARED_CLR, 5
        .equ SYS_MAX,        6
        .equ BTN_PORT,       0x00010001
        # External interrupt controller
        .equ PLIC_BASE,      0x00010400
        .equ PLIC_ENABLES,   0x04
        .equ PLIC_REQUESTS,  0x08
        .equ BTN_IRQ_BIT,    0x20        # bit 5 = button
        .equ LED_PORT,       0x00010000
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

        call    lcd_clear

        # ── enable button interrupt in PLIC (bit 5, level-sensitive) ─
        li      t0, PLIC_BASE
        li      t1, BTN_IRQ_BIT
        sw      t1, PLIC_ENABLES(t0)
        sw      zero, 0x0C(t0)          # mode = 0 (level-sensitive)

        # ── enable machine external interrupt + global enable ────────
        li      t0, MEIE_BIT
        csrs    MIE_CSR, t0
        li      t0, MSTATUS_MIE
        csrs    MSTATUS, t0

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
        addi    sp, sp, -16
        sw      ra,  0(sp)
        sw      t0,  4(sp)
        sw      a7,  8(sp)
        csrr    t0,  MEPC
        sw      t0, 12(sp)

        csrr    t0, MCAUSE

        # interrupt: MSB set → negative
        bltz    t0, isr_dispatch

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
        .word   sys_shared_get
        .word   sys_shared_clr

trap_error:
        li      t1, HALT_PORT
        li      t0, 0xDEADBEEF
        sw      t0, 0(t1)
        j       trap_error

        # ECALL return — identical to lab5-works
trap_return:
        lw      t0, 12(sp)
        addi    t0,  t0, 4
        csrw    MEPC, t0
        lw      a7,  8(sp)
        lw      t0,  4(sp)
        lw      ra,  0(sp)
        addi    sp,  sp, 16
        csrrw   sp,  MSCRATCH, sp
        mret

        # ── interrupt dispatcher ─────────────────────────────────────
isr_dispatch:
        andi    t0, t0, 0xF
        li      t1, 11
        bne     t0, t1, isr_return

isr_external:
        # Confirm it's the button via PLIC requests register
        li      t0, PLIC_BASE
        lw      t1, PLIC_REQUESTS(t0)
        andi    t1, t1, BTN_IRQ_BIT
        beqz    t1, isr_return

        # Toggle LED0
        li      t0, LED_PORT
        lbu     t0, 0(t0)
        xori    t0, t0, 0x01
        li      t1, LED_PORT
        sb      t0, 0(t1)

        # Set dirty flag
        la      t0, isr_dirty
        li      t1, 1
        sw      t1, 0(t0)

isr_return:
        # Interrupt return — go back to interrupted instruction (no MEPC+4)
        lw      t0, 12(sp)
        csrw    MEPC, t0
        lw      a7,  8(sp)
        lw      t0,  4(sp)
        lw      ra,  0(sp)
        addi    sp,  sp, 16
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

        # a0 ← isr_dirty
sys_shared_get:
        la      t0, isr_dirty
        lw      a0, 0(t0)
        j       trap_return

        # isr_dirty ← 0
sys_shared_clr:
        la      t0, isr_dirty
        sw      zero, 0(t0)
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
isr_dirty:  .word 0
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
