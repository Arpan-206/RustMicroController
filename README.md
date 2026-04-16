# RustMicro — RISC-V Bare-Metal Rust + Assembly

A mixed-language bare-metal project for a RISC-V RV32IM microcontroller.
Machine-mode startup, trap handling, interrupt dispatch, and all hardware
access live in assembly. User-mode application logic lives in Rust.

---

## Architecture overview

```
┌─────────────────────────────────────────────────────┐
│  Machine mode  (0x00000000 – 0x0003FFFF)            │
│  src/os.s                                           │
│                                                     │
│  init         — stack, mtvec, timer, intc, mret     │
│  trap_entry   — unified trap/interrupt entry        │
│  handle_interrupt — timer ISR, counter, LCD update  │
│  trap_return  — ECALL return (MEPC += 4)            │
│  isr_return   — interrupt return (MEPC unchanged)   │
│  syscall stubs — sys_lcd_char, sys_btn_read, …      │
│  LCD driver   — lcd_print_char, lcd_clear, …        │
│  device drivers — btn_read, timer_init, …           │
│                                                     │
│  isr_counter  (.data, 0x5a8)                        │
│  str_count    (.krodata, "Count: ")                 │
│  os_stack_top (.bss)                                │
└────────────────────────┬────────────────────────────┘
                         │  mret (MPP=00)
┌────────────────────────▼────────────────────────────┐
│  User mode  (0x00040000 – 0x0007FFFF)               │
│  src/main.rs  — user_main()  →  loop {}             │
│  src/lcd.rs   — print_str, clear  (via ecall)       │
│  src/io.rs    — btn_read, timer_init, …  (via ecall)│
│  src/syscall.rs — ecall wrappers                    │
│                                                     │
│  user_stack_top (.utext.start, 0x40000)             │
└─────────────────────────────────────────────────────┘
```

The timer ISR runs entirely in machine mode and never calls into Rust.
The Rust foreground loop never touches hardware MMIO directly.

---

## Memory map

| Region | Address range | Contents |
|---|---|---|
| `MMODE` | `0x00000000 – 0x0003FFFF` | OS code, data, BSS, OS stack |
| `UMODE` | `0x00040000 – 0x0007FFFF` | User stack stub, Rust code/rodata |
| LCD MMIO | `0x00010100` | LCD base |
| Button port | `0x00010001` | Raw button byte |
| Timer | `0x00010200` | Timer registers (see below) |
| Interrupt controller | `0x00010400` | INTC registers (see below) |
| Halt port | `0x00010700` | Write any value to halt |

### Timer registers (base `0x10200`)

| Offset | Name | Purpose |
|---|---|---|
| `+0x04` | `TIMER_LIMIT` | Modulus register (write modulus − 1) |
| `+0x0C` | `TIMER_CTRL` | Status — bit 31 = terminal count, bit 30 = overrun |
| `+0x10` | `TIMER_CLR` | Write `0x10` to clear terminal-count sticky bit |
| `+0x14` | `TIMER_SET` | Write `0x03` to enable in modulus mode |

### Interrupt controller registers (base `0x10400`)

| Offset | Name | Purpose |
|---|---|---|
| `+0x04` | `INTC_ENABLE` | Bit mask of enabled interrupt lines |
| `+0x08` | `INTC_IRQ` | Pending interrupts — write 1 to clear a bit |
| `+0x0C` | `INTC_MODE` | Level / edge selection |

Timer is wired to bit 4 (`0x10`) of the interrupt controller.

---

## Boot and interrupt flow

```
power-on → init (M-mode)
    la sp, os_stack_top          # OS stack
    csrw mtvec, trap_entry       # install unified trap handler
    call lcd_clear
    # configure timer: modulus = 999999 (1 Hz at 1 MHz clock)
    sw TIMER_1S → TIMER_LIMIT
    sw (EN|MOD) → TIMER_SET
    # enable interrupt path
    sw bit4 → INTC_ENABLE        # unmask timer line
    csrs mie, MEIE               # machine external interrupt enable
    # drop to user mode
    csrc mstatus, MPP_MASK       # MPP = 00 (user)
    csrw mepc, USER_CODE
    csrs mstatus, MIE            # global interrupt enable
    mret → USER_CODE (U-mode)

USER_CODE → user_main → loop {}  # foreground idles forever

every 1 second:
    timer fires → machine external interrupt
    → trap_entry
        csrrw sp, mscratch, sp   # swap to OS stack
        save ra/t0/a7/MEPC
        csrr mcause
        bltz mcause → handle_interrupt
    → handle_interrupt
        check INTC_IRQ bit4      # confirm timer, not spurious
        save a0–a5, t1–t4        # full ISR frame
        clear TIMER_CLR_TERM     # prevent immediate re-trigger
        clear INTC_IRQ bit4
        isr_counter += 1
        lcd_char('\n')           # cursor to line 2
        print "Count: "
        print isr_counter (decimal)
        restore a0–a5, t1–t4
    → isr_return
        csrw mepc, saved_MEPC   # restore UNCHANGED (resume user insn)
        restore ra/t0/a7
        csrrw sp, mscratch, sp  # swap back to user stack
        mret → user loop {}
```

---

## Source files

| File | Language | Responsibility |
|---|---|---|
| `src/os.s` | RISC-V asm | Everything M-mode: init, trap, ISR, LCD driver, device drivers |
| `src/main.rs` | Rust | User-mode entry — `user_main()` loops forever |
| `src/syscall.rs` | Rust | `ecall` wrappers for each syscall number |
| `src/io.rs` | Rust | Button and timer helpers, constants |
| `src/lcd.rs` | Rust | `print_str`, `clear` via syscalls |
| `build.rs` | Rust | Compiles `os.s` via `riscv64-unknown-elf-gcc` |
| `linker.ld` | Linker script | Places `.ktext.start` at 0x0, `.utext.start` at 0x40000 |
| `elftokmd.py` | Python | Converts ELF to `.kmd` listing for the simulator |
| `build.sh` | Shell | `cargo build --release` then `elftokmd.py` |

### Syscall table

| Number | Name | In | Out |
|---|---|---|---|
| 0 | `SYS_EXIT` | — | halts processor |
| 1 | `SYS_LCD_CHAR` | `a0` = byte | prints one character |
| 2 | `SYS_LCD_CLEAR` | — | clears display |
| 3 | `SYS_BTN_READ` | — | `a0` = button byte |
| 4 | `SYS_TIMER_INIT` | `a0` = modulus−1 | configures and starts timer |
| 5 | `SYS_TIMER_POLL` | — | `a0` = 0/1/2 (not fired/fired/overrun) |
| 6 | `SYS_TIMER_ACK` | — | clears terminal-count flag |

The LCD character syscall interprets three control codes:
`\n` (0x0A) moves to line 2, `\r` (0x0D) moves to line 1,
`\f` (0x0C) clears the display.

---

## Trap handler design

`trap_entry` is the single entry point for all M-mode traps. It saves a
minimal frame (ra, t0, a7, MEPC) onto the OS stack via `mscratch` swap,
then reads `mcause` and branches:

- **Top bit 1 (negative when sign-extended)** → `handle_interrupt`
- **Top bit 0, cause = 8 (ECALL from U-mode)** → syscall dispatch via `sys_table`
- **Anything else** → `trap_error` (writes to halt port, spins)

The two return paths are distinct:

- `trap_return` (ECALL): adds 4 to saved MEPC so `mret` resumes the instruction *after* the `ecall`.
- `isr_return` (interrupt): restores MEPC unchanged so `mret` resumes the exact instruction that was interrupted.

---

## Register preservation in the ISR

`trap_entry` saves ra, t0, a7, MEPC. The ISR additionally saves a0–a5
and t1–t4 before calling the LCD subroutines, which clobber those
registers. s0 is saved/restored by `isr_print_str` internally.
The net effect is that all registers visible to the interrupted user
program are restored to their original values before `mret`.

---

## Build

**Prerequisites**

- Rust with target `riscv32im-unknown-none-elf`
- `riscv64-unknown-elf-gcc` (used by `build.rs` to assemble `os.s`)
- `riscv64-unknown-elf-objdump` (used by `elftokmd.py`)
- Python 3

```bash
# add the Rust target once
rustup target add riscv32im-unknown-none-elf

# build and convert to KMD
bash build.sh
```

Output: `rv32-bare.kmd` — load this into the Bennett simulator.

---

## Lab 6 Part 2 — what changed from the polling stopwatch

| | Polling stopwatch (Lab 5) | Interrupt counter (Lab 6 Part 2) |
|---|---|---|
| Timer use | `SYS_TIMER_POLL` / `SYS_TIMER_ACK` in Rust loop | Hardware timer interrupt, handled in M-mode ISR |
| LCD updates | Driven by Rust foreground | Driven by `handle_interrupt` in assembly |
| Rust foreground | Polls timer and buttons, updates display | `loop {}` — idles, never touches hardware |
| Counter storage | Rust local variables on user stack | `isr_counter` word in M-mode `.data` |
| MEPC on return | +4 (ECALL path) | Unchanged (interrupt path) |
| Interrupt controller | Not configured | INTC bit 4 enabled, pending bit cleared in ISR |
| `mie` / `mstatus.MIE` | Not set | Both set during `init` |
