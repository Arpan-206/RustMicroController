#![allow(dead_code)]

pub use crate::syscall::{btn_read, counter_clr, counter_get, key_scan, timer_start};

/// Button bit masks (from hardware spec).
pub const BTN_START: u8 = 0x01;
pub const BTN_PAUSE: u8 = 0x02;
pub const BTN_RESET: u8 = 0x04;

/// Timer modulus helpers (limit register uses modulus minus 1).
pub const TIMER_1S: u32 = 999_999;
pub const TIMER_10MS: u32 = 9_999;
pub const TIMER_1MS: u32 = 999;
