#![no_std]
#![no_main]

mod io;
mod syscall;

use core::panic::PanicInfo;

#[no_mangle]
pub extern "C" fn user_main() {
    // 10 ms tick for keypad scanning
    io::timer_start(io::TIMER_10MS);

    loop {
        let key = io::key_read();
        if key == -1 {
            continue;
        }
        syscall::lcd_char(key as u8);
    }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
