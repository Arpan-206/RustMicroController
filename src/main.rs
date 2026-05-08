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
    display::clear_screen(0x00);
    svg::render(svg_data::SVG_BYTECODE);
    loop {}
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
