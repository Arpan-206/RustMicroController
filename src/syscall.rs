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
    VduInit = 8,
    VduPixel = 9,
    VduFill = 10,
    VduVsync = 11,
    VduGetW = 12,
    VduGetH = 13,
    VduHlineBuf = 14,
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
fn ecall3(nr: Syscall, arg0: u32, arg1: u32, arg2: u32) {
    unsafe {
        core::arch::asm!(
            "ecall",
            in("a7") nr as u32,
            in("a0") arg0,
            in("a1") arg1,
            in("a2") arg2,
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

pub fn vdu_init(mode: u32) {
    ecall1(Syscall::VduInit, mode);
}

pub fn vdu_pixel(x: u32, y: u32, colour: u32) {
    ecall3(Syscall::VduPixel, x, y, colour);
}

pub fn vdu_fill(colour: u32) {
    ecall1(Syscall::VduFill, colour);
}

pub fn vdu_vsync() {
    ecall0(Syscall::VduVsync);
}

pub fn vdu_width() -> u32 {
    ecall0_ret(Syscall::VduGetW)
}

pub fn vdu_height() -> u32 {
    ecall0_ret(Syscall::VduGetH)
}

/// Write a full 640-byte scanline to framebuffer row `y` (8bpp mode).
pub fn vdu_hline_buf(y: u32, buf: &[u8; 640]) {
    ecall3(Syscall::VduHlineBuf, y, buf.as_ptr() as u32, 640);
}
