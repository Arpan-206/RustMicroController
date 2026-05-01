#![no_std]
#![no_main]

mod io;
mod keyboard;
mod syscall;

use core::panic::PanicInfo;

#[no_mangle]
pub extern "C" fn user_main() {
    keyboard::wait_for_keypress_and_halt();
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
