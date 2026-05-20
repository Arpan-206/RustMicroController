#![allow(dead_code)]

use crate::syscall;

// Colour type — RRRGGGBB 8bpp
#[derive(Copy, Clone)]
pub struct Colour(pub u8);

impl Colour {
    pub const RED: Self = Self(0xE0);
    pub const GREEN: Self = Self(0x1C);
    pub const BLUE: Self = Self(0x03);
    pub const WHITE: Self = Self(0xFF);
    pub const BLACK: Self = Self(0x00);

    pub fn rgb(r: u8, g: u8, b: u8) -> Self {
        Self((r & 0x7) << 5 | (g & 0x7) << 2 | (b & 0x3))
    }
}

#[inline(always)]
fn draw_rect_syscall(x0: u16, y0: u16, x1: u16, y1: u16, colour: Colour) {
    syscall::draw_rect(x0 as u32, y0 as u32, x1 as u32, y1 as u32, colour.0 as u32);
}

#[inline(always)]
fn draw_circle_syscall(cx: u16, cy: u16, radius: u16, colour: Colour) {
    syscall::draw_circle(cx as u32, cy as u32, radius as u32, 0, colour.0 as u32);
}

#[inline(always)]
fn draw_line_syscall(x0: u16, y0: u16, x1: u16, y1: u16, thickness: u16, colour: Colour) {
    syscall::draw_line(
        x0 as u32,
        y0 as u32,
        x1 as u32,
        y1 as u32,
        colour.0 as u32,
        thickness as u32,
    );
}

pub fn fill_triangle(x0: u16, y0: u16, x1: u16, y1: u16, x2: u16, y2: u16, colour: u8) {
    syscall::fill_triangle(
        x0 as u32,
        y0 as u32,
        x1 as u32,
        y1 as u32,
        x2 as u32,
        y2 as u32,
        colour as u32,
    );
}

pub fn fill_circle(cx: u16, cy: u16, radius: u16, colour: u8) {
    syscall::fill_circle(cx as u32, cy as u32, radius as u32, colour as u32);
}

pub fn draw_rect(x0: u16, y0: u16, x1: u16, y1: u16, colour: Colour) {
    draw_rect_syscall(x0, y0, x1, y1, colour);
}

pub fn fill_rect(x0: u16, y0: u16, x1: u16, y1: u16, colour: Colour) {
    draw_rect_syscall(x0, y0, x1, y1, colour);
}

pub fn draw_circle(cx: u16, cy: u16, radius: u16, colour: Colour) {
    draw_circle_syscall(cx, cy, radius, colour);
}

pub fn draw_line(x0: u16, y0: u16, x1: u16, y1: u16, thickness: u16, colour: Colour) {
    draw_line_syscall(x0, y0, x1, y1, thickness, colour);
}

// Convenience: 4 draw_line calls for top/bottom/left/right edges
pub fn draw_rect_outline(x0: u16, y0: u16, x1: u16, y1: u16, colour: Colour) {
    draw_line(x0, y0, x1, y0, 1, colour);
    draw_line(x0, y1, x1, y1, 1, colour);
    draw_line(x0, y0, x0, y1, 1, colour);
    draw_line(x1, y0, x1, y1, 1, colour);
}
