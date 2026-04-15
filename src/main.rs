#![no_std]
#![no_main]

use core::arch::global_asm;
use core::panic::PanicInfo;

global_asm!(
    ".section .text.start",
    ".global _start",
    "_start:",
    "   li   sp, 0x4000",
    "   call rust_main",
    "   j    .",
);

// ── Addresses ─────────────────────────────────────────────────────────────────
const LCD_BASE: u32 = 0x0001_0100;
const LCD_DATA: u32 = LCD_BASE + 0x00; // byte 0: data pins 7:0
const LCD_CTRL: u32 = LCD_BASE + 0x01; // byte 1: bits 11:8 → BL|E|RS|RW

// ── Control bit positions (in the CTRL byte, i.e. upper nibble of port) ───────
// Bit 8  = RW  → bit 0 of the ctrl byte when accessed as byte at offset +1
// Bit 9  = RS  → bit 1
// Bit 10 = E   → bit 2
// Bit 11 = BL  → bit 3
const RW: u8 = 1 << 0; // 1 = read from LCD
const RS: u8 = 1 << 1; // 1 = data register, 0 = control register
const E: u8 = 1 << 2; // 1 = enable strobe
const BL: u8 = 1 << 3; // 1 = backlight on  ← THIS was missing!

// ── LCD commands ──────────────────────────────────────────────────────────────
const CMD_CLEAR: u8 = 0x01;
const CMD_HOME: u8 = 0x02;
const CMD_LINE1: u8 = 0x80;
const CMD_LINE2: u8 = 0xc0;

// ── Delay counts (from manual: E pulse = 20 cycles, spacing = 48 cycles) ─────
const DELAY_E_PULSE: u32 = 20;
const DELAY_E_SPACING: u32 = 48;

// ── ASCII control codes ───────────────────────────────────────────────────────
const ASCII_LF: u8 = 0x0a;
const ASCII_CR: u8 = 0x0d;
const ASCII_FF: u8 = 0x0c;

// ── MMIO helpers ──────────────────────────────────────────────────────────────
#[inline(always)]
unsafe fn write8(addr: u32, val: u8) {
    core::ptr::write_volatile(addr as *mut u8, val);
}

#[inline(always)]
unsafe fn read8(addr: u32) -> u8 {
    core::ptr::read_volatile(addr as *const u8)
}

#[inline(never)]
fn delay(count: u32) {
    for _ in 0..count {
        core::hint::black_box(());
    }
}

// ── lcd_bw: busy-wait then write ──────────────────────────────────────────────
// Matches the manual's sequence (p.40, fig 7.2) exactly.
// ctrl_rs: pass RS (data write) or 0 (command write)
unsafe fn lcd_bw(data: u8, ctrl_rs: u8) {
    // ── Busy poll ─────────────────────────────────────────────────────────────
    // Step 1: set RW=1, RS=0 (read control), keep backlight on
    // Step 2: raise E
    // Step 3: delay (E pulse width)
    // Step 4: read data pins (bit 7 = busy flag)
    // Step 5: lower E
    // Step 6: delay (E spacing)
    // Step 7: repeat while busy
    loop {
        write8(LCD_CTRL, BL | RW); // RW=1, RS=0, E=0
        write8(LCD_CTRL, BL | RW | E); // raise E
        delay(DELAY_E_PULSE);
        let status = read8(LCD_DATA); // read busy flag
        write8(LCD_CTRL, BL | RW); // lower E
        delay(DELAY_E_SPACING);
        if status & 0x80 == 0 {
            break;
        } // bit 7 = 0 → idle
    }

    // ── Write ─────────────────────────────────────────────────────────────────
    // Step 1: put data on bus, set RW=0, RS=ctrl_rs, keep backlight on
    // Step 2: raise E
    // Step 3: delay (E pulse width)
    // Step 4: lower E
    write8(LCD_DATA, data);
    write8(LCD_CTRL, BL | ctrl_rs); // RW=0, E=0
    write8(LCD_CTRL, BL | ctrl_rs | E); // raise E
    delay(DELAY_E_PULSE);
    write8(LCD_CTRL, BL | ctrl_rs); // lower E
}

// ── LCD init sequence (HD44780 power-on init) ─────────────────────────────────
unsafe fn lcd_init() {
    // Backlight on immediately, everything else low
    write8(LCD_CTRL, BL);
    delay(50_000); // >15 ms power-on settle

    lcd_bw(0x38, 0); // function set: 8-bit, 2 lines, 5×8
    lcd_bw(0x0C, 0); // display on, cursor off, blink off
    lcd_bw(0x06, 0); // entry mode: cursor increments, no shift
    lcd_bw(CMD_CLEAR, 0);
    lcd_bw(CMD_HOME, 0);
}

// ── Higher-level LCD functions ────────────────────────────────────────────────
unsafe fn print_char(c: u8) {
    lcd_bw(c, RS);
} // RS=1 → data register
unsafe fn new_line() {
    lcd_bw(CMD_LINE2, 0);
}
unsafe fn home_line() {
    lcd_bw(CMD_LINE1, 0);
}
unsafe fn clear_home() {
    lcd_bw(CMD_CLEAR, 0);
    lcd_bw(CMD_HOME, 0);
}

unsafe fn print_str(s: &[u8]) {
    for &c in s {
        match c {
            0 => break,
            ASCII_LF => new_line(),
            ASCII_CR => home_line(),
            ASCII_FF => clear_home(),
            _ => print_char(c),
        }
    }
}

const HELLO: &[u8] = b"Arpan\n\0";
const WORLD: &[u8] = b"World!\rHello\0";

#[no_mangle]
pub extern "C" fn rust_main() -> ! {
    unsafe {
        lcd_init();
        print_str(HELLO);
        print_str(WORLD);
    }
    loop {}
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
