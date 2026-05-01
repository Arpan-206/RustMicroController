pub const NUM_DIGITS: usize = 4;

pub fn digits_to_value(digits: &[u8; NUM_DIGITS], len: usize) -> i32 {
    let mut value: i32 = 0;
    let mut i = 0;
    while i < len {
        let d = (digits[i] - b'0') as i32;
        value = value * 10 + d;
        i += 1;
    }
    value
}

pub fn write_number(buf: &mut [u8], mut n: i32) -> usize {
    if n == 0 {
        if !buf.is_empty() {
            buf[0] = b'0';
            return 1;
        }
        return 0;
    }

    let mut idx = 0;
    if n < 0 {
        if idx < buf.len() {
            buf[idx] = b'-';
            idx += 1;
        }
        n = -n;
    }

    let mut tmp = [0u8; 10];
    let mut tlen = 0;
    while n > 0 && tlen < tmp.len() {
        tmp[tlen] = b'0' + (n % 10) as u8;
        n /= 10;
        tlen += 1;
    }

    while tlen > 0 && idx < buf.len() {
        tlen -= 1;
        buf[idx] = tmp[tlen];
        idx += 1;
    }

    idx
}
