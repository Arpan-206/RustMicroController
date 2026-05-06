#![no_std]
#![no_main]

mod io;
mod keyboard;
mod lcd;
mod syscall;

use core::panic::PanicInfo;

const LCD_WIDTH: usize = 16;

#[derive(Clone, Copy)]
enum Op {
    Mul,
    Div,
}

fn render_line1(line: &[u8; LCD_WIDTH]) {
    lcd::print_str(b"\r");
    lcd::print_str(line);
}

fn render_line2(line: &[u8; LCD_WIDTH]) {
    lcd::print_str(b"\n");
    lcd::print_str(line);
}

fn clear_line(line: &mut [u8; LCD_WIDTH]) {
    for b in line.iter_mut() {
        *b = b' ';
    }
}

fn append_digit(line: &mut [u8; LCD_WIDTH], len: &mut usize, value: &mut i32, digit: u8) -> bool {
    if *len >= LCD_WIDTH {
        return false;
    }
    let d = (digit - b'0') as i32;
    if let Some(v) = value.checked_mul(10).and_then(|v| v.checked_add(d)) {
        *value = v;
        line[*len] = digit;
        *len += 1;
        return true;
    }
    false
}

fn write_i32(buf: &mut [u8; LCD_WIDTH], n: i32) -> usize {
    clear_line(buf);
    if n == 0 {
        buf[0] = b'0';
        return 1;
    }

    let mut idx = 0;
    let mut v = n as i64;
    if v < 0 {
        buf[idx] = b'-';
        idx += 1;
        v = -v;
    }

    let mut tmp = [0u8; 12];
    let mut tlen = 0;
    while v > 0 && tlen < tmp.len() {
        tmp[tlen] = b'0' + (v % 10) as u8;
        v /= 10;
        tlen += 1;
    }

    while tlen > 0 && idx < buf.len() {
        tlen -= 1;
        buf[idx] = tmp[tlen];
        idx += 1;
    }

    idx
}

fn compute_result(a: i32, b: i32, op: Op) -> Option<i32> {
    match op {
        Op::Mul => a.checked_mul(b),
        Op::Div => a.checked_div(b),
    }
}

fn op_char(op: Op) -> u8 {
    match op {
        Op::Mul => b'*',
        Op::Div => b'/',
    }
}

fn show_result(line1: &mut [u8; LCD_WIDTH], value1: i32, value2: i32, op: Op) {
    if let Some(result) = compute_result(value1, value2, op) {
        write_i32(line1, result);
    } else {
        clear_line(line1);
        line1[0] = b'E';
        line1[1] = b'R';
        line1[2] = b'R';
    }
}

#[no_mangle]
pub extern "C" fn user_main() {
    io::timer_start(io::TIMER_10MS);

    lcd::clear();

    let mut line1 = [b' '; LCD_WIDTH];
    let mut line2 = [b' '; LCD_WIDTH];
    let mut len1: usize = 0;
    let mut len2: usize = 0;
    let mut value1: i32 = 0;
    let mut value2: i32 = 0;
    let mut op: Option<Op> = None;

    render_line1(&line1);
    render_line2(&line2);

    loop {
        if let Some(ch) = keyboard::read_key_nonblocking() {
            if ch == b'C' {
                clear_line(&mut line1);
                clear_line(&mut line2);
                len1 = 0;
                len2 = 0;
                value1 = 0;
                value2 = 0;
                op = None;
                render_line1(&line1);
                render_line2(&line2);
                continue;
            }

            if (b'0'..=b'9').contains(&ch) {
                if op.is_none() {
                    if append_digit(&mut line1, &mut len1, &mut value1, ch) {
                        render_line1(&line1);
                    }
                } else if append_digit(&mut line2, &mut len2, &mut value2, ch) {
                    render_line2(&line2);
                    if let Some(selected) = op {
                        show_result(&mut line1, value1, value2, selected);
                        render_line1(&line1);
                    }
                }
                continue;
            }

            if ch == b'A' || ch == b'B' {
                if len1 == 0 {
                    continue;
                }

                let selected = if ch == b'A' { Op::Mul } else { Op::Div };
                op = Some(selected);

                if len2 == 0 {
                    if len1 < LCD_WIDTH {
                        line1[len1] = op_char(selected);
                    }
                    render_line1(&line1);
                } else {
                    show_result(&mut line1, value1, value2, selected);
                    render_line1(&line1);
                }
            }
        }
    }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    loop {}
}
