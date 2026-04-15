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

// ── Peripheral addresses ──────────────────────────────────────────────────────
const LCD_BASE: u32 = 0x0001_0100;

// ── LCD control patterns ──────────────────────────────────────────────────────
const R_INPUT: u8 = 0b1001;
const R_OUTPUT: u8 = 0b1010;
const LCD_E_BIT: u8 = 0x04;
const LCD_E_CLR: u8 = 0xfb;
const LCD_BUSY: u8 = 0x80;
const LCD_CTRL: u8 = 0b1000;

// ── LCD commands ──────────────────────────────────────────────────────────────
const CMD_CLEAR: u8 = 0x01;
const CMD_HOME: u8 = 0x02;
const CMD_LINE1: u8 = 0x80;
const CMD_LINE2: u8 = 0xc0;

// ── Delay counts ─────────────────────────────────────────────────────────────
const DELAY_SHORT: u32 = 20;
const DELAY_POLL: u32 = 48;

// ── ASCII control codes ───────────────────────────────────────────────────────
const ASCII_LF: u8 = 0x0a; // \n → new line
const ASCII_CR: u8 = 0x0d; // \r → home (line 1)
const ASCII_FF: u8 = 0x0c; // \f → clear + home

// ── MMIO helpers ──────────────────────────────────────────────────────────────
#[inline(always)]
unsafe fn write8(addr: u32, val: u8) {
    core::ptr::write_volatile(addr as *mut u8, val);
}

#[inline(always)]
unsafe fn read8(addr: u32) -> u8 {
    core::ptr::read_volatile(addr as *const u8)
}

// ── delay(count) ──────────────────────────────────────────────────────────────
#[inline(never)]
fn delay(count: u32) {
    for _ in 0..count {
        core::hint::black_box(());
    }
}

// ── lcd_bw(data, ctrl) ────────────────────────────────────────────────────────
// Polls busy flag then writes data byte with given control pattern.
// Mirrors lcd_bw(a0, a3) from your asm.
unsafe fn lcd_bw(data: u8, ctrl: u8) {
    // busy wait
    loop {
        let mut t2 = R_INPUT | LCD_E_BIT;
        write8(LCD_BASE + 1, t2);
        delay(DELAY_SHORT);

        let t3 = read8(LCD_BASE);
        t2 &= LCD_E_CLR;
        write8(LCD_BASE + 1, t2);
        delay(DELAY_POLL);

        if t3 & LCD_BUSY == 0 {
            break;
        }
    }

    // write
    let mut t2 = ctrl | LCD_E_BIT;
    write8(LCD_BASE, data);
    write8(LCD_BASE + 1, t2);
    delay(DELAY_SHORT);

    t2 &= LCD_E_CLR;
    write8(LCD_BASE + 1, t2);
}

// ── print_char(c) ─────────────────────────────────────────────────────────────
unsafe fn print_char(c: u8) {
    lcd_bw(c, R_OUTPUT);
}

// ── new_line() ────────────────────────────────────────────────────────────────
unsafe fn new_line() {
    lcd_bw(CMD_LINE2, LCD_CTRL);
}

// ── home_line() ───────────────────────────────────────────────────────────────
unsafe fn home_line() {
    lcd_bw(CMD_LINE1, LCD_CTRL);
}

// ── clear_home() ──────────────────────────────────────────────────────────────
unsafe fn clear_home() {
    lcd_bw(CMD_CLEAR, LCD_CTRL);
    lcd_bw(CMD_HOME, LCD_CTRL);
}

// ── print_str(s) ──────────────────────────────────────────────────────────────
// Null-terminated byte slice. Handles \n, \r, \f exactly as your asm does.
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

// ── Strings (null-terminated, matching your DEFB data) ───────────────────────
const HELLO: &[u8] = b"Arpan\n\0";
const WORLD: &[u8] = b"World!\rHello\0";

#[no_mangle]
pub extern "C" fn rust_main() -> ! {
    unsafe {
        clear_home();
        print_str(HELLO);
        print_str(WORLD);
    }

    loop {}
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
