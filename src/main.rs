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

const LED_BASE: u32 = 0x0001_0000;
const TIMER_MODULUS: u32 = 0x0001_0204;
const TIMER_CTRL: u32 = 0x0001_020C;
const TIMER_CLR: u32 = 0x0001_0210;
const TIMER_SET: u32 = 0x0001_0214;

const CTRL_EN: u32 = 1 << 0;
const CTRL_MOD: u32 = 1 << 1;
const CTRL_CLR_TC: u32 = 1 << 4;
const BTN_START: u8 = 1 << 0;

const ONE_SECOND: u32 = 1_000_000 - 1;

#[inline(always)]
unsafe fn write32(addr: u32, val: u32) {
    core::ptr::write_volatile(addr as *mut u32, val);
}

#[inline(always)]
unsafe fn read8(addr: u32) -> u8 {
    core::ptr::read_volatile(addr as *const u8)
}

#[no_mangle]
pub extern "C" fn rust_main() -> ! {
    unsafe {
        let mut running = false;

        write32(TIMER_CLR, 0xFFFF_FFFF);
        write32(TIMER_MODULUS, ONE_SECOND);
        write32(TIMER_SET, CTRL_MOD);
        write32(LED_BASE, 0x00);

        loop {
            if read8(LED_BASE + 1) & BTN_START != 0 {
                running = !running;
                if running {
                    write32(TIMER_CLR, CTRL_CLR_TC);
                    write32(TIMER_SET, CTRL_EN);
                    write32(LED_BASE, 0x01); // LED on
                } else {
                    write32(TIMER_CLR, CTRL_EN);
                    write32(LED_BASE, 0x00); // LED off
                }
                while read8(LED_BASE + 1) & BTN_START != 0 {}
            }
        }
    }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
