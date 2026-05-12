#![no_std]
#![no_main]

mod display;
mod syscall;

use core::panic::PanicInfo;

use display::{draw_circle, draw_line, draw_rect, draw_rect_outline, Colour};

#[no_mangle]
pub extern "C" fn user_main() {
    syscall::vdu_init(0); // 8bpp mode

    loop {
        syscall::vdu_vsync();
        draw_rect(0, 0, 639, 479, Colour::BLACK);

        // Blue filled rectangle with green outline
        draw_rect(80, 60, 300, 200, Colour::BLUE);
        draw_rect_outline(80, 60, 300, 200, Colour::GREEN);

        // Red-outlined triangle
        draw_line(360, 80, 520, 220, Colour::RED);
        draw_line(520, 220, 260, 220, Colour::RED);
        draw_line(260, 220, 360, 80, Colour::RED);

        // Small circle
        draw_circle(500, 120, 20, Colour::WHITE);
    }
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
