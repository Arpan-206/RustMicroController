#![no_std]
#![no_main]

mod io;
mod keyboard;
mod lcd;
mod syscall;
mod ui;
mod utils;

use core::panic::PanicInfo;

#[no_mangle]
pub extern "C" fn user_main() {
    io::timer_start(io::TIMER_10MS);

    let mut state = ui::UiState::new();
    lcd::clear();
    ui::render_line1(&state);
    ui::render_line2(&state);

    loop {
        if let Some(ch) = keyboard::read_key_nonblocking() {
            ui::handle_key(&mut state, ch);
            ui::render_line1(&state);
            ui::render_line2(&state);
        }
    }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
