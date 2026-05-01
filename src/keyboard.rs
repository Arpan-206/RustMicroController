#![allow(dead_code)]

use crate::{io, syscall};

fn nibble_to_hex(n: u8) -> u8 {
    match n & 0x0f {
        0..=9 => b'0' + (n & 0x0f),
        _ => b'A' + ((n & 0x0f) - 10),
    }
}

/// Poll the keypad once per 10ms tick until a key press is detected,
/// then halt the system.
pub fn wait_for_keypress_and_halt() -> ! {
    // Ensure 10ms timer is running for scan cadence.
    io::timer_start(io::TIMER_10MS);

    loop {
        let ticks = io::counter_get();
        if ticks == 0 {
            continue;
        }
        io::counter_clr();

        let key = io::key_scan();
        if key > 0x0f {
            let row = ((key as u8) >> 4) & 0x0f;
            let col = (key as u8) & 0x0f;
            syscall::lcd_char(b'R');
            syscall::lcd_char(nibble_to_hex(row));
            syscall::lcd_char(b'C');
            syscall::lcd_char(nibble_to_hex(col));
            syscall::exit();
        }
    }
}
