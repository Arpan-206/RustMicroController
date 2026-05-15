#![no_std]
#![no_main]

mod display;
mod font;
mod io;
mod keyboard;
mod lcd;
mod pong;
mod syscall;

use core::panic::PanicInfo;

use crate::lcd::print_str;

#[no_mangle]
pub extern "C" fn user_main() {
    print_str(b"Pong game!");
    pong::run();
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
