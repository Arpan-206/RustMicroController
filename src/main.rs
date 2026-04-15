#![no_std]
#![no_main]

mod syscall;
use syscall::*;

use core::panic::PanicInfo;

#[link_section = ".urodata"]
static HELLO: [u8; 6] = *b"Arpan\n";

#[link_section = ".urodata"]
static WORLD: [u8; 12] = *b"World!\rHello";

#[no_mangle]
#[link_section = ".utext"]
pub extern "C" fn user_main() -> ! {
    lcd_clear();
    print_str(&HELLO);
    print_str(&WORLD);
    exit();
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
