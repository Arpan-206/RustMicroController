#![no_std]
#![no_main]

mod io;
mod keyboard;
mod syscall;

use core::panic::PanicInfo;

#[no_mangle]
pub extern "C" fn user_main() {
    io::timer_start(io::TIMER_10MS);

    loop {
        if let Some(ch) = keyboard::read_key_nonblocking() {
            syscall::lcd_char(ch);
        }
    }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
