#![no_std]
#![no_main]

mod io;
mod lcd;
mod syscall;

use core::panic::PanicInfo;
use io::TIMER_1S;

#[no_mangle]
pub extern "C" fn user_main() {
    lcd::clear();
    lcd::print_str(b"Press btn:");

    // Poll button — start timer on first press
    loop {
        if io::btn_read() != 0 {
            io::timer_start(TIMER_1S);
            break;
        }
    }

    loop {}
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    lcd::print_str(b"ERROR");
    loop {}
}
