#![no_std]
#![no_main]

mod io;
mod lcd;
mod syscall;

use core::panic::PanicInfo;
use io::{BTN_PAUSE, BTN_RESET, BTN_START, TIMER_1S};

const BCD_SEC_MAX: u8 = 0x60;
const BCD_MIN_MAX: u8 = 0x60;
const BCD_HR_MAX: u8 = 0x24;

fn bcd_inc(val: u8, limit: u8) -> u8 {
    let mut v = val.wrapping_add(1);
    if v & 0xF >= 10 {
        v = v.wrapping_add(6);
    }
    if v >= limit {
        0
    } else {
        v
    }
}

fn print_bcd2(byte: u8) {
    lcd::print_str(&[b'0' + (byte >> 4), b'0' + (byte & 0xF)]);
}

fn print_time(hh: u8, mm: u8, ss: u8) {
    lcd::print_str(b"\n");
    print_bcd2(hh);
    lcd::print_str(b":");
    print_bcd2(mm);
    lcd::print_str(b":");
    print_bcd2(ss);
}

// Opaque setter — #[inline(never)] stops the optimizer seeing through
// the running flag assignment and collapsing the if/else chain.
#[inline(never)]
fn set_running(running: &mut u8, val: u8) {
    *running = val;
}

#[no_mangle]
pub extern "C" fn user_main() {
    io::timer_init(TIMER_1S);

    let mut hh: u8 = 0;
    let mut mm: u8 = 0;
    let mut ss: u8 = 0;
    let mut running: u8 = 0;

    lcd::clear();
    lcd::print_str(b"Stopwatch");
    print_time(hh, mm, ss);

    loop {
        // ── consume ticks deposited by the timer ISR ─────────────────
        let ticks = syscall::shared_get();
        if ticks != 0 {
            syscall::shared_clr();
            if running != 0 {
                let mut remaining = ticks;
                while remaining > 0 {
                    remaining -= 1;
                    ss = bcd_inc(ss, BCD_SEC_MAX);
                    if ss == 0 {
                        mm = bcd_inc(mm, BCD_MIN_MAX);
                        if mm == 0 {
                            hh = bcd_inc(hh, BCD_HR_MAX);
                        }
                    }
                }
                print_time(hh, mm, ss);
            }
        }

        // ── buttons ──────────────────────────────────────────────────
        let btns = io::btn_read();
        if btns & BTN_START != 0 {
            set_running(&mut running, 1);
        } else if btns & BTN_PAUSE != 0 {
            set_running(&mut running, 0);
        } else if btns & BTN_RESET != 0 && running == 0 {
            hh = 0;
            mm = 0;
            ss = 0;
            print_time(hh, mm, ss);
        }
    }
}

#[panic_handler]
fn panic(_: &PanicInfo) -> ! {
    lcd::print_str(b"ERROR");
    loop {}
}
