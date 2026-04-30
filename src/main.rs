#![no_std]
#![no_main]

mod syscall;

use core::panic::PanicInfo;

#[no_mangle]
pub extern "C" fn user_main() {
    // 10 ms tick for keypad scanning
    syscall::timer_start(9_999);

    loop {
        let key = syscall::key_read();
        if key == -1 {
            continue;
        }
        syscall::lcd_char(key as u8);
    }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
