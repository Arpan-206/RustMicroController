#![no_std]
#![no_main]

mod animator;
mod display;
mod generated_scene;
mod io;
mod syscall;

use core::panic::PanicInfo;

#[no_mangle]
pub extern "C" fn user_main() {
    animator::run();
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
