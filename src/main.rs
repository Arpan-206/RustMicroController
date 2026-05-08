#![no_std]
#![no_main]

mod display;
mod syscall;

use core::panic::PanicInfo;

fn plot(x: i32, y: i32, colour: u32) {
    if x >= 0 && y >= 0 {
        syscall::vdu_pixel(x as u32, y as u32, colour);
    }
}

fn draw_filled_circle(cx: i32, cy: i32, r: i32, colour: u32) {
    let r2 = r * r;
    for y in (cy - r)..=(cy + r) {
        let dy = y - cy;
        let dy2 = dy * dy;
        for x in (cx - r)..=(cx + r) {
            let dx = x - cx;
            let d2 = dx * dx + dy2;
            if d2 <= r2 {
                plot(x, y, colour);
            }
        }
    }
}

fn draw_smile(cx: i32, cy: i32, r: i32, thickness: i32, colour: u32) {
    let r_outer2 = r * r;
    let r_inner = r - thickness;
    let r_inner2 = r_inner * r_inner;

    for y in cy..=(cy + r) {
        let dy = y - cy;
        let dy2 = dy * dy;
        for x in (cx - r)..=(cx + r) {
            let dx = x - cx;
            let d2 = dx * dx + dy2;
            if d2 <= r_outer2 && d2 >= r_inner2 {
                plot(x, y, colour);
            }
        }
    }
}

#[no_mangle]
pub extern "C" fn user_main() {
    syscall::vdu_init(0);
    syscall::vdu_fill(display::BLACK);
    syscall::vdu_vsync();

    let cx: i32 = 320;
    let cy: i32 = 240;
    let face_r: i32 = 100;
    draw_filled_circle(cx, cy, face_r, display::YELLOW);

    let eye_r: i32 = 10;
    draw_filled_circle(cx - 35, cy - 30, eye_r, display::BLACK);
    draw_filled_circle(cx + 35, cy - 30, eye_r, display::BLACK);

    draw_smile(cx, cy + 30, 50, 6, display::BLACK);

    loop {
        syscall::vdu_vsync();
    }
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
