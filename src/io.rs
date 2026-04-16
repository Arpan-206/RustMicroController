#![allow(dead_code)]

use crate::syscall;

/// Button bit masks (from hardware spec).
pub const BTN_START: u8 = 0x01;
pub const BTN_PAUSE: u8 = 0x02;
pub const BTN_RESET: u8 = 0x04;

/// Timer modulus helpers (limit register uses modulus minus 1).
pub const TIMER_1S: u32 = 999_999;
pub const TIMER_1MS: u32 = 999;

pub fn btn_read() -> u8 {
    syscall::btn_read()
}

/// Start the interrupt-driven timer with the given modulus.
pub fn timer_start(modulus: u32) {
    syscall::timer_start(modulus);
}

/// Read the tick counter (incremented by timer ISR each second).
pub fn counter_get() -> u32 {
    syscall::counter_get()
}

/// Reset the tick counter to zero.
pub fn counter_clr() {
    syscall::counter_clr();
}
