#![allow(dead_code)]

use crate::{io, syscall};

const KEYMAP: [[u8; 4]; 4] = [
    [b'1', b'2', b'3', b'+'],
    [b'4', b'5', b'6', b'-'],
    [b'7', b'8', b'9', b'='],
    [b'*', b'0', b'#', b'/'],
];

fn keycode_to_ascii(key: u8) -> Option<u8> {
    let row = (key >> 4) & 0x0f;
    let col = key & 0x0f;

    let row_idx = match row {
        0x8 => 0,
        0x4 => 1,
        0x2 => 2,
        0x1 => 3,
        _ => return None,
    };

    let col_idx = match col {
        0x1 => 0,
        0x2 => 1,
        0x4 => 2,
        0x8 => 3,
        _ => return None,
    };

    Some(KEYMAP[row_idx][col_idx])
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
            if let Some(ch) = keycode_to_ascii(key as u8) {
                syscall::lcd_char(ch);
            }
            syscall::exit();
        }
    }
}
