#![no_std]
#![no_main]

use core::panic::PanicInfo;

// No user_main — the asm USER_CODE does everything directly
#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
