use crate::display::{draw_rect, fill_circle, Colour};
use crate::lcd;
use crate::{font, io, keyboard, syscall};

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
const TITLE_SCALE: u16 = 8;
const SUBTITLE_SCALE: u16 = 3;
const START_SUBTITLE: &[u8] = b"PRESS 1 TO START";
const WIN_P1_SUBTITLE: &[u8] = b"P1 WINS";
const WIN_P2_SUBTITLE: &[u8] = b"P2 WINS";

const P1_X: i16 = 20;
const P2_X: i16 = (SCREEN_W as i16) - 20 - (PADDLE_W as i16);
const NET_X0: u16 = (SCREEN_W / 2) - 2;
const NET_X1: u16 = (SCREEN_W / 2) + 1;

#[derive(Copy, Clone)]
struct Ball {
    x: i16,
    y: i16,
}

#[derive(Copy, Clone)]
struct GameState {
    p1_y: i16,
    p2_y: i16,
    ball: Ball,
    ball_vx: i16,
    ball_vy: i16,
    p1_score: u8,
    p2_score: u8,
    serve_left: bool,
    p1_dir: i16,
    p2_dir: i16,
    p1_repeat: u8,
    p2_repeat: u8,
}

#[derive(Copy, Clone)]
enum SplashKind {
    Start,
    Winner { subtitle: &'static [u8], colour: u8 },
}

#[derive(Copy, Clone)]
enum Mode {
    Splash(SplashKind),
    Playing,
}

impl GameState {
    fn new() -> Self {
        let mut state = Self {
            p1_y: 0,
            p2_y: 0,
            ball: Ball { x: 0, y: 0 },
            ball_vx: BALL_SPD_X,
            ball_vy: BALL_SPD_Y,
            p1_score: 0,
            p2_score: 0,
            serve_left: false,
            p1_dir: 0,
            p2_dir: 0,
            p1_repeat: 0,
            p2_repeat: 0,
        };
        state.reset_round();
        state
    }

    fn reset_round(&mut self) {
        self.p1_y = ((SCREEN_H as i16) - (PADDLE_H as i16)) / 2;
        self.p2_y = self.p1_y;
        self.ball = Ball {
            x: (SCREEN_W as i16) / 2,
            y: (SCREEN_H as i16) / 2,
        };
        self.ball_vx = BALL_SPD_X;
        self.ball_vy = BALL_SPD_Y;
        self.p1_score = 0;
        self.p2_score = 0;
        self.serve_left = false;
        self.p1_dir = 0;
        self.p2_dir = 0;
        self.p1_repeat = 0;
        self.p2_repeat = 0;
    }
}

pub fn run() -> ! {
    io::timer_start(io::TIMER_1MS);
    syscall::counter_clr();

    let mut ticks_per_frame = 1000 / FPS;
    if ticks_per_frame == 0 {
        ticks_per_frame = 1;
    }

    let mut mode = Mode::Splash(SplashKind::Start);
    let mut splash_dirty = true;
    let mut game = GameState::new();

    loop {
        let start = syscall::counter_get();

        match mode {
            Mode::Splash(kind) => {
                if splash_dirty {
                    show_splash(kind);
                    splash_dirty = false;
                }

                while let Some(key) = keyboard::read_key_nonblocking() {
                    match key {
                        b'1' => {
                            game.reset_round();
                            mode = Mode::Playing;
                            splash_dirty = true;
                            break;
                        }
                        b'0' => {
                            game.reset_round();
                            mode = Mode::Splash(SplashKind::Start);
                            splash_dirty = true;
                            break;
                        }
                        _ => {}
                    }
                }
            }
            Mode::Playing => {
                if let Some(next_splash) = handle_play_input(&mut game) {
                    game.reset_round();
                    mode = Mode::Splash(next_splash);
                    splash_dirty = true;
                } else if let Some(next_splash) = update_and_render_game(&mut game) {
                    game.reset_round();
                    mode = Mode::Splash(next_splash);
                    splash_dirty = true;
                }
            }
        }

        while syscall::counter_get().wrapping_sub(start) < ticks_per_frame {}
    }
}

fn show_splash(kind: SplashKind) {
    draw_rect(0, 0, SCREEN_W - 1, SCREEN_H - 1, Colour(BG));
    lcd::clear();

    let title = b"PONG";
    let title_w = font::char_width(TITLE_SCALE) * title.len() as u16;
    let title_h = font::char_height(TITLE_SCALE);
    let title_x = (SCREEN_W - title_w) / 2;
    let title_y = (SCREEN_H - title_h) / 2 - 20;

    font::draw_str(title_x, title_y, title, BALL_COL, TITLE_SCALE);

    let (subtitle_src, subtitle_colour) = match kind {
        SplashKind::Start => (START_SUBTITLE, BALL_COL),
        SplashKind::Winner { subtitle, colour } => (subtitle, colour),
    };

    let subtitle_w = font::char_width(SUBTITLE_SCALE) * subtitle_src.len() as u16;
    let subtitle_x = (SCREEN_W - subtitle_w) / 2;
    let subtitle_y = title_y + title_h + 18;

    font::draw_str(subtitle_x, subtitle_y, subtitle_src, subtitle_colour, SUBTITLE_SCALE);
    lcd::print_str(subtitle_src);
}

fn handle_play_input(game: &mut GameState) -> Option<SplashKind> {
    while let Some(raw) = keyboard::read_raw_key_nonblocking() {
        // Debug: print raw keycode and ASCII translation to LCD
        if let Some(ascii) = keyboard::keycode_to_ascii_pub(raw) {
            let hex = b"0123456789ABCDEF";
            let hi = hex[((raw >> 4) & 0x0f) as usize];
            let lo = hex[(raw & 0x0f) as usize];
            lcd::print_str(b"\n");
            lcd::print_str(&[hi, lo, b':', ascii]);
        } else {
            let hex = b"0123456789ABCDEF";
            let hi = hex[((raw >> 4) & 0x0f) as usize];
            let lo = hex[(raw & 0x0f) as usize];
            lcd::print_str(b"\n");
            lcd::print_str(&[hi, lo, b':', b'?']);
        }

        let key = keyboard::keycode_to_ascii_pub(raw);
        if let Some(key) = key {
            match key {
            b'0' => return Some(SplashKind::Start),
            b'1' => {
                game.p1_dir = -1;
                game.p1_repeat = INPUT_REPEAT_FRAMES;
            }
            b'7' | b'4' => {
                game.p1_dir = 1;
                game.p1_repeat = INPUT_REPEAT_FRAMES;
            }
            b'3' => {
                game.p2_dir = -1;
                game.p2_repeat = INPUT_REPEAT_FRAMES;
            }
            b'9' | b'6' => {
                game.p2_dir = 1;
                game.p2_repeat = INPUT_REPEAT_FRAMES;
            }
            _ => {}
            }
        }
    }

    None
}

fn update_and_render_game(game: &mut GameState) -> Option<SplashKind> {
    let old_p1_y = game.p1_y;
    let old_p2_y = game.p2_y;
    let old_ball = game.ball;

    if game.p1_repeat > 0 && game.p1_dir != 0 {
        game.p1_y += game.p1_dir * PADDLE_SPD;
        game.p1_repeat -= 1;
    }

    if game.p2_repeat > 0 && game.p2_dir != 0 {
        game.p2_y += game.p2_dir * PADDLE_SPD;
        game.p2_repeat -= 1;
    }

    game.p1_y = clamp_paddle_y(game.p1_y);
    game.p2_y = clamp_paddle_y(game.p2_y);

    game.ball.x += game.ball_vx;
    game.ball.y += game.ball_vy;

    if game.ball.y - (BALL_R as i16) <= 0 {
        game.ball.y = BALL_R as i16;
        game.ball_vy = -game.ball_vy;
    } else if game.ball.y + (BALL_R as i16) >= (SCREEN_H as i16) - 1 {
        game.ball.y = (SCREEN_H as i16) - 1 - (BALL_R as i16);
        game.ball_vy = -game.ball_vy;
    }

    let p1_bottom = game.p1_y + (PADDLE_H as i16);
    let p2_bottom = game.p2_y + (PADDLE_H as i16);
    let ball_top = game.ball.y - (BALL_R as i16);
    let ball_bottom = game.ball.y + (BALL_R as i16);

    if game.ball_vx < 0
        && game.ball.x - (BALL_R as i16) <= P1_X + (PADDLE_W as i16)
        && ball_bottom >= game.p1_y
        && ball_top <= p1_bottom
        && game.ball.x >= P1_X
    {
        game.ball.x = P1_X + (PADDLE_W as i16) + (BALL_R as i16) + 1;
        game.ball_vx = -(game.ball_vx - 1);
    } else if game.ball_vx > 0
        && game.ball.x + (BALL_R as i16) >= P2_X
        && ball_bottom >= game.p2_y
        && ball_top <= p2_bottom
        && game.ball.x <= P2_X + (PADDLE_W as i16)
    {
        game.ball.x = P2_X - (BALL_R as i16) - 1;
        game.ball_vx = -(game.ball_vx + 1);
    }

    if game.ball.x < 0 {
        game.p2_score = game.p2_score.saturating_add(1);
        if game.p2_score >= 9 {
            show_splash(SplashKind::Winner {
                subtitle: WIN_P2_SUBTITLE,
                colour: P2_COL,
            });
            return Some(SplashKind::Winner {
                subtitle: WIN_P2_SUBTITLE,
                colour: P2_COL,
            });
        }

        game.serve_left = !game.serve_left;
        reset_ball(
            &mut game.ball,
            game.serve_left,
            &mut game.ball_vx,
            &mut game.ball_vy,
        );
        clear_and_draw_world(
            game.p1_y,
            game.p2_y,
            game.ball,
            game.p1_score,
            game.p2_score,
        );
        update_lcd_score(game.p1_score, game.p2_score);
        return None;
    } else if game.ball.x > SCREEN_W as i16 {
        game.p1_score = game.p1_score.saturating_add(1);
        if game.p1_score >= 9 {
            show_splash(SplashKind::Winner {
                subtitle: WIN_P1_SUBTITLE,
                colour: P1_COL,
            });
            return Some(SplashKind::Winner {
                subtitle: WIN_P1_SUBTITLE,
                colour: P1_COL,
            });
        }

        game.serve_left = !game.serve_left;
        reset_ball(
            &mut game.ball,
            game.serve_left,
            &mut game.ball_vx,
            &mut game.ball_vy,
        );
        clear_and_draw_world(
            game.p1_y,
            game.p2_y,
            game.ball,
            game.p1_score,
            game.p2_score,
        );
        update_lcd_score(game.p1_score, game.p2_score);
        return None;
    }

    draw_paddle(old_p1_y, BG, P1_X);
    draw_paddle(old_p2_y, BG, P2_X);
    draw_ball(old_ball.x, old_ball.y, BG);

    draw_paddle(game.p1_y, P1_COL, P1_X);
    draw_paddle(game.p2_y, P2_COL, P2_X);
    draw_ball(game.ball.x, game.ball.y, BALL_COL);

    None
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
    for _ in 0..12 {
        draw_rect(NET_X0, y, NET_X1, y + segment_h - 1, Colour(NET_COL));
        y += segment_h + gap_h;
    }
}

fn draw_paddle(y: i16, colour: u8, x: i16) {
    let y0 = y.max(0) as u16;
    let y1 = (y + (PADDLE_H as i16) - 1).min((SCREEN_H as i16) - 1) as u16;
    draw_rect(
        x as u16,
        y0,
        (x + (PADDLE_W as i16) - 1) as u16,
        y1,
        Colour(colour),
    );
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
    lcd::print_str(b"\n                           ");
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

fn reset_ball(ball: &mut Ball, serve_left: bool, ball_vx: &mut i16, ball_vy: &mut i16) {
    ball.x = (SCREEN_W as i16) / 2;
    ball.y = (SCREEN_H as i16) / 2;
    *ball_vx = if serve_left { -BALL_SPD_X } else { BALL_SPD_X };
    *ball_vy = BALL_SPD_Y;
}
