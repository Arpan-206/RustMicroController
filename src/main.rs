#![no_std]
#![no_main]

mod syscall;

use core::panic::PanicInfo;

#[link_section = ".urodata"]
static HELLO: [u8; 6] = *b"Arpan\n";
#[link_section = ".urodata"]
static WORLD: [u8; 12] = *b"World!\rHello";

#[link_section = ".utext"]
#[no_mangle]
pub extern "C" fn user_main() {
    syscall::print_str(&HELLO);
    syscall::print_str(&WORLD);
    syscall::exit();
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
