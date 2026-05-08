use crate::display;

const MAX_X: u16 = 639;
const MAX_Y: u16 = 479;
const MAX_W: u16 = 640;
const MAX_H: u16 = 480;

#[inline]
fn clamp_x(x: u16) -> u16 {
    if x > MAX_X {
        MAX_X
    } else {
        x
    }
}

#[inline]
fn clamp_y(y: u16) -> u16 {
    if y > MAX_Y {
        MAX_Y
    } else {
        y
    }
}

#[inline]
fn clamp_w(w: u16) -> u16 {
    if w > MAX_W {
        MAX_W
    } else {
        w
    }
}

#[inline]
fn clamp_h(h: u16) -> u16 {
    if h > MAX_H {
        MAX_H
    } else {
        h
    }
}

#[inline]
fn clamp_r(r: u16) -> u16 {
    if r > MAX_Y {
        MAX_Y
    } else {
        r
    }
}

#[inline]
fn read_u16_le(bytes: &[u8], offset: usize) -> u16 {
    let lo = bytes[offset] as u16;
    let hi = bytes[offset + 1] as u16;
    lo | (hi << 8)
}

pub fn render(bytecode: &[u8]) {
    let mut idx: usize = 0;
    let len = bytecode.len();

    while idx < len {
        let op = bytecode[idx];
        if op == 0xFF {
            break;
        }

        match op {
            0x01 => {
                let next = idx + 6;
                if next > len {
                    break;
                }
                let x = clamp_x(read_u16_le(bytecode, idx + 1));
                let y = clamp_y(read_u16_le(bytecode, idx + 3));
                let col = bytecode[idx + 5];
                display::pixel(x as i32, y as i32, col);
                idx = next;
            }
            0x02 => {
                let next = idx + 10;
                if next > len {
                    break;
                }
                let x1 = clamp_x(read_u16_le(bytecode, idx + 1));
                let y1 = clamp_y(read_u16_le(bytecode, idx + 3));
                let x2 = clamp_x(read_u16_le(bytecode, idx + 5));
                let y2 = clamp_y(read_u16_le(bytecode, idx + 7));
                let col = bytecode[idx + 9];
                display::line(x1 as i32, y1 as i32, x2 as i32, y2 as i32, col);
                idx = next;
            }
            0x03 => {
                let next = idx + 10;
                if next > len {
                    break;
                }
                let x = clamp_x(read_u16_le(bytecode, idx + 1));
                let y = clamp_y(read_u16_le(bytecode, idx + 3));
                let w = clamp_w(read_u16_le(bytecode, idx + 5));
                let h = clamp_h(read_u16_le(bytecode, idx + 7));
                let col = bytecode[idx + 9];
                display::filled_rect(x as i32, y as i32, w as i32, h as i32, col);
                idx = next;
            }
            0x04 => {
                let next = idx + 8;
                if next > len {
                    break;
                }
                let x = clamp_x(read_u16_le(bytecode, idx + 1));
                let y = clamp_y(read_u16_le(bytecode, idx + 3));
                let r = clamp_r(read_u16_le(bytecode, idx + 5));
                let col = bytecode[idx + 7];
                display::circle(x as i32, y as i32, r as i32, col);
                idx = next;
            }
            _ => {
                break;
            }
        }
    }
}
