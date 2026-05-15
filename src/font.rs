// 7-segment digit display
// Segments:  0=top  1=top-left  2=top-right  3=mid  4=bot-left  5=bot-right  6=bottom
//
//   _
//  | |
//   -
//  | |
//   -

const TOP: u8 = 1 << 0;
const TL: u8 = 1 << 1;
const TR: u8 = 1 << 2;
const MID: u8 = 1 << 3;
const BL: u8 = 1 << 4;
const BR: u8 = 1 << 5;
const BOT: u8 = 1 << 6;

const SEG: [u8; 10] = [
    TOP | TL | TR | BL | BR | BOT,      // 0
    TR | BR,                            // 1
    TOP | TR | MID | BL | BOT,         // 2
    TOP | TR | MID | BR | BOT,         // 3
    TL | TR | MID | BR,                // 4
    TOP | TL | MID | BR | BOT,         // 5
    TOP | TL | MID | BL | BR | BOT,     // 6
    TOP | TR | BR,                     // 7
    TOP | TL | TR | MID | BL | BR | BOT,// 8
    TOP | TL | TR | MID | BR | BOT,     // 9
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