#![no_std]
#![no_main]

mod io;
mod lcd;
mod syscall;

use core::panic::PanicInfo;

#[no_mangle]
pub extern "C" fn user_main() {
    lcd::clear();
    lcd::print_str(b"Press button");

    loop {
        // Foreground idles; ISR sets dirty flag when button pressed.
        if syscall::shared_get() != 0 {
            syscall::shared_clr();
            lcd::clear();
            lcd::print_str(b"BTN!");
        }
    }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    lcd::print_str(b"ERROR");
    loop {}
}
