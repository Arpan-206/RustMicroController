#![no_std]
#![no_main]

mod io;
mod lcd;
mod shared;
mod syscall;

use core::panic::PanicInfo;
use io::{BTN_PAUSE, BTN_RESET, BTN_START};
use shared::SharedSlot;
use syscall::{shared_get, shared_set};

fn print_decimal(mut n: u32) {
    let mut buf = [0u8; 10];
    let mut len = 0;
    if n == 0 {
        lcd::print_str(b"0");
        return;
    }
    while n > 0 {
        buf[len] = b'0' + (n % 10) as u8;
        n /= 10;
        len += 1;
    }
    buf[..len].reverse();
    lcd::print_str(&buf[..len]);
}

#[no_mangle]
pub extern "C" fn user_main() {
    lcd::clear();
    lcd::print_str(b"Stopwatch");
    lcd::print_str(b"\n");
    print_decimal(0);

    loop {
        let btns = io::btn_read();
        if btns & BTN_START != 0 {
            shared_set(SharedSlot::Running, 1);
        } else if btns & BTN_PAUSE != 0 {
            shared_set(SharedSlot::Running, 0);
        } else if btns & BTN_RESET != 0 && shared_get(SharedSlot::Running) == 0 {
            shared_set(SharedSlot::Counter, 0);
            shared_set(SharedSlot::Dirty, 1);
        }

        if shared_get(SharedSlot::Dirty) != 0 {
            shared_set(SharedSlot::Dirty, 0);
            let count = shared_get(SharedSlot::Counter);
            lcd::print_str(b"\n");
            print_decimal(count);
        }
    }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
