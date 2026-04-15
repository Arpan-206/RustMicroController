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

// ── Declare the asm functions using the RISC-V ABI ───────────────────────────
unsafe extern "C" {
    fn clear_home();
    fn print_str(ptr: *const u8, len: usize);
    fn new_line();
    fn home_line();
    fn print_char(c: u8);
}

// ── Safe wrappers ─────────────────────────────────────────────────────────────
fn lcd_clear() {
    unsafe {
        clear_home();
    }
}
fn lcd_newline() {
    unsafe {
        new_line();
    }
}
fn lcd_home() {
    unsafe {
        home_line();
    }
}
fn lcd_char(c: u8) {
    unsafe {
        print_char(c);
    }
}
fn lcd_print(s: &[u8]) {
    unsafe {
        print_str(s.as_ptr(), s.len());
    }
}

// ── Your program ──────────────────────────────────────────────────────────────
#[no_mangle]
pub extern "C" fn rust_main() -> ! {
    lcd_clear();
    lcd_print(b"Arpan\n");
    lcd_print(b"World!\rHello");
    loop {}
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
