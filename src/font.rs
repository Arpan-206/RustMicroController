// 7-segment digit display
// Segments:  0=top  1=top-left  2=top-right  3=mid  4=bot-left  5=bot-right  6=bottom
//
//   _
//  | |
//   -
//  | |
//   -

const SEG: [u8; 10] = [
    0b0111111, // 0
    0b0000110, // 1
    0b1011011, // 2
    0b1001111, // 3
    0b1100110, // 4
    0b1101101, // 5
    0b1111101, // 6
    0b0000111, // 7
    0b1111111, // 8
    0b1101111, // 9
];

// Each segment as (dx0, dy0, dx1, dy1) relative to glyph top-left
// for a glyph that is W wide, H tall with thickness T
// W=16, H=24, T=3
const W: u16 = 16;
const H: u16 = 24;
const T: u16 = 3;

pub fn draw_digit(x: u16, y: u16, digit: u8, colour: u8) {
    use crate::display::{fill_rect, Colour};

    let d = digit as usize;
    if d > 9 {
        return;
    }

    let s = SEG[d];
    let c = Colour(colour);

    // top bar
    if s & (1 << 0) != 0 {
        fill_rect(x, y, x + W, y + T, c);
    }
    // top-left
    if s & (1 << 1) != 0 {
        fill_rect(x, y, x + T, y + H / 2, c);
    }
    // top-right
    if s & (1 << 2) != 0 {
        fill_rect(x + W - T, y, x + W, y + H / 2, c);
    }
    // middle
    if s & (1 << 3) != 0 {
        fill_rect(x, y + H / 2 - T / 2, x + W, y + H / 2 + T / 2, c);
    }
    // bot-left
    if s & (1 << 4) != 0 {
        fill_rect(x, y + H / 2, x + T, y + H, c);
    }
    // bot-right
    if s & (1 << 5) != 0 {
        fill_rect(x + W - T, y + H / 2, x + W, y + H, c);
    }
    // bottom
    if s & (1 << 6) != 0 {
        fill_rect(x, y + H - T, x + W, y + H, c);
    }
}

pub fn erase_digit(x: u16, y: u16) {
    use crate::display::{fill_rect, Colour};

    fill_rect(x, y, x + W, y + H, Colour(crate::pong::BG));
}