use crate::syscall;

pub fn print_str(s: &[u8]) {
    for &c in s {
        syscall::lcd_char(c);
    }
}

pub fn clear() {
    syscall::lcd_clear();
}
