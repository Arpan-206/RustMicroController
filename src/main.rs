#![no_std]
#![no_main]

mod display;
mod svg;
mod svg_data;
mod syscall;

use core::panic::PanicInfo;

#[no_mangle]
pub extern "C" fn user_main() {
    syscall::vdu_init(0); // 8bpp mode

    let mut frame: usize = 0;
    loop {
        syscall::vdu_vsync();
        syscall::vdu_fill(0x00);
        svg::render_frame(frame);
        frame = (frame + 1) % svg_data::FRAME_COUNT;
    }
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
