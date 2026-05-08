#![no_std]
#![no_main]

mod display;
mod syscall;

use core::panic::PanicInfo;

#[no_mangle]
pub extern "C" fn user_main() {
    syscall::vdu_init(0);
    syscall::vdu_fill(display::BLACK);
    syscall::vdu_vsync();

    let size: u32 = 10;
    let x0: u32 = 100;
    let y0: u32 = 100;
    for y in 0..size {
        for x in 0..size {
            syscall::vdu_pixel(x0 + x, y0 + y, display::RED);
        }
    }

    syscall::vdu_vsync();

    let x1: u32 = 200;
    let y1: u32 = 200;
    for y in 0..size {
        for x in 0..size {
            syscall::vdu_pixel(x1 + x, y1 + y, display::GREEN);
        }
    }

    loop {
        syscall::vdu_vsync();
    }
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
