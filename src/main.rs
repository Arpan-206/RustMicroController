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
    loop {}
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    lcd::print_str(b"ERROR");
    loop {}
}
