#![no_std]
#![no_main]

mod display;
mod syscall;

use core::panic::PanicInfo;

#[no_mangle]
pub extern "C" fn user_main() {
    let mut ball = display::AnimSprite::new(&display::BALL, 100, 100, 2, 1, display::BLACK);

    syscall::vdu_init(0);
    display::fill(display::BLACK);

    loop {
        ball.update();
        ball.bounce(syscall::vdu_width() as i32, syscall::vdu_height() as i32);
        syscall::vdu_vsync();
    }
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
