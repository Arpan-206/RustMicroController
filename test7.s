;       ----------------------------------------------------------
;       keypad.s - Basic keypad scanner, halts on first keypress
;       ----------------------------------------------------------

        ORG     0

        HALT_PORT   EQU 0x00010700
        PIO_DATA    EQU 0x00010300
        PIO_DIR     EQU 0x00010304
        CLR_COL     EQU 0x0000003f

        COL1        EQU 0xffff013f
        COL2        EQU 0xffff023f
        COL3        EQU 0xffff043f
        COL4        EQU 0xffff083f

        li      t0, PIO_DIR
        li      t1, 0x0000f0ff
        sw      t1, 0[t0]
        li      t0, PIO_DATA        ; keep t0 pointing at data port
        addi    t2, zero, 0xF       ; threshold, set once

scan_loop:
        ; --- Column 1 ---
        li      t1, COL1
        sw      t1, 0[t0]
        nop
        nop
        lw      t3, 0[t0]
        srli    t3, t3, 8
        andi    t3, t3, 0xFF
        blt     t2, t3, key_found
        li      t1, CLR_COL         ; deactivate column
        sw      t1, 0[t0]
        li      t4, 10              ; ~1us settle delay
dly1:   addi    t4, t4, -1
        bnez    t4, dly1

        ; --- Column 2 ---
        li      t1, COL2
        sw      t1, 0[t0]
        nop
        nop
        lw      t3, 0[t0]
        srli    t3, t3, 8
        andi    t3, t3, 0xFF
        blt     t2, t3, key_found
        li      t1, CLR_COL
        sw      t1, 0[t0]
        li      t4, 10
dly2:   addi    t4, t4, -1
        bnez    t4, dly2

        ; --- Column 3 ---
        li      t1, COL3
        sw      t1, 0[t0]
        nop
        nop
        lw      t3, 0[t0]
        srli    t3, t3, 8
        andi    t3, t3, 0xFF
        blt     t2, t3, key_found
        li      t1, CLR_COL
        sw      t1, 0[t0]
        li      t4, 10
dly3:   addi    t4, t4, -1
        bnez    t4, dly3

        ; --- Column 4 ---
        li      t1, COL4
        sw      t1, 0[t0]
        nop
        nop
        lw      t3, 0[t0]
        srli    t3, t3, 8
        andi    t3, t3, 0xFF
        blt     t2, t3, key_found
        li      t1, CLR_COL
        sw      t1, 0[t0]
        li      t4, 10
dly4:   addi    t4, t4, -1
        bnez    t4, dly4

        j       scan_loop

key_found:
        ; t3 = 0xRC e.g. 0x11 = col1 bottom, 0x81 = col1 top
        li      t0, HALT_PORT
        sw      zero, 0[t0]