.section .text

# ── exports ──────────────────────────────────────────────────
.global lcd_bw
.global print_char
.global new_line
.global home_line
.global clear_home
.global print_str

# ── constants ─────────────────────────────────────────────────
.equ lcd_base,      0x00010100
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

# ── delay(a1) ─────────────────────────────────────────────────
delay:
    mv    t4, a1
1:
    addi  t4, t4, -1
    bnez  t4, 1b
    ret

# ── lcd_bw(a0=data, a1=ctrl) ──────────────────────────────────
lcd_bw:
        addi  sp, sp, -12
        sw    ra, 0(sp)
        sw    s3, 4(sp)     # save s3 (callee-saved)
        sw    s4, 8(sp)     # save s4
        mv    s3, a0        # s3 = data  (safe across calls)
        mv    s4, a1        # s4 = ctrl  (safe across calls — was a3 in original)
        li    s1, lcd_base
busy_wait:
        li    t2, r_input
        li    a1, delay_short
        ori   t2, t2, lcd_e_bit
        sb    t2, 1(s1)
        call  delay         # clobbers a1 — but data/ctrl are in s3/s4 now
        lb    t3, 0(s1)
        andi  t2, t2, lcd_e_clear
        sb    t2, 1(s1)
        li    a1, delay_poll
        call  delay
        andi  t3, t3, lcd_busy_flag
        bnez  t3, busy_wait
        # write phase — use s3/s4 not a0/a1
        mv    t2, s4
        ori   t2, t2, lcd_e_bit
        sb    s3, 0(s1)
        sb    t2, 1(s1)
        li    a1, delay_short
        call  delay
        andi  t2, t2, lcd_e_clear
        sb    t2, 1(s1)
        lw    s4, 8(sp)
        lw    s3, 4(sp)
        lw    ra, 0(sp)
        addi  sp, sp, 12
        ret

# ── print_char(a0=char) ───────────────────────────────────────
print_char:
    addi  sp, sp, -4
    sw    ra, 0(sp)
    li    a1, r_output
    call  lcd_bw
    lw    ra, 0(sp)
    addi  sp, sp, 4
    ret

# ── new_line() ────────────────────────────────────────────────
new_line:
    addi  sp, sp, -4
    sw    ra, 0(sp)
    li    a0, lcd_cmd_line2
    li    a1, lcd_ctrl_cmd
    call  lcd_bw
    lw    ra, 0(sp)
    addi  sp, sp, 4
    ret

# ── home_line() ───────────────────────────────────────────────
home_line:
    addi  sp, sp, -4
    sw    ra, 0(sp)
    li    a0, lcd_cmd_line1
    li    a1, lcd_ctrl_cmd
    call  lcd_bw
    lw    ra, 0(sp)
    addi  sp, sp, 4
    ret

# ── clear_home() ──────────────────────────────────────────────
clear_home:
    addi  sp, sp, -4
    sw    ra, 0(sp)
    li    a0, lcd_cmd_clear
    li    a1, lcd_ctrl_cmd
    call  lcd_bw
    li    a0, lcd_cmd_home
    li    a1, lcd_ctrl_cmd
    call  lcd_bw
    lw    ra, 0(sp)
    addi  sp, sp, 4
    ret

# ── print_str(a0=ptr, a1=len) ─────────────────────────────────
print_str:
    addi  sp, sp, -16
    sw    ra,  0(sp)
    sw    s0,  4(sp)
    sw    s1,  8(sp)
    sw    s2, 12(sp)
    mv    s0, a0
    mv    s1, a1
    li    s2, lcd_base
ps_loop:
    beqz  s1, ps_done
    lbu   a0, 0(s0)
    beqz  a0, ps_done
    li    t5, 0x0a
    beq   a0, t5, ps_newline
    li    t5, 0x0d
    beq   a0, t5, ps_home
    li    t5, 0x0c
    beq   a0, t5, ps_clear
    call  print_char
    j     ps_next
ps_newline:
    call  new_line
    j     ps_next
ps_home:
    call  home_line
    j     ps_next
ps_clear:
    call  clear_home
ps_next:
    addi  s0, s0, 1
    addi  s1, s1, -1
    j     ps_loop
ps_done:
    lw    ra,  0(sp)
    lw    s0,  4(sp)
    lw    s1,  8(sp)
    lw    s2, 12(sp)
    addi  sp, sp, 16
    ret
