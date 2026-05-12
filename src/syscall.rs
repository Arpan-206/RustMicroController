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
    KeyScan = 7,
    DrawRect = 10,
    DrawCircle = 11,
    DrawLine = 12,
}

// ── raw ecall primitives ────────────────────────────────────────────

#[inline(never)]
fn ecall0(nr: Syscall) {
    let _ = ecall0_ret(nr);
}

#[inline(never)]
fn ecall1(nr: Syscall, arg: u32) {
    let _ = ecall1_ret(nr, arg);
}

#[inline(never)]
fn ecall5(nr: Syscall, arg0: u32, arg1: u32, arg2: u32, arg3: u32, arg4: u32) {
    unsafe {
        core::arch::asm!(
            "ecall",
            in("a7") nr as u32,
            in("a0") arg0,
            in("a1") arg1,
            in("a2") arg2,
            in("a3") arg3,
            in("a4") arg4,
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

/// Read next debounced keycode from FIFO. Returns 0 if none.
pub fn key_scan() -> i32 {
    ecall0_ret(Syscall::KeyScan) as i32
}

pub fn draw_rect(x0: u32, y0: u32, x1: u32, y1: u32, colour: u32) {
    ecall5(Syscall::DrawRect, x0, y0, x1, y1, colour);
}

pub fn draw_circle(cx: u32, cy: u32, radius: u32, y1: u32, colour: u32) {
    ecall5(Syscall::DrawCircle, cx, cy, radius, y1, colour);
}

pub fn draw_line(x0: u32, y0: u32, x1: u32, y1: u32, colour: u32) {
    ecall5(Syscall::DrawLine, x0, y0, x1, y1, colour);
}
