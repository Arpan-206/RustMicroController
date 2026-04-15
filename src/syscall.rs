pub const SYS_EXIT: u32 = 0;
pub const SYS_LCD_CHAR: u32 = 1;
pub const SYS_LCD_CLEAR: u32 = 2;

#[link_section = ".utext"]
#[inline(never)]
pub fn ecall1(nr: u32, arg: u32) {
    unsafe {
        core::arch::asm!(
            "ecall",
            in("a7") nr,
            in("a0") arg,
            options(nostack)
        );
    }
}

#[link_section = ".utext"]
#[inline(never)]
pub fn ecall0(nr: u32) {
    unsafe {
        core::arch::asm!(
            "ecall",
            in("a7") nr,
            options(nostack)
        );
    }
}

#[link_section = ".utext"]
pub fn lcd_char(c: u8) {
    ecall1(SYS_LCD_CHAR, c as u32);
}

#[link_section = ".utext"]
pub fn lcd_clear() {
    ecall0(SYS_LCD_CLEAR);
}

#[link_section = ".utext"]
pub fn exit() -> ! {
    loop {
        ecall0(SYS_EXIT);
    }
}

#[link_section = ".utext"]
pub fn print_str(s: &[u8]) {
    for &c in s {
        lcd_char(c);
    }
}
