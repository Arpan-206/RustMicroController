#![no_std]
#![no_main]

mod display;
mod plasma;
mod syscall;

use core::panic::PanicInfo;
use plasma::Plasma;

#[no_mangle]
pub extern "C" fn user_main() {
    // Change the argument to switch plasma variant: 0, 1, or 2.
    let mut plasma = Plasma::new(0);
    let mut line_buf = [0u8; 640];

    syscall::vdu_init(0); // 8bpp mode, clears framebuffer

    loop {
        plasma.render(&mut line_buf);
        plasma.tick();
        syscall::vdu_vsync();
    }
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
