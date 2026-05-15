use crate::display::{draw_rect, fill_circle, Colour};
use crate::{font, io, keyboard, syscall};
use crate::lcd;

const SCREEN_W: u16 = 640;
const SCREEN_H: u16 = 480;
const PADDLE_W: u16 = 12;
const PADDLE_H: u16 = 80;
const BALL_R: u16 = 10;
const PADDLE_SPD: i16 = 5;
const BALL_SPD_X: i16 = 4;
const BALL_SPD_Y: i16 = 3;
const FPS: u32 = 30;
const INPUT_REPEAT_FRAMES: u8 = 8;
pub const BG: u8 = 0x00;
const P1_COL: u8 = 0xE0;
const P2_COL: u8 = 0x1C;
const BALL_COL: u8 = 0xFF;
const NET_COL: u8 = 0x24;
const P1_SCORE_X: u16 = 260;
const P2_SCORE_X: u16 = 364;
const SCORE_Y: u16 = 10;

const P1_X: i16 = 20;
const P2_X: i16 = (SCREEN_W as i16) - 20 - (PADDLE_W as i16);
const NET_X0: u16 = (SCREEN_W / 2) - 2;
const NET_X1: u16 = (SCREEN_W / 2) + 1;

#[derive(Copy, Clone)]
struct Ball {
    x: i16,
    y: i16,
}

pub fn run() -> ! {
    io::timer_start(io::TIMER_1MS);
    syscall::counter_clr();

    let mut ticks_per_frame = 1000 / FPS;
    if ticks_per_frame == 0 {
        ticks_per_frame = 1;
    }

    show_start_screen();
    wait_for_start_key();

    let mut p1_y: i16 = ((SCREEN_H as i16) - (PADDLE_H as i16)) / 2;
    let mut p2_y: i16 = p1_y;
    let mut ball = Ball {
        x: (SCREEN_W as i16) / 2,
        y: (SCREEN_H as i16) / 2,
    };
    let mut ball_vx: i16 = BALL_SPD_X;
    let mut ball_vy: i16 = BALL_SPD_Y;
    let mut p1_score: u8 = 0;
    let mut p2_score: u8 = 0;
    let mut serve_left = false;
    let mut p1_dir: i16 = 0;
    let mut p2_dir: i16 = 0;
    let mut p1_repeat: u8 = 0;
    let mut p2_repeat: u8 = 0;

    clear_and_draw_world(p1_y, p2_y, ball, p1_score, p2_score);
    update_lcd_score(p1_score, p2_score);

    loop {
        let start = syscall::counter_get();

        let old_p1_y = p1_y;
        let old_p2_y = p2_y;
        let old_ball = ball;

        while let Some(key) = keyboard::read_key_nonblocking() {
            match key {
                b'1' => {
                    p1_dir = -1;
                    p1_repeat = INPUT_REPEAT_FRAMES;
                }
                b'7' => {
                    p1_dir = 1;
                    p1_repeat = INPUT_REPEAT_FRAMES;
                }
                b'3' => {
                    p2_dir = -1;
                    p2_repeat = INPUT_REPEAT_FRAMES;
                }
                b'9' => {
                    p2_dir = 1;
                    p2_repeat = INPUT_REPEAT_FRAMES;
                }
                _ => {}
            }
        }

        if p1_repeat > 0 && p1_dir != 0 {
            p1_y += p1_dir * PADDLE_SPD;
            p1_repeat -= 1;
        }

        if p2_repeat > 0 && p2_dir != 0 {
            p2_y += p2_dir * PADDLE_SPD;
            p2_repeat -= 1;
        }

        p1_y = clamp_paddle_y(p1_y);
        p2_y = clamp_paddle_y(p2_y);

        ball.x += ball_vx;
        ball.y += ball_vy;

        if ball.y - (BALL_R as i16) <= 0 {
            ball.y = BALL_R as i16;
            ball_vy = -ball_vy;
        } else if ball.y + (BALL_R as i16) >= (SCREEN_H as i16) - 1 {
            ball.y = (SCREEN_H as i16) - 1 - (BALL_R as i16);
            ball_vy = -ball_vy;
        }

        let p1_bottom = p1_y + (PADDLE_H as i16);
        let p2_bottom = p2_y + (PADDLE_H as i16);
        let ball_top = ball.y - (BALL_R as i16);
        let ball_bottom = ball.y + (BALL_R as i16);

        if ball_vx < 0
            && ball.x - (BALL_R as i16) <= P1_X + (PADDLE_W as i16)
            && ball_bottom >= p1_y
            && ball_top <= p1_bottom
            && ball.x >= P1_X
        {
            ball.x = P1_X + (PADDLE_W as i16) + (BALL_R as i16) + 1;
            ball_vx = -(ball_vx - 1);
        } else if ball_vx > 0
            && ball.x + (BALL_R as i16) >= P2_X
            && ball_bottom >= p2_y
            && ball_top <= p2_bottom
            && ball.x <= P2_X + (PADDLE_W as i16)
        {
            ball.x = P2_X - (BALL_R as i16) - 1;
            ball_vx = -(ball_vx + 1);
        }

        let mut scored = false;
        if ball.x < 0 {
            p2_score = next_score(p2_score);
            serve_left = !serve_left;
            reset_ball(&mut ball, serve_left, &mut ball_vx, &mut ball_vy);
            scored = true;
        } else if ball.x > SCREEN_W as i16 {
            p1_score = next_score(p1_score);
            serve_left = !serve_left;
            reset_ball(&mut ball, serve_left, &mut ball_vx, &mut ball_vy);
            scored = true;
        }

        if scored {
            clear_and_draw_world(p1_y, p2_y, ball, p1_score, p2_score);
            update_lcd_score(p1_score, p2_score);
        } else {
            draw_paddle(old_p1_y, BG, P1_X);
            draw_paddle(old_p2_y, BG, P2_X);
            draw_ball(old_ball.x, old_ball.y, BG);

            draw_paddle(p1_y, P1_COL, P1_X);
            draw_paddle(p2_y, P2_COL, P2_X);
            draw_ball(ball.x, ball.y, BALL_COL);
        }

        while syscall::counter_get().wrapping_sub(start) < ticks_per_frame {}
    }
}

fn show_start_screen() {
    draw_rect(0, 0, SCREEN_W - 1, SCREEN_H - 1, Colour(BG));

    let scale: u16 = 8;
    let title = b"PONG";
    let text_w = font::char_width(scale) * title.len() as u16;
    let text_h = font::char_height(scale);
    let x = (SCREEN_W - text_w) / 2;
    let y = (SCREEN_H - text_h) / 2;

    font::draw_str(x, y, title, BALL_COL, scale);
}

fn wait_for_start_key() {
    loop {
        while let Some(key) = keyboard::read_key_nonblocking() {
            if key == b'1' {
                return;
            }
        }

        let start = syscall::counter_get();
        while syscall::counter_get().wrapping_sub(start) < 10 {}
    }
}

fn clear_and_draw_world(p1_y: i16, p2_y: i16, ball: Ball, p1_score: u8, p2_score: u8) {
    draw_rect(0, 0, SCREEN_W - 1, SCREEN_H - 1, Colour(BG));
    draw_net();
    draw_paddle(p1_y, P1_COL, P1_X);
    draw_paddle(p2_y, P2_COL, P2_X);
    draw_ball(ball.x, ball.y, BALL_COL);
    draw_scores(p1_score, p2_score);
}

fn draw_net() {
    let segment_h: u16 = 20;
    let gap_h: u16 = 20;
    let mut y: u16 = 10;
    let mut count = 0;

    while count < 12 {
        draw_rect(NET_X0, y, NET_X1, y + segment_h - 1, Colour(NET_COL));
        y += segment_h + gap_h;
        count += 1;
    }
}

fn draw_paddle(y: i16, colour: u8, x: i16) {
    let y0 = y.max(0) as u16;
    let y1 = (y + (PADDLE_H as i16) - 1).min((SCREEN_H as i16) - 1) as u16;
    draw_rect(x as u16, y0, (x + (PADDLE_W as i16) - 1) as u16, y1, Colour(colour));
}

fn draw_ball(x: i16, y: i16, colour: u8) {
    fill_circle(x as u16, y as u16, BALL_R, colour);
}

fn draw_scores(p1_score: u8, p2_score: u8) {
    font::erase_digit(P1_SCORE_X, SCORE_Y);
    font::draw_digit(P1_SCORE_X, SCORE_Y, p1_score, BALL_COL);
    font::erase_digit(P2_SCORE_X, SCORE_Y);
    font::draw_digit(P2_SCORE_X, SCORE_Y, p2_score, BALL_COL);
}

fn update_lcd_score(p1_score: u8, p2_score: u8) {
    lcd::print_str(b"\nScore ");
    lcd::print_str(score_digit(p1_score).as_slice());
    lcd::print_str(b"-");
    lcd::print_str(score_digit(p2_score).as_slice());
}

fn score_digit(score: u8) -> [u8; 1] {
    [b'0' + (score % 10)]
}

fn clamp_paddle_y(y: i16) -> i16 {
    let max_y = (SCREEN_H as i16) - (PADDLE_H as i16);
    y.clamp(0, max_y)
}

fn next_score(score: u8) -> u8 {
    if score >= 9 { 0 } else { score + 1 }
}

fn reset_ball(ball: &mut Ball, serve_left: bool, ball_vx: &mut i16, ball_vy: &mut i16) {
    ball.x = (SCREEN_W as i16) / 2;
    ball.y = (SCREEN_H as i16) / 2;
    *ball_vx = if serve_left { -BALL_SPD_X } else { BALL_SPD_X };
    *ball_vy = BALL_SPD_Y;
}