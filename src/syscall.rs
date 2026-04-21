#![allow(dead_code)]

/// Syscall numbers — must match sys_table order in os.s.
#[repr(u32)]
enum Syscall {
    Exit = 0,
    LcdChar = 1,
    LcdClear = 2,
    BtnRead = 3,
    CounterGet = 4, // read s5 tick counter
    CounterClr = 5, // clear s5 tick counter
    TimerStart = 6, // start timer with given modulus
    KbdScan = 7,
}

// ── raw ecall primitives ────────────────────────────────────────────

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

// ── public API ──────────────────────────────────────────────────────

pub fn lcd_char(c: u8) {
    ecall1(Syscall::LcdChar, c as u32);
}

pub fn lcd_clear() {
    ecall0(Syscall::LcdClear);
}

pub fn btn_read() -> u8 {
    ecall0_ret(Syscall::BtnRead) as u8
}

pub fn exit() -> ! {
    loop {
        ecall0(Syscall::Exit);
    }
}

/// Returns current value of s5 tick counter.
pub fn counter_get() -> u32 {
    ecall0_ret(Syscall::CounterGet)
}

/// Reset s5 tick counter to zero.
pub fn counter_clr() {
    ecall0(Syscall::CounterClr);
}

/// Start the timer with the given modulus (limit register value).
pub fn timer_start(modulus: u32) {
    ecall1(Syscall::TimerStart, modulus);
}

pub fn kbd_scan(row: u8) -> u8 {
    ecall1_ret(Syscall::KbdScan, row as u32) as u8
}
