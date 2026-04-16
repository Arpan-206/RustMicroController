#![allow(dead_code)]

/// Syscall numbers — must match sys_table order in os.s.
#[repr(u32)]
enum Syscall {
    Exit      = 0,
    LcdChar   = 1,
    LcdClear  = 2,
    BtnRead   = 3,
    SharedGet = 4,  // read isr_dirty
    SharedClr = 5,  // clear isr_dirty
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

/// Returns non-zero if the button ISR has fired since last clear.
pub fn shared_get() -> u32 {
    ecall0_ret(Syscall::SharedGet)
}

/// Clear the ISR dirty flag.
pub fn shared_clr() {
    ecall0(Syscall::SharedClr);
}
