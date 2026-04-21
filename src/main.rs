#![no_std]
#![no_main]

mod io;
mod lcd;
mod syscall;

use core::panic::PanicInfo;

#[no_mangle]
pub extern "C" fn user_main() {
    crate::syscall::timer_start(999999);

    let mut sample: u8 = 0;
    let mut debounced: u8 = 0;
    let mut last_tick: u32 = 0;

    loop {
        let mut tick = crate::syscall::counter_get();
        while tick == last_tick {
            tick = crate::syscall::counter_get();
        }

        last_tick = tick;
        crate::syscall::counter_clr();

        let raw_cols: u8 = crate::syscall::kbd_scan(0);
        let raw: u8 = raw_cols & 1;

        sample = ((sample << 1) | raw) & 0xFF;

        if sample == 0xFF {
            debounced = 1;
        } else if sample == 0x00 {
            debounced = 0;
        }

        crate::syscall::lcd_char(if debounced == 1 { b'1' } else { b'0' });
    }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
