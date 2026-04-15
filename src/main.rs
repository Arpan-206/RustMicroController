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
const CTRL_TC: u32 = 1 << 31;

const ONE_SECOND: u32 = 1_000_000 - 1;

const BTN_START: u8 = 1 << 0; // SW1 → start
const BTN_PAUSE: u8 = 1 << 1; // SW2 → pause

#[inline(always)]
unsafe fn write32(addr: u32, val: u32) {
    core::ptr::write_volatile(addr as *mut u32, val);
}

#[inline(always)]
unsafe fn read32(addr: u32) -> u32 {
    core::ptr::read_volatile(addr as *const u32)
}

#[inline(always)]
unsafe fn read8(addr: u32) -> u8 {
    core::ptr::read_volatile(addr as *const u8)
}

#[no_mangle]
pub extern "C" fn rust_main() -> ! {
    // Force the elapsed counter into t0 (x5)
    let mut elapsed: u32;
    unsafe { core::arch::asm!("li t0, 0", out("t0") elapsed) };

    let mut running = false;

    unsafe {
        write32(TIMER_CLR, 0xFFFF_FFFF);
        write32(TIMER_MODULUS, ONE_SECOND);
        write32(TIMER_SET, CTRL_MOD);
        write32(LED_BASE, 0x00);

        loop {
            let btns = read8(LED_BASE + 1);

            // SW1 → start (only if not already running)
            if btns & BTN_START != 0 && !running {
                running = true;
                write32(TIMER_CLR, CTRL_CLR_TC);
                write32(TIMER_SET, CTRL_EN);
                write32(LED_BASE, 0x01);
                while read8(LED_BASE + 1) & BTN_START != 0 {}
            }

            // SW2 → pause (only if running)
            if btns & BTN_PAUSE != 0 && running {
                running = false;
                write32(TIMER_CLR, CTRL_EN);
                write32(LED_BASE, 0x00);
                while read8(LED_BASE + 1) & BTN_PAUSE != 0 {}
            }

            // Every 1 second, increment t0
            if running && read32(TIMER_CTRL) & CTRL_TC != 0 {
                write32(TIMER_CLR, CTRL_CLR_TC);
                // increment t0 directly via asm, write back to elapsed
                core::arch::asm!(
                    "addi t0, t0, 1",
                    inout("t0") elapsed => elapsed
                );
            }
        }
    }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
