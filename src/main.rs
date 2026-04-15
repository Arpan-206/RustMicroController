#![no_std]
#![no_main]

mod lcd;
mod syscall;

use core::panic::PanicInfo;

static HELLO: [u8; 6] = *b"Arpan\n";
static WORLD: [u8; 12] = *b"World!\rHello";

#[no_mangle]
pub extern "C" fn user_main() {
    lcd::print_str(&HELLO);
    lcd::print_str(&WORLD);
    syscall::exit();
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
