#![allow(dead_code)]

use crate::shared::SharedSlot;

/// Syscall numbers — must match sys_table order in os.s.
#[repr(u32)]
enum Syscall {
    Exit       = 0,
    LcdChar    = 1,
    LcdClear   = 2,
    BtnRead    = 3,
    TimerInit  = 4,
    TimerPoll  = 5,
    TimerAck   = 6,
    SharedGet  = 7,
    SharedSet  = 8,
}

// ── raw ecall primitives ────────────────────────────────────────────────────

#[inline(never)]
fn ecall0(nr: Syscall) {
    unsafe {
        core::arch::asm!(
            "ecall",
            in("a7") nr as u32,
            options(nostack)
        );
    }
}

#[inline(never)]
fn ecall1(nr: Syscall, arg: u32) {
    unsafe {
        core::arch::asm!(
            "ecall",
            in("a7") nr as u32,
            in("a0") arg,
            options(nostack)
        );
    }
}

#[inline(never)]
fn ecall0_ret(nr: Syscall) -> u32 {
    let ret: u32;
    unsafe {
        core::arch::asm!(
            "ecall",
            in("a7") nr as u32,
            lateout("a0") ret,
            options(nostack)
        );
    }
    ret
}

#[inline(never)]
fn ecall1_ret(nr: Syscall, arg: u32) -> u32 {
    let ret: u32;
    unsafe {
        core::arch::asm!(
            "ecall",
            in("a7") nr as u32,
            inlateout("a0") arg => ret,
            options(nostack)
        );
    }
    ret
}

#[inline(never)]
fn ecall2(nr: Syscall, a0: u32, a1: u32) {
    unsafe {
        core::arch::asm!(
            "ecall",
            in("a7") nr as u32,
            in("a0") a0,
            in("a1") a1,
            options(nostack)
        );
    }
}

// ── public API ──────────────────────────────────────────────────────────────

pub fn lcd_char(c: u8) {
    ecall1(Syscall::LcdChar, c as u32);
}

pub fn lcd_clear() {
    ecall0(Syscall::LcdClear);
}

pub fn btn_read() -> u8 {
    ecall0_ret(Syscall::BtnRead) as u8
}

pub fn timer_init(modulus_minus_1: u32) {
    ecall1(Syscall::TimerInit, modulus_minus_1);
}

pub fn timer_poll() -> u32 {
    ecall0_ret(Syscall::TimerPoll)
}

pub fn timer_ack() {
    ecall0(Syscall::TimerAck);
}

pub fn shared_get(slot: SharedSlot) -> u32 {
    ecall1_ret(Syscall::SharedGet, slot as u32)
}

pub fn shared_set(slot: SharedSlot, value: u32) {
    ecall2(Syscall::SharedSet, slot as u32, value);
}

pub fn exit() -> ! {
    loop {
        ecall0(Syscall::Exit);
    }
}
