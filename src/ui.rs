use crate::{lcd, utils};

#[derive(Clone, Copy)]
pub struct UiState {
    pub num1: [u8; utils::NUM_DIGITS],
    pub len1: usize,
    pub num2: [u8; utils::NUM_DIGITS],
    pub len2: usize,
    pub op: Option<u8>,
    pub result: Option<i32>,
}

impl UiState {
    pub fn new() -> Self {
        Self {
            num1: [b' '; utils::NUM_DIGITS],
            len1: 0,
            num2: [b' '; utils::NUM_DIGITS],
            len2: 0,
            op: None,
            result: None,
        }
    }
}

pub fn render_line1(state: &UiState) {
    let mut line = [b' '; 16];
    line[0..4].copy_from_slice(&state.num1);
    line[4] = b' ';
    line[5..9].copy_from_slice(&state.num2);
    line[9] = b' ';
    if let Some(op) = state.op {
        line[10] = op;
    }
    lcd::print_str(b"\r");
    lcd::print_str(&line);
}

pub fn render_line2(state: &UiState) {
    let mut line = [b' '; 16];
    if let Some(result) = state.result {
        let len = utils::write_number(&mut line, result);
        for i in len..line.len() {
            line[i] = b' ';
        }
    }
    lcd::print_str(b"\n");
    lcd::print_str(&line);
}

pub fn recompute_result(state: &mut UiState) {
    let n1 = utils::digits_to_value(&state.num1, state.len1);
    let n2 = utils::digits_to_value(&state.num2, state.len2);
    state.result = match state.op {
        Some(b'+') => Some(n1 + n2),
        Some(b'-') => Some(n1 - n2),
        _ => None,
    };
}

pub fn handle_key(state: &mut UiState, ch: u8) {
    match ch {
        b'0'..=b'9' => {
            if state.op.is_none() {
                if state.len1 < utils::NUM_DIGITS {
                    state.num1[state.len1] = ch;
                    state.len1 += 1;
                }
            } else if state.len2 < utils::NUM_DIGITS {
                state.num2[state.len2] = ch;
                state.len2 += 1;
            }
        }
        b'+' | b'-' => {
            if state.len1 > 0 && state.op.is_none() {
                state.op = Some(ch);
            }
        }
        b'F' => {
            if state.len1 > 0 && state.op.is_none() {
                state.op = Some(b'+');
            }
        }
        b'E' => {
            if state.len1 > 0 && state.op.is_none() {
                state.op = Some(b'-');
            }
        }
        b'=' => {
            if state.op.is_some() && state.len2 > 0 {
                recompute_result(state);
            }
        }
        _ => {}
    }
}
