#![no_std]
#![no_main]

mod io;
mod keyboard;
mod lcd;
mod syscall;

use core::panic::PanicInfo;

const LCD_WIDTH: usize = 16;

fn render_line1(line: &[u8; LCD_WIDTH]) {
    lcd::print_str(b"\r");
    lcd::print_str(line);
}

fn render_line2(line: &[u8; LCD_WIDTH]) {
    lcd::print_str(b"\n");
    lcd::print_str(line);
}

#[no_mangle]
pub extern "C" fn user_main() {
    io::timer_start(io::TIMER_10MS);

    lcd::clear();

    let mut line = [b' '; LCD_WIDTH];
    let blank = [b' '; LCD_WIDTH];
    let mut len: usize = 0;

    render_line1(&line);
    render_line2(&blank);

    loop {
        if let Some(ch) = keyboard::read_key_nonblocking() {
            if (b'0'..=b'9').contains(&ch) {
                if len < LCD_WIDTH {
                    line[len] = ch;
                    len += 1;
                }
                render_line1(&line);
            }
        }
    }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
