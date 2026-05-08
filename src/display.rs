#![allow(dead_code)]

use crate::syscall;

const SCREEN_W: i32 = 640;
const SCREEN_H: i32 = 480;

pub const fn rgb8(r: u8, g: u8, b: u8) -> u8 {
    let r3 = r >> 5;
    let g3 = g >> 5;
    let b2 = b >> 6;
    (r3 << 5) | (g3 << 2) | b2
}

pub const fn rgb16(r: u8, g: u8, b: u8) -> u16 {
    let r5 = (r as u16) >> 3;
    let g6 = (g as u16) >> 2;
    let b5 = (b as u16) >> 3;
    (r5 << 11) | (g6 << 5) | b5
}

pub const BLACK: u8 = 0x00;
pub const WHITE: u8 = 0xFF;
pub const RED: u8 = 0xE0;
pub const GREEN: u8 = 0x1C;
pub const BLUE: u8 = 0x03;
pub const YELLOW: u8 = 0xFC;
pub const CYAN: u8 = 0x1F;
pub const MAGENTA: u8 = 0xE3;

#[inline]
fn plot(x: i32, y: i32, colour: u8) {
    if x >= 0 && x < SCREEN_W && y >= 0 && y < SCREEN_H {
        syscall::vdu_pixel(x as u32, y as u32, colour as u32);
    }
}

pub fn fill(colour: u8) {
    syscall::vdu_fill(colour as u32);
}

pub fn hline(x: i32, y: i32, len: i32, colour: u8) {
    if len <= 0 {
        return;
    }
    for i in 0..len {
        plot(x + i, y, colour);
    }
}

pub fn vline(x: i32, y: i32, len: i32, colour: u8) {
    if len <= 0 {
        return;
    }
    for i in 0..len {
        plot(x, y + i, colour);
    }
}

pub fn rect(x: i32, y: i32, w: i32, h: i32, colour: u8) {
    if w <= 0 || h <= 0 {
        return;
    }
    for i in 0..h {
        hline(x, y + i, w, colour);
    }
}

pub fn line(x0: i32, y0: i32, x1: i32, y1: i32, colour: u8) {
    let mut x = x0;
    let mut y = y0;
    let dx = (x1 - x0).abs();
    let sx = if x0 < x1 { 1 } else { -1 };
    let dy = -(y1 - y0).abs();
    let sy = if y0 < y1 { 1 } else { -1 };
    let mut err = dx + dy;

    loop {
        plot(x, y, colour);
        if x == x1 && y == y1 {
            break;
        }
        let e2 = 2 * err;
        if e2 >= dy {
            err += dy;
            x += sx;
        }
        if e2 <= dx {
            err += dx;
            y += sy;
        }
    }
}

pub fn circle(cx: i32, cy: i32, r: i32, colour: u8) {
    if r <= 0 {
        return;
    }
    let mut x = r;
    let mut y = 0;
    let mut err = 1 - x;

    while x >= y {
        plot(cx + x, cy + y, colour);
        plot(cx + y, cy + x, colour);
        plot(cx - y, cy + x, colour);
        plot(cx - x, cy + y, colour);
        plot(cx - x, cy - y, colour);
        plot(cx - y, cy - x, colour);
        plot(cx + y, cy - x, colour);
        plot(cx + x, cy - y, colour);

        y += 1;
        if err < 0 {
            err += 2 * y + 1;
        } else {
            x -= 1;
            err += 2 * (y - x) + 1;
        }
    }
}

pub struct Sprite1bpp {
    pub w: u8,
    pub h: u8,
    pub frames: u8,
    data: &'static [u8],
}

impl Sprite1bpp {
    pub const fn new(w: u8, h: u8, frames: u8, data: &'static [u8]) -> Self {
        Self { w, h, frames, data }
    }

    pub fn draw(&self, x: i32, y: i32, frame: u8, fg: u8, bg: u8) {
        self.draw_impl(x, y, frame, fg, Some(bg));
    }

    pub fn draw_transparent(&self, x: i32, y: i32, frame: u8, fg: u8) {
        self.draw_impl(x, y, frame, fg, None);
    }

    fn frame_offset(&self, frame: u8) -> usize {
        let stride = ((self.w as usize) + 7) / 8;
        if self.frames == 0 {
            return 0;
        }
        let f = (frame % self.frames) as usize;
        f * stride * (self.h as usize)
    }

    fn draw_impl(&self, x: i32, y: i32, frame: u8, fg: u8, bg: Option<u8>) {
        let stride = ((self.w as usize) + 7) / 8;
        let base = self.frame_offset(frame);
        let w = self.w as i32;
        let h = self.h as i32;

        for row in 0..h {
            let dy = y + row;
            if dy < 0 || dy >= SCREEN_H {
                continue;
            }
            let row_off = base + (row as usize) * stride;
            for col in 0..w {
                let dx = x + col;
                if dx < 0 || dx >= SCREEN_W {
                    continue;
                }
                let byte = self.data[row_off + (col as usize / 8)];
                let bit = 7 - (col as usize & 7);
                let set = ((byte >> bit) & 1) != 0;
                if set {
                    plot(dx, dy, fg);
                } else if let Some(bg_col) = bg {
                    plot(dx, dy, bg_col);
                }
            }
        }
    }
}

pub struct Rect {
    pub x: i16,
    pub y: i16,
    pub w: i16,
    pub h: i16,
}

pub struct AnimSprite {
    pub sprite: &'static Sprite1bpp,
    pub x: i32,
    pub y: i32,
    pub dx: i32,
    pub dy: i32,
    pub frame: u8,
    dirty: Rect,
    bg: u8,
}

impl AnimSprite {
    pub const fn new(
        sprite: &'static Sprite1bpp,
        x: i32,
        y: i32,
        dx: i32,
        dy: i32,
        bg: u8,
    ) -> Self {
        Self {
            sprite,
            x,
            y,
            dx,
            dy,
            frame: 0,
            dirty: Rect {
                x: x as i16,
                y: y as i16,
                w: sprite.w as i16,
                h: sprite.h as i16,
            },
            bg,
        }
    }

    pub fn update(&mut self) {
        rect(
            self.dirty.x as i32,
            self.dirty.y as i32,
            self.dirty.w as i32,
            self.dirty.h as i32,
            self.bg,
        );

        self.x += self.dx;
        self.y += self.dy;

        self.sprite
            .draw_transparent(self.x, self.y, self.frame, WHITE);

        self.dirty = Rect {
            x: self.x as i16,
            y: self.y as i16,
            w: self.sprite.w as i16,
            h: self.sprite.h as i16,
        };

        if self.sprite.frames != 0 {
            self.frame = self.frame.wrapping_add(1) % self.sprite.frames;
        }
    }

    pub fn bounce(&mut self, x_max: i32, y_max: i32) {
        let w = self.sprite.w as i32;
        let h = self.sprite.h as i32;
        let max_x = x_max - w;
        let max_y = y_max - h;

        if max_x < 0 {
            self.x = 0;
            self.dx = -self.dx;
        } else if self.x < 0 {
            self.x = 0;
            self.dx = -self.dx;
        } else if self.x > max_x {
            self.x = max_x;
            self.dx = -self.dx;
        }

        if max_y < 0 {
            self.y = 0;
            self.dy = -self.dy;
        } else if self.y < 0 {
            self.y = 0;
            self.dy = -self.dy;
        } else if self.y > max_y {
            self.y = max_y;
            self.dy = -self.dy;
        }
    }
}

pub static BALL: Sprite1bpp = Sprite1bpp::new(
    8,
    8,
    1,
    &[
        0b00111100, 0b01111110, 0b11111111, 0b11111111, 0b11111111, 0b11111111, 0b01111110,
        0b00111100,
    ],
);

pub static WALKER: Sprite1bpp = Sprite1bpp::new(
    8,
    8,
    2,
    &[
        // frame 0
        0b00011000, 0b00111100, 0b00011000, 0b00111100, 0b01011010, 0b00011000, 0b00100100,
        0b01000010, // frame 1
        0b00011000, 0b00111100, 0b00011000, 0b00111100, 0b01011010, 0b00011000, 0b01000010,
        0b00100100,
    ],
);
