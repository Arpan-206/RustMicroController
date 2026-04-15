#![no_std]
#![no_main]

use core::arch::global_asm;
use core::panic::PanicInfo;

// Boot stub: set up stack pointer, jump to rust_main
global_asm!(
    ".section .text.start",
    ".global _start",
    "_start:",
    "   la   sp, _stack_top",   // init stack pointer
    "   call rust_main",
    "   j    .",                // halt if main returns
);

#[no_mangle]
pub extern "C" fn rust_main() -> ! {
    // Write to LED port (0x00010000) — turns on LED 0
    let leds = 0x0001_0000 as *mut u32;
    unsafe {
        core::ptr::write_volatile(leds, 0x01);
    }

    loop {}
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
