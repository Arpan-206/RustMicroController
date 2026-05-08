#![allow(dead_code)]

pub const fn rgb8(r: u8, g: u8, b: u8) -> u32 {
    let r3 = (r as u32) >> 5;
    let g3 = (g as u32) >> 5;
    let b2 = (b as u32) >> 6;
    (r3 << 5) | (g3 << 2) | b2
}

pub const fn rgb16(r: u8, g: u8, b: u8) -> u32 {
    let r5 = (r as u32) >> 3;
    let g6 = (g as u32) >> 2;
    let b5 = (b as u32) >> 3;
    (r5 << 11) | (g6 << 5) | b5
}

pub const BLACK: u32 = 0x00;
pub const WHITE: u32 = 0xFF;
pub const RED: u32 = 0xE0;
pub const GREEN: u32 = 0x1C;
pub const BLUE: u32 = 0x03;
pub const YELLOW: u32 = 0xFC;
pub const CYAN: u32 = 0x1F;
pub const MAGENTA: u32 = 0xE3;
