#![allow(dead_code)]

use crate::io;

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

/// Return the next debounced key from the FIFO, if any.
pub fn read_key_nonblocking() -> Option<u8> {
    let key = io::key_scan();
    if key > 0x0f {
        return keycode_to_ascii(key as u8);
    }
    None
}

/// Block until a debounced key is available, then return it.
pub fn read_key_blocking() -> u8 {
    loop {
        if let Some(ch) = read_key_nonblocking() {
            return ch;
        }
    }
}
