#![no_std]
#![no_main]

mod io;
mod keyboard;
mod lcd;
mod syscall;

use core::panic::PanicInfo;

const LCD_WIDTH: usize = 16;
// Line-2 prompt shown after displaying a result (padded to LCD width).
const RESET_MSG: [u8; LCD_WIDTH] = *b"C to reset      ";

#[derive(Clone, Copy)]
enum Op {
    Add,
    Sub,
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

fn render_lines(line1: &[u8; LCD_WIDTH], line2: &[u8; LCD_WIDTH]) {
    render_line1(line1);
    render_line2(line2);
}

fn clear_line(line: &mut [u8; LCD_WIDTH]) {
    for b in line.iter_mut() {
        *b = b' ';
    }
}

// Append a digit if it keeps the value within i32 range and buffer space.
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

// Render a signed integer into the buffer, padding with spaces.
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

// Safe arithmetic: returns None on overflow or divide-by-zero.
fn compute_result(a: i32, b: i32, op: Op) -> Option<i32> {
    match op {
        Op::Add => a.checked_add(b),
        Op::Sub => a.checked_sub(b),
        Op::Mul => a.checked_mul(b),
        Op::Div => a.checked_div(b),
    }
}

fn op_char(op: Op) -> u8 {
    match op {
        Op::Add => b'+',
        Op::Sub => b'-',
        Op::Mul => b'*',
        Op::Div => b'/',
    }
}

// Write result (or ERR) into line 1.
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

fn show_reset_message(line2: &mut [u8; LCD_WIDTH]) {
    *line2 = RESET_MSG;
}

// Clear all inputs and internal state.
fn reset_state(
    line1: &mut [u8; LCD_WIDTH],
    line2: &mut [u8; LCD_WIDTH],
    len1: &mut usize,
    len2: &mut usize,
    value1: &mut i32,
    value2: &mut i32,
    op: &mut Option<Op>,
    locked: &mut bool,
) {
    clear_line(line1);
    clear_line(line2);
    *len1 = 0;
    *len2 = 0;
    *value1 = 0;
    *value2 = 0;
    *op = None;
    *locked = false;
}

// Show "<num1> <op>" on line 1 once the operator is chosen.
fn show_op_on_line1(line1: &mut [u8; LCD_WIDTH], len1: usize, op: Op) {
    if len1 < LCD_WIDTH {
        line1[len1] = b' ';
    }
    if len1 + 1 < LCD_WIDTH {
        line1[len1 + 1] = op_char(op);
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
    // When true, ignore input until reset (after showing a result).
    let mut locked: bool = false;

    render_lines(&line1, &line2);

    // Input flow:
    // 1) digits -> num1 (line 1)
    // 2) +, -, *, / -> operator shown on line 1
    // 3) digits -> num2 (line 2)
    // 4) '=' computes and locks until reset
    // 'C' resets at any time.
    loop {
        if let Some(ch) = keyboard::read_key_nonblocking() {
            // C always resets, even after the result lock.
            if ch == b'C' {
                reset_state(
                    &mut line1,
                    &mut line2,
                    &mut len1,
                    &mut len2,
                    &mut value1,
                    &mut value2,
                    &mut op,
                    &mut locked,
                );
                render_lines(&line1, &line2);
                continue;
            }

            // After showing a result, ignore all keys until reset.
            if locked {
                continue;
            }

            if ch == b'=' {
                if let Some(selected) = op {
                    if len2 > 0 {
                        clear_line(&mut line1);
                        clear_line(&mut line2);
                        show_result(&mut line1, value1, value2, selected);
                        show_reset_message(&mut line2);
                        render_lines(&line1, &line2);
                        locked = true;
                    }
                }
                continue;
            }

            if (b'0'..=b'9').contains(&ch) {
                if op.is_none() {
                    if append_digit(&mut line1, &mut len1, &mut value1, ch) {
                        render_line1(&line1);
                    }
                } else if append_digit(&mut line2, &mut len2, &mut value2, ch) {
                    render_line2(&line2);
                }
                continue;
            }

            if ch == b'+' || ch == b'-' || ch == b'*' || ch == b'/' {
                if len1 == 0 || len2 > 0 {
                    continue;
                }
                let selected = match ch {
                    b'+' => Op::Add,
                    b'-' => Op::Sub,
                    b'*' => Op::Mul,
                    b'/' => Op::Div,
                    _ => panic!("invalid operator key"),
                };
                op = Some(selected);
                show_op_on_line1(&mut line1, len1, selected);
                render_line1(&line1);
            }
        }
    }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    // Ensure keypad scanning is active while waiting for reset.
    io::timer_start(io::TIMER_10MS);
    lcd::clear();

    let mut line1 = [b' '; LCD_WIDTH];
    let line2 = RESET_MSG;
    line1[0] = b'E';
    line1[1] = b'R';
    line1[2] = b'R';
    render_lines(&line1, &line2);

    loop {
        if let Some(ch) = keyboard::read_key_nonblocking() {
            if ch == b'C' {
                lcd::clear();
                user_main();
            }
        }
    }
}
