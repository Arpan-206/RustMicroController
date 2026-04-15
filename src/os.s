        # ── constants ──────────────────────────────────────────────
        .equ HALT_PORT,     0x00010700
        .equ LCD_BASE,      0x00010100
        .equ MPP_MASK,      0x00001800
        .equ CAUSE_ECALL_U, 8
        .equ OS_STACK_SIZE, 256
        .equ SYS_EXIT,      0
        .equ SYS_LCD_CHAR,  1
        .equ SYS_LCD_CLEAR, 2
        .equ SYS_MAX,       3
        .equ r_input,       0b1001
        .equ r_output,      0b1010
        .equ lcd_e_bit,     0x04
        .equ lcd_e_clear,   0xfb
        .equ lcd_busy_flag, 0x80
        .equ lcd_ctrl_cmd,  0b1000
        .equ lcd_cmd_clear, 0x01
        .equ lcd_cmd_home,  0x02
        .equ lcd_cmd_line1, 0x80
        .equ lcd_cmd_line2, 0xc0
        .equ delay_short,   20
        .equ delay_poll,    48
        .equ ascii_lf,      0x0a
        .equ ascii_cr,      0x0d
        .equ ascii_ff,      0x0c
        .equ MSCRATCH,      0x340
        .equ MTVEC,         0x305
        .equ MSTATUS,       0x300
        .equ MEPC,          0x341
        .equ MCAUSE,        0x342

        .global init
        .global USER_CODE

        # ================================================================
        # M-MODE: boot
        # ================================================================
        .section .text.start

init:
        la      sp, os_stack_top
        csrw    MSCRATCH, sp        # MSCRATCH always holds OS stack top

        la      t0, trap_entry
        csrw    MTVEC, t0

        call    lcd_clear

        li      t0, MPP_MASK
        csrc    MSTATUS, t0         # MPP = 00 → U-mode on mret
        la      t0, USER_CODE
        csrw    MEPC, t0
        mret

        # ================================================================
        # TRAP HANDLER
        #
        # Frame layout (on OS stack, grows down):
        #   sp+ 0 : ra
        #   sp+ 4 : t0
        #   sp+ 8 : a7
        #   sp+12 : MEPC
        #   sp+16 : user sp   ← key addition, avoids MSCRATCH corruption
        #
        # MSCRATCH invariant: always holds OS stack top.
        # Never read MSCRATCH at trap_return — user sp is in the frame.
        # ================================================================
        .section .text

trap_entry:
        csrrw   sp, MSCRATCH, sp    # sp = OS stack top, MSCRATCH = user sp
        addi    sp, sp, -20
        sw      ra,  0(sp)
        sw      t0,  4(sp)
        sw      a7,  8(sp)
        csrr    t0,  MEPC
        sw      t0, 12(sp)
        csrr    t0,  MSCRATCH       # MSCRATCH still holds user sp
        sw      t0, 16(sp)          # save user sp into frame

        # Restore MSCRATCH to OS stack top for nested trap safety
        addi    t0, sp, 20          # t0 = os_stack_top (before frame alloc)
        csrw    MSCRATCH, t0        # MSCRATCH = OS stack top again ✓

        csrr    t0,  MCAUSE
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

trap_error:
        li      t0, HALT_PORT
        li      t1, 0xDEADBEEF
        sw      t1, 0(t0)
        j       trap_error

        # ── trap_return ──────────────────────────────────────────────
        # Restores user sp directly from frame — never touches MSCRATCH.
        # a0 is not restored (syscall return value).
trap_return:
        lw      t0, 12(sp)
        addi    t0,  t0, 4          # advance MEPC past ecall
        csrw    MEPC, t0
        lw      a7,  8(sp)
        lw      t0,  4(sp)
        lw      ra,  0(sp)
        lw      sp, 16(sp)          # restore user sp directly from frame ✓
        mret                        # MSCRATCH still = OS stack top for next trap

        # ================================================================
        # SYSCALL HANDLERS
        # ================================================================

sys_exit:
        li      t0, HALT_PORT
        li      t1, 0
        sw      t1, 0(t0)
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

        # ================================================================
        # LCD DRIVER
        # ================================================================

lcd_print_char:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        li      t0, ascii_lf
        beq     a0, t0, lpc_newline
        li      t0, ascii_cr
        beq     a0, t0, lpc_home
        li      t0, ascii_ff
        beq     a0, t0, lpc_clear
        li      a1, r_output
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
        li      a0, lcd_cmd_line2
        li      a1, lcd_ctrl_cmd
        call    lcd_send
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

lcd_home_line:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        li      a0, lcd_cmd_line1
        li      a1, lcd_ctrl_cmd
        call    lcd_send
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

lcd_clear:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        li      a0, lcd_cmd_clear
        li      a1, lcd_ctrl_cmd
        call    lcd_send
        li      a0, lcd_cmd_home
        li      a1, lcd_ctrl_cmd
        call    lcd_send
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

lcd_send:
        addi    sp, sp, -12
        sw      ra, 0(sp)
        sw      s0, 4(sp)
        sw      s1, 8(sp)
        mv      s0, a0
        mv      s1, a1
        call    lcd_poll
        mv      a0, s0
        mv      a1, s1
        call    lcd_write
        lw      s1, 8(sp)
        lw      s0, 4(sp)
        lw      ra, 0(sp)
        addi    sp, sp, 12
        ret

lcd_poll:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        li      t2, LCD_BASE
lp_wait:
        li      t3, r_input
        ori     t3, t3, lcd_e_bit
        sb      t3, 1(t2)
        li      a0, delay_short
        call    delay
        lb      t3, 0(t2)
        li      t0, r_input
        andi    t0, t0, lcd_e_clear
        sb      t0, 1(t2)
        li      a0, delay_poll
        call    delay
        andi    t3, t3, lcd_busy_flag
        bnez    t3, lp_wait
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

lcd_write:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        li      t2, LCD_BASE
        mv      t3, a1
        ori     t3, t3, lcd_e_bit
        sb      a0, 0(t2)
        sb      t3, 1(t2)
        li      a0, delay_short
        call    delay
        andi    t3, t3, lcd_e_clear
        sb      t3, 1(t2)
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

delay:
        beqz    a0, delay_done
1:
        addi    a0, a0, -1
        bnez    a0, 1b
delay_done:
        ret

        # ── OS stack ─────────────────────────────────────────────────
        .section .bss
        .balign 4
        .space  OS_STACK_SIZE
os_stack_top:

        # ================================================================
        # U-MODE ENTRY (0x00040000)
        # ================================================================
        .section .utext
        .balign 4

USER_CODE:
        lui     sp, %hi(user_stack_top)
        addi    sp, sp, %lo(user_stack_top)
        call    user_main
        li      a7, SYS_EXIT
        ecall
        j       .

        .space  256
user_stack_top:
