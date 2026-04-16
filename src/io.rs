#![allow(dead_code)]

use crate::syscall;

/// Button bit masks (from hardware spec).
pub const BTN_START: u8 = 0x01;
pub const BTN_PAUSE: u8 = 0x02;
pub const BTN_RESET: u8 = 0x04;

/// Timer modulus helpers (limit register uses modulus minus 1).
pub const TIMER_1S: u32 = 999_999;
pub const TIMER_1MS: u32 = 999;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum TimerStatus {
    NotFired,
    Fired,
    Overrun,
}

pub fn btn_read() -> u8 {
    syscall::btn_read()
}

pub fn timer_init(modulus_minus_1: u32) {
    syscall::timer_init(modulus_minus_1);
}

pub fn timer_poll_raw() -> u32 {
    syscall::timer_poll()
}

pub fn timer_poll_status() -> TimerStatus {
    match timer_poll_raw() {
        1 => TimerStatus::Fired,
        2 => TimerStatus::Overrun,
        _ => TimerStatus::NotFired,
    }
}

pub fn timer_ack() {
    syscall::timer_ack();
}
