use crate::syscall;

pub use crate::syscall::lcd_clear as clear;

pub fn print_str(s: &[u8]) {
    for &c in s {
        syscall::lcd_char(c);
    }
}
