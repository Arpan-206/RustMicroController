# ── constants ──────────────────────────────────────────────
        .equ HALT_PORT,      0x00010700
        .equ LCD_BASE,       0x00010100
        .equ VDU_BASE,       0x00010600
        .equ VDU_MODE,       0x04
        .equ VDU_STATUS,     0x08
        .equ VDU_WIDTH,      0x10
        .equ VDU_HEIGHT,     0x14
        .equ FRAME_BASE,     0x00100000
        .equ VDU_VBLANK_BIT, 0x04
        .equ MPP_MASK,       0x00001800
        .equ CAUSE_ECALL_U,  8
        .equ CAUSE_M_EXT,    0x8000000B
        .equ OS_STACK_SIZE,  1024
        .equ USER_STACK_SIZE, 2048
        .equ SYS_EXIT,        0
        .equ SYS_LCD_CHAR,    1
        .equ SYS_LCD_CLEAR,   2
        .equ SYS_BTN_READ,    3
        .equ SYS_COUNTER_GET, 4
        .equ SYS_COUNTER_CLR, 5
        .equ SYS_TIMER_START, 6
        .equ SYS_KEY_READ,    7
        .equ SYS_VDU_INIT,    8
        .equ SYS_VDU_PIXEL,   9
        .equ SYS_VDU_FILL,    10
        .equ SYS_VDU_VSYNC,   11
        .equ SYS_VDU_GETW,    12
        .equ SYS_VDU_GETH,    13
        .equ SYS_VDU_HLINE_BUF, 14
        .equ SYS_MAX,         15
        .equ KEY_NONE,       0x00
        .equ DEBOUNCE_MAX,   5
        .equ FIFO_SIZE,      16
        .equ BTN_PORT,       0x00010001
        .equ PIO_BASE,       0x00010300
        .equ PIO_DATA,       0x00
        .equ PIO_DIR,        0x04
        .equ PIO_DIR_VAL,    0x0000f0ff
        .equ CLR_COL,        0x0000003f
        .equ COL_BASE,       0xffff003f
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

        # PIO: configure direction for keypad scan
        li      t0, PIO_BASE
        li      t1, PIO_DIR_VAL
        sw      t1, PIO_DIR(t0)
        li      t1, CLR_COL
        sw      t1, PIO_DATA(t0)

        # Default timer reload value
        la      t0, timer_reload
        li      t1, TIMER_1S
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
        .word   sys_exit           # 0
        .word   sys_lcd_char       # 1
        .word   sys_lcd_clear      # 2
        .word   sys_btn_read       # 3
        .word   sys_counter_get    # 4
        .word   sys_counter_clr    # 5
        .word   sys_timer_start    # 6
        .word   sys_key_read       # 7
        .word   sys_vdu_init       # 8
        .word   sys_vdu_pixel      # 9
        .word   sys_vdu_fill       # 10
        .word   sys_vdu_vsync      # 11
        .word   sys_vdu_getw       # 12
        .word   sys_vdu_geth       # 13
        .word   sys_vdu_hline_buf  # 14

trap_error:
        li      t1, HALT_PORT
        li      t0, 0xDEADBEEF
        sw      t0, 0(t1)
        j       trap_error

trap_return:
        lw      t0, 20(sp)
        addi    t0, t0, 4
        csrw    MEPC, t0
        j       restore_and_mret

isr_dispatch:
        li      t0, PLIC_BASE
        lw      t1, PLIC_REQUESTS(t0)
        andi    t2, t1, TIMER_IRQ_BIT
        bnez    t2, timer_isr
        j       isr_return

timer_isr:
        li      t0, TIMER_BASE
        li      t1, TIMER_CLR_TERM
        sw      t1, TIMER_CLR(t0)

        la      t0, tick_count
        lw      t1, 0(t0)
        addi    t1, t1, 1
        sw      t1, 0(t0)

        addi    sp, sp, -44
        sw      a0, 0(sp)
        sw      a1, 4(sp)
        sw      a2, 8(sp)
        sw      a3, 12(sp)
        sw      a4, 16(sp)
        sw      a5, 20(sp)
        sw      t3, 24(sp)
        sw      t4, 28(sp)
        sw      t5, 32(sp)
        sw      t6, 36(sp)
        sw      ra, 40(sp)
        call    debounce_update
        lw      ra, 40(sp)
        lw      t6, 36(sp)
        lw      t5, 32(sp)
        lw      t4, 28(sp)
        lw      t3, 24(sp)
        lw      a5, 20(sp)
        lw      a4, 16(sp)
        lw      a3, 12(sp)
        lw      a2, 8(sp)
        lw      a1, 4(sp)
        lw      a0, 0(sp)
        addi    sp, sp, 44

        j       isr_return

isr_return:
        lw      t0, 20(sp)
        csrw    MEPC, t0
        j       restore_and_mret

restore_and_mret:
        lw      a7, 16(sp)
        lw      t2, 12(sp)
        lw      t1,  8(sp)
        lw      t0,  4(sp)
        lw      ra,  0(sp)
        addi    sp,  sp, 24
        csrrw   sp,  MSCRATCH, sp
        mret

        # ── syscall implementations ──────────────────────────────────

sys_call_and_return:
        jalr    ra, t0, 0
        j       trap_return

sys_exit:
        li      t1, HALT_PORT
        sw      zero, 0(t1)
        j       sys_exit

sys_lcd_char:
        la      t0, lcd_print_char
        j       sys_call_and_return

sys_lcd_clear:
        la      t0, lcd_clear
        j       sys_call_and_return

sys_btn_read:
        la      t0, btn_read
        j       sys_call_and_return

sys_counter_get:
        la      t0, tick_count
        lw      a0, 0(t0)
        j       trap_return

sys_counter_clr:
        la      t0, tick_count
        sw      zero, 0(t0)
        j       trap_return

sys_timer_start:
        la      t1, timer_reload
        sw      a0, 0(t1)
        li      t0, TIMER_BASE
        sw      a0, TIMER_LIMIT(t0)
        li      t1, TIMER_EN | TIMER_MOD | TIMER_IE
        sw      t1, TIMER_SET(t0)
        j       trap_return

        # SYS_KEY_READ (7) — returns next debounced keycode or 0 if none
sys_key_read:
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
        li      a0, KEY_NONE
        j       trap_return

        #;--- vdu syscalls ---
sys_vdu_init:
        addi    sp, sp, -16
        sw      s0, 0(sp)
        sw      s1, 4(sp)
        sw      s2, 8(sp)
        sw      s3, 12(sp)

        la      s0, vdu_mode
        sw      a0, 0(s0)
        li      s0, VDU_BASE
        sw      a0, VDU_MODE(s0)

        li      a0, 0
        jal     vdu_fill_impl

        lw      s3, 12(sp)
        lw      s2, 8(sp)
        lw      s1, 4(sp)
        lw      s0, 0(sp)
        addi    sp, sp, 16
        j       trap_return

sys_vdu_pixel:
        addi    sp, sp, -16
        sw      s0, 0(sp)
        sw      s1, 4(sp)
        sw      s2, 8(sp)
        sw      s3, 12(sp)

        li      s0, VDU_BASE
        lw      s1, VDU_WIDTH(s0)
        bgeu    a0, s1, vdu_pixel_done
        lw      s2, VDU_HEIGHT(s0)
        bgeu    a1, s2, vdu_pixel_done
        la      s3, vdu_mode
        lw      s3, 0(s3)

        mul     s2, a1, s1
        add     s2, s2, a0
        li      s0, FRAME_BASE
        beqz    s3, vdu_pixel_8bpp
        slli    s2, s2, 1
        add     s0, s0, s2
        sh      a2, 0(s0)
        j       vdu_pixel_done

vdu_pixel_8bpp:
        add     s0, s0, s2
        sb      a2, 0(s0)

vdu_pixel_done:
        lw      s3, 12(sp)
        lw      s2, 8(sp)
        lw      s1, 4(sp)
        lw      s0, 0(sp)
        addi    sp, sp, 16
        j       trap_return

sys_vdu_fill:
        addi    sp, sp, -16
        sw      s0, 0(sp)
        sw      s1, 4(sp)
        sw      s2, 8(sp)
        sw      s3, 12(sp)

        jal     vdu_fill_impl

        lw      s3, 12(sp)
        lw      s2, 8(sp)
        lw      s1, 4(sp)
        lw      s0, 0(sp)
        addi    sp, sp, 16
        j       trap_return

vdu_fill_impl:
        li      s0, VDU_BASE
        lw      s1, VDU_WIDTH(s0)
        lw      s2, VDU_HEIGHT(s0)
        mul     s1, s1, s2

        la      s3, vdu_mode
        lw      s3, 0(s3)

        li      s0, FRAME_BASE
        beqz    s3, vdu_fill_8bpp

vdu_fill_16bpp:
        li      s2, 0xffff
        and     s2, a0, s2
        slli    s3, s2, 16
        or      s2, s2, s3
        srli    s1, s1, 1
vdu_fill_16_loop:
        beqz    s1, vdu_fill_done
        sw      s2, 0(s0)
        addi    s0, s0, 4
        addi    s1, s1, -1
        bnez    s1, vdu_fill_16_loop
        j       vdu_fill_done

vdu_fill_8bpp:
        andi    s2, a0, 0xff
        slli    s3, s2, 8
        or      s2, s2, s3
        slli    s3, s2, 16
        or      s2, s2, s3
        srli    s1, s1, 2
vdu_fill_8_loop:
        beqz    s1, vdu_fill_done
        sw      s2, 0(s0)
        addi    s0, s0, 4
        addi    s1, s1, -1
        bnez    s1, vdu_fill_8_loop

vdu_fill_done:
        ret

sys_vdu_vsync:
        addi    sp, sp, -16
        sw      s0, 0(sp)
        sw      s1, 4(sp)
        sw      s2, 8(sp)
        sw      s3, 12(sp)

        li      s0, VDU_BASE
        li      s1, VDU_VBLANK_BIT

vdu_vsync_wait_low1:
        lw      s2, VDU_STATUS(s0)
        and     s2, s2, s1
        bnez    s2, vdu_vsync_wait_low1

vdu_vsync_wait_high:
        lw      s2, VDU_STATUS(s0)
        and     s2, s2, s1
        beqz    s2, vdu_vsync_wait_high

vdu_vsync_wait_low2:
        lw      s2, VDU_STATUS(s0)
        and     s2, s2, s1
        bnez    s2, vdu_vsync_wait_low2

        lw      s3, 12(sp)
        lw      s2, 8(sp)
        lw      s1, 4(sp)
        lw      s0, 0(sp)
        addi    sp, sp, 16
        j       trap_return

sys_vdu_getw:
        addi    sp, sp, -16
        sw      s0, 0(sp)
        sw      s1, 4(sp)
        sw      s2, 8(sp)
        sw      s3, 12(sp)

        li      s0, VDU_BASE
        lw      a0, VDU_WIDTH(s0)

        lw      s3, 12(sp)
        lw      s2, 8(sp)
        lw      s1, 4(sp)
        lw      s0, 0(sp)
        addi    sp, sp, 16
        j       trap_return

sys_vdu_geth:
        addi    sp, sp, -16
        sw      s0, 0(sp)
        sw      s1, 4(sp)
        sw      s2, 8(sp)
        sw      s3, 12(sp)

        li      s0, VDU_BASE
        lw      a0, VDU_HEIGHT(s0)

        lw      s3, 12(sp)
        lw      s2, 8(sp)
        lw      s1, 4(sp)
        lw      s0, 0(sp)
        addi    sp, sp, 16
        j       trap_return

        # SYS_VDU_HLINE_BUF (14)
        # a0 = y coordinate
        # a1 = pointer to [u8; 640] colour buffer (user address)
        # a2 = length (must be 640)
        # Writes buf[0..len] to framebuffer row y in 8bpp mode.
sys_vdu_hline_buf:
        addi    sp, sp, -20
        sw      s0, 0(sp)
        sw      s1, 4(sp)
        sw      s2, 8(sp)
        sw      s3, 12(sp)
        sw      s4, 16(sp)

        # compute dst = FRAME_BASE + y*640
        li      s0, 640
        mul     s1, a0, s0
        li      s0, FRAME_BASE
        add     s0, s0, s1      # s0 = dst pointer
        mv      s1, a1          # s1 = src pointer
        mv      s2, a2          # s2 = remaining count

hline_buf_loop:
        beqz    s2, hline_buf_done
        lbu     s3, 0(s1)
        sb      s3, 0(s0)
        addi    s0, s0, 1
        addi    s1, s1, 1
        addi    s2, s2, -1
        j       hline_buf_loop

hline_buf_done:
        lw      s4, 16(sp)
        lw      s3, 12(sp)
        lw      s2, 8(sp)
        lw      s1, 4(sp)
        lw      s0, 0(sp)
        addi    sp, sp, 20
        j       trap_return

        # ── keypad raw scan ──────────────────────────────────────────
        # Drives each col high, reads row nibble back.
        # Returns a0 = 0xRC byte, or 0 if nothing pressed.

key_scan_raw:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        li      t0, PIO_BASE
        li      t1, 0xF
        li      t2, 0               # col index
        li      t5, COL_BASE

ksr_col_loop:
        li      t3, 0x0100
        sll     t3, t3, t2          # select column bit (bit 8-11)
        or      t4, t5, t3          # COL_BASE | col bit
        sw      t4, PIO_DATA(t0)
        nop
        nop
        lw      a0, PIO_DATA(t0)
        srli    a0, a0, 8
        andi    a0, a0, 0xFF
        blt     t1, a0, ksr_done
        li      t4, CLR_COL
        sw      t4, PIO_DATA(t0)
        li      a1, 10
        call    delay

        addi    t2, t2, 1
        li      t3, 4
        blt     t2, t3, ksr_col_loop

        li      a0, KEY_NONE
ksr_done:
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

        # ── keypad full scan (internal) ─────────────────────────────
        # Returns a0 = 16-bit bitmap (bit row*4+col set if pressed).

scan_all_keys:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        li      t0, PIO_BASE
        li      t1, 0               # bitmap
        li      t2, 0               # col index
        li      t6, COL_BASE

sak_col_loop:
        li      t3, 0x0100
        sll     t3, t3, t2          # select column bit (bit 8-11)
        or      t4, t6, t3
        sw      t4, PIO_DATA(t0)
        nop
        nop
        lw      t5, PIO_DATA(t0)
        srli    t5, t5, 8
        andi    t5, t5, 0xF0        # row bits in upper nibble
        li      a0, 0x10
        li      a1, 0

sak_row_loop:
        and     a2, t5, a0
        beqz    a2, sak_row_next
        slli    a2, a1, 2
        add     a2, a2, t2
        li      a3, 1
        sll     a3, a3, a2
        or      t1, t1, a3

sak_row_next:
        slli    a0, a0, 1
        addi    a1, a1, 1
        li      a2, 4
        blt     a1, a2, sak_row_loop

        li      t4, CLR_COL
        sw      t4, PIO_DATA(t0)
        li      a1, 10
        call    delay

        addi    t2, t2, 1
        li      t3, 4
        blt     t2, t3, sak_col_loop

        mv      a0, t1
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

        # ── debounce update (internal) ─────────────────────────────
        # Updates per-key saturating counters and stable state.

debounce_update:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        call    scan_all_keys
        mv      t0, a0              # bitmap
        # If more than one key is pressed, ignore this scan to avoid ghosting.
        beqz    t0, du_start
        addi    t4, t0, -1
        and     t4, t4, t0
        beqz    t4, du_start
        li      t0, 0


du_start:
        li      t1, 0               # key index
        la      t2, debounce_cnt
        la      t3, stable_state

        # loop over 16 keys

du_loop:
        li      t4, 1
        sll     t4, t4, t1
        and     t5, t0, t4          # pressed?
        add     t6, t2, t1
        lbu     a0, 0(t6)           # count
        add     a1, t3, t1
        lbu     a2, 0(a1)           # stable state

        beqz    t5, du_not_pressed
        li      t4, DEBOUNCE_MAX
        bge     a0, t4, du_pressed_done
        addi    a0, a0, 1
        sb      a0, 0(t6)
        li      t4, DEBOUNCE_MAX
        bne     a0, t4, du_pressed_done
        lbu     a2, 0(a1)
        bnez    a2, du_pressed_done
        li      a2, 1
        sb      a2, 0(a1)

        # compute keycode 0xRC from index t1
        srli    a2, t1, 2
        andi    a3, t1, 3
        li      t4, 1
        sll     a2, t4, a2          # row nibble (1,2,4,8)
        sll     a3, t4, a3          # col nibble (1,2,4,8)
        slli    a2, a2, 4
        or      a2, a2, a3
        mv      a0, a2
        call    fifo_push
        j       du_next

du_pressed_done:
        j       du_next

du_not_pressed:
        beqz    a0, du_clear_stable
        addi    a0, a0, -1
        sb      a0, 0(t6)
        bnez    a0, du_next

du_clear_stable:
        sb      zero, 0(a1)


du_next:
        addi    t1, t1, 1
        li      t4, 16
        blt     t1, t4, du_loop

        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

fifo_push:
        la      t0, fifo_tail
        lw      t1, 0(t0)
        addi    t2, t1, 1
        andi    t2, t2, FIFO_SIZE-1
        la      t3, fifo_head
        lw      t4, 0(t3)
        beq     t2, t4, fp_done
        la      t3, fifo_buf
        add     t3, t3, t1
        sb      a0, 0(t3)
        sw      t2, 0(t0)
fp_done:
        ret

        # ── rest of OS ───────────────────────────────────────────────

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

lcd_send_cmd:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        li      a2, LCD_BASE
        li      a3, lcd_ctrl_cmd
        call    lcd_send
        lw      ra, 0(sp)
        addi    sp, sp, 4
        ret

lcd_new_line:
        li      a0, lcd_cmd_line2
        j       lcd_send_cmd

lcd_home_line:
        li      a0, lcd_cmd_line1
        j       lcd_send_cmd

lcd_clear:
        addi    sp, sp, -4
        sw      ra, 0(sp)
        li      a0, lcd_cmd_clear
        call    lcd_send_cmd
        li      a0, lcd_cmd_home
        call    lcd_send_cmd
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
vdu_mode:       .word 0
debounce_cnt:   .space 16
stable_state:   .space 16
fifo_buf:       .space FIFO_SIZE
fifo_head:      .word 0
fifo_tail:      .word 0
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
