# RustMicro — RISC-V Bare-Metal Rust + Assembly

A mixed-language bare-metal project for a RISC-V RV32IM microcontroller.
Machine-mode startup, trap handling, keypad debounce, and hardware access live in assembly.
User-mode application logic lives in Rust.

## GamePlay

| | |
|---|---|
| ![Splash screen](assets/docs/SPLASH.png) | ![Player 2 win screen](assets/docs/P2_WON.png) |


![Gameplay Video](assets/docs/GAMEPLAY.mp4)

If your Markdown renderer does not display the video inline, open [GAMEPLAY.MOV](assets/docs/GAMEPLAY.MOV) directly.

---

## Current user application (Pong game)

- A simple two-player Pong game rendered via the framebuffer draw syscalls.
- Screen resolution: 640×480, 8bpp palette.
- Controls (keypad):
    - Player 1: `1` = paddle up, `4` = paddle down
    - Player 2: `3` = paddle up, `6` = paddle down
    - `1` also starts the game from the splash screen; `0` returns to the splash.
- Game specifics:
    - Paddle size: 12×80, ball radius: 10
    - Default speeds: paddle `PADDLE_SPD = 5`, ball `BALL_SPD_X = 4`, `BALL_SPD_Y = 3`
    - Input repeat uses `INPUT_REPEAT_FRAMES` to apply repeated small moves on a single key press.

The paddles and ball are updated by erasing their previous positions and redrawing their current ones, which can make some text look like it is being erased; that effect was kept intentionally because it looked good in practice. Full-screen redraws only happen when the score changes.

Note: If controls behave unexpectedly, check `src/keyboard.rs` (keycode → ASCII mapping) and the keypad debounce/FIFO in `src/os.s`.

---

## Architecture overview

```
┌─────────────────────────────────────────────────────┐
│  Machine mode  (0x00000000 – 0x0003FFFF)            │
│  src/os.s                                           │
│                                                     │
│  init         — stack, mtvec, PIO, PLIC, mret       │
│  trap_entry   — unified trap/interrupt entry        │
│  isr_dispatch — timer ISR → debounce_update         │
│  trap_return  — ECALL return (MEPC += 4)            │
│  isr_return   — interrupt return (MEPC unchanged)   │
│  syscall stubs — sys_lcd_char, sys_key_read, …      │
│  LCD driver   — lcd_print_char, lcd_clear, …        │
│  keypad scan  — scan_all_keys + debounce + FIFO     │
│                                                     │
│  tick_count   (.bss)                                │
│  os_stack_top (.bss)                                │
└────────────────────────┬────────────────────────────┘
                         │  mret (MPP=00)
┌────────────────────────▼────────────────────────────┐
│  User mode  (0x00040000 – 0x0007FFFF)               │
│  src/main.rs  — entry + game loop (Pong)            │
│  src/pong.rs  — game logic, rendering, input loop   │
│  src/font.rs  — 8×8 glyph set + text rendering      │
│  src/display.rs — high-level draw wrappers (colour) │
│  src/keyboard.rs — keycode → ASCII mapping          │
│  src/lcd.rs   — print_str/clear (via ecall)         │
│  src/io.rs    — timer/key helpers (via ecall)       │
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
| PLIC | `0x00010400` | Interrupt controller registers |
| Halt port | `0x00010700` | Write any value to halt |
| Keypad PIO | `0x00010300` | Keypad GPIO (data/dir) |

### Timer registers (base `0x10200`)

| Offset | Name | Purpose |
|---|---|---|
| `+0x04` | `TIMER_LIMIT` | Modulus register (write modulus − 1) |
| `+0x10` | `TIMER_CLR` | Write `0x10` to clear terminal-count sticky bit |
| `+0x14` | `TIMER_SET` | Write `(EN|MOD|IE)` to enable modulus + interrupt |

### PLIC registers (base `0x10400`)

| Offset | Name | Purpose |
|---|---|---|
| `+0x04` | `PLIC_ENABLES` | Bit mask of enabled interrupt lines |
| `+0x08` | `PLIC_REQUESTS` | Pending interrupt bits |
| `+0x0C` | `PLIC_MODE` | Level / edge selection |

Timer is wired to bit 4 (`0x10`) of the interrupt controller.

---

## Boot and interrupt flow

```
power-on → init (M-mode)
    la sp, os_stack_top          # OS stack
    csrw mtvec, trap_entry       # unified trap handler
    configure keypad PIO
    call lcd_clear
    enable PLIC timer bit + MIE   # interrupts enabled
    drop to user mode
    mret → USER_CODE

USER_CODE → user_main → keypad calculator loop
    io::timer_start(10ms)         # starts timer-driven debounce

on each timer interrupt:
    trap_entry → isr_dispatch
        clear TIMER_CLR
        tick_count += 1
        debounce_update()         # scans keypad, pushes stable key into FIFO
    isr_return → resume user code
```

---

## Keypad debounce (machine mode)

- `scan_all_keys` drives each column and reads row bits to produce a 16-bit bitmap.
- `debounce_update` uses per-key saturating counters (`DEBOUNCE_MAX = 5`).
- When a key becomes stably pressed, its 0xRC keycode is pushed into a FIFO (`FIFO_SIZE = 16`).
- Multi-key scans are ignored to reduce ghosting.
- `SYS_KEY_READ` pops the next keycode or returns `0` if none.

`keyboard.rs` maps keycodes to ASCII using the same 4×4 keypad layout:

```
[1 2 3 +]
[4 5 6 -]
[7 8 9 =]
[* 0 / C]
```

The game expects ASCII digits/characters returned by `keyboard::read_key_nonblocking()`.

---

## Source files

| File | Language | Responsibility |
|---|---|---|
| `src/os.s` | RISC-V asm | M-mode: init, trap, ISR, LCD driver, keypad scan + debounce |
| `src/main.rs` | Rust | User-mode entry + game loop |
| `src/pong.rs` | Rust | Pong game logic and rendering |
| `src/font.rs` | Rust | 8×8 glyphs and text rendering helpers |
| `src/display.rs` | Rust | Display primitives / Colour wrapper |
| `src/keyboard.rs` | Rust | Keycode → ASCII mapping |
| `src/syscall.rs` | Rust | `ecall` wrappers for each syscall number |
| `src/io.rs` | Rust | Timer/key helpers, constants |
| `src/lcd.rs` | Rust | `print_str`, `clear` via syscalls |
| `build.rs` | Rust | Compiles `os.s` via `riscv64-unknown-elf-gcc` |
| `linker.ld` | Linker script | Places `.ktext.start` at 0x0, `.utext.start` at 0x40000 |
| `elftokmd.py` | Python | Converts ELF to `.kmd` listing for the simulator |
| `build.sh` | Shell | `cargo build --release` then `elftokmd.py` |

## Animator (incomplete)

- **Status**: `src/animator.rs` contains a partial implementation and is marked as not completed due to time constraints.
- **Integration**: Animator is not integrated into the running game; `main.rs` runs Pong.
- **Preview/export**: Use `tools/physanim.py` to preview or author `.ron` scenes; `build.rs` consumes `assets/scene.ron` to produce `src/generated_scene.rs` when present.

## Hardware blocks

The `riscv_system/rtl/user` directory contains the FPGA-side user graphics path:

- `User_Peripheral.sv` is the CPU-facing peripheral wrapper. It exposes the draw register file, accepts a `GO` strobe from the processor, and sequences writes into the drawing engine. It also bridges the board peripherals such as LEDs, LCD control lines, switches, and the video timing inputs.
- `drawing_engine.sv` is the rasterizer. It implements the actual shape drawing commands used by the Rust app: rectangles, circles, lines, filled triangles, and filled circles. The module keeps a small command FSM, tracks the active color, and writes pixels into video memory through the display interface.

These blocks are the hardware side of the same drawing API that the Rust code reaches through syscalls.


### Syscall table

| Number | Name | In | Out |
|---|---|---|---|
| 0 | `SYS_EXIT` | — | halts processor |
| 1 | `SYS_LCD_CHAR` | `a0` = byte | prints one character |
| 2 | `SYS_LCD_CLEAR` | — | clears display |
| 3 | `SYS_BTN_READ` | — | `a0` = button byte |
| 4 | `SYS_COUNTER_GET` | — | `a0` = tick counter |
| 5 | `SYS_COUNTER_CLR` | — | resets tick counter |
| 6 | `SYS_TIMER_START` | `a0` = modulus | programs and starts timer |
| 7 | `SYS_KEY_READ` | — | `a0` = next debounced keycode or `0` |

The LCD character syscall interprets three control codes:
`\n` (0x0A) moves to line 2, `\r` (0x0D) moves to line 1,
`\f` (0x0C) clears the display.

---

## Trap handler design

`trap_entry` is the single entry point for all M-mode traps. It saves a
minimal frame (ra, t0–t2, a7, MEPC) onto the OS stack via `mscratch` swap,
then reads `mcause` and branches:

- **Machine external interrupt** → `isr_dispatch`
- **ECALL from U-mode (cause = 8)** → syscall dispatch via `sys_table`
- **Anything else** → `trap_error` (writes to halt port, spins)

The two return paths are distinct:

- `trap_return` (ECALL): adds 4 to saved MEPC so `mret` resumes the instruction *after* `ecall`.
- `isr_return` (interrupt): restores MEPC unchanged so `mret` resumes the interrupted instruction.

---

## Register preservation in the ISR

`trap_entry` saves `ra`, `t0–t2`, `a7`, and `MEPC`. The timer ISR additionally
saves `a0–a5`, `t3–t6`, and `ra` before calling `debounce_update`.
All registers visible to the interrupted user program are restored before `mret`.

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

### Flashing the board

To run on the FPGA board, flash the generated bitstream to the board before loading the software image. After building the hardware in `riscv_system`, use the provided Vivado helper script with the `top.bit` file from the `RISCV_Dual/RISCV_Dual.runs/impl_2` implementation directory:

```bash
bash riscv_system/download_bit_file.sh riscv_system/RISCV_Dual/RISCV_Dual.runs/impl_2/top.bit
```

After the board is flashed, you can build the Rust app and load the resulting `rv32-bare.kmd` into the simulator or run flow you are using.