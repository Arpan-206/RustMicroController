// This file was under-progress but I ran out of time to include it

use crate::display::{draw_line, draw_rect, fill_circle, fill_rect, fill_triangle, Colour};
use crate::generated_scene::{self, Kf};
use crate::{io, syscall};

#[derive(Copy, Clone)]
struct Shape {
    x0: u16,
    y0: u16,
    x1: u16,
    y1: u16,
    x2: u16,
    y2: u16,
}

impl Shape {
    const fn empty() -> Self {
        Self {
            x0: 0,
            y0: 0,
            x1: 0,
            y1: 0,
            x2: 0,
            y2: 0,
        }
    }

    fn draw(self, kind: u8, colour: u8) {
        if kind == generated_scene::KIND_RECT {
            draw_rect(self.x0, self.y0, self.x1, self.y1, Colour(colour));
        } else if kind == generated_scene::KIND_TRIANGLE {
            fill_triangle(self.x0, self.y0, self.x1, self.y1, self.x2, self.y2, colour);
        } else if kind == generated_scene::KIND_CIRCLE {
            fill_circle(self.x0, self.y0, self.x1, colour);
        } else if kind == generated_scene::KIND_LINE {
            draw_line(self.x0, self.y0, self.x1, self.y1, self.x2, Colour(colour));
        }
    }

    fn eq(self, other: Shape) -> bool {
        self.x0 == other.x0
            && self.y0 == other.y0
            && self.x1 == other.x1
            && self.y1 == other.y1
            && self.x2 == other.x2
            && self.y2 == other.y2
    }

    fn erase(self, kind: u8, bg: u8) {
        if kind == generated_scene::KIND_CIRCLE {
            let r = self.x1;
            fill_rect(
                self.x0.saturating_sub(r),
                self.y0.saturating_sub(r),
                self.x0.saturating_add(r),
                self.y0.saturating_add(r),
                Colour(bg),
            );
        } else {
            self.draw(kind, bg);
        }
    }
}

pub fn run() -> ! {
    let background = Colour(generated_scene::BG);
    let mut previous = [Shape::empty(); generated_scene::OBJECT_COUNT];
    let mut next = [Shape::empty(); generated_scene::OBJECT_COUNT];

    // Draw background and initial frame
    draw_rect(0, 0, 639, 479, background);

    let mut i = 0;
    while i < generated_scene::OBJECT_COUNT {
        let object = generated_scene::OBJECTS[i];
        previous[i] = shape_at(object.keyframes, 0);
        previous[i].draw(object.kind, object.colour);
        i += 1;
    }

    io::timer_start(io::TIMER_1MS);
    syscall::counter_clr();

    let mut ticks_per_frame = 1000 / generated_scene::FPS;
    if ticks_per_frame == 0 {
        ticks_per_frame = 1;
    }

    let mut frame = next_frame(0);

    loop {
        let start = syscall::counter_get();

        // Compute next shapes
        i = 0;
        while i < generated_scene::OBJECT_COUNT {
            next[i] = shape_at(generated_scene::OBJECTS[i].keyframes, frame);
            i += 1;
        }

        // Pass 1: erase only shapes that changed (back-to-front order preserves Z)
        i = 0;
        while i < generated_scene::OBJECT_COUNT {
            if !previous[i].eq(next[i]) {
                previous[i].erase(generated_scene::OBJECTS[i].kind, background.0);
            }
            i += 1;
        }

        // Pass 2: redraw only shapes that changed
        i = 0;
        while i < generated_scene::OBJECT_COUNT {
            if !previous[i].eq(next[i]) {
                next[i].draw(
                    generated_scene::OBJECTS[i].kind,
                    generated_scene::OBJECTS[i].colour,
                );
            }
            previous[i] = next[i];
            i += 1;
        }

        frame = next_frame(frame);

        while syscall::counter_get().wrapping_sub(start) < ticks_per_frame {}
    }
}

fn next_frame(frame: u16) -> u16 {
    if frame >= generated_scene::LAST_FRAME {
        0
    } else {
        frame + 1
    }
}

fn shape_at(keyframes: &[Kf], frame: u16) -> Shape {
    if keyframes.is_empty() {
        return Shape::empty();
    }

    if frame <= keyframes[0].frame {
        return shape_from_kf(&keyframes[0]);
    }

    let mut i = 0;
    while i + 1 < keyframes.len() {
        let a = keyframes[i];
        let b = keyframes[i + 1];
        if frame <= b.frame {
            let t_num = frame - a.frame;
            let t_den = b.frame - a.frame;
            return Shape {
                x0: lerp(a.x0, b.x0, t_num, t_den),
                y0: lerp(a.y0, b.y0, t_num, t_den),
                x1: lerp(a.x1, b.x1, t_num, t_den),
                y1: lerp(a.y1, b.y1, t_num, t_den),
                x2: lerp(a.x2, b.x2, t_num, t_den),
                y2: lerp(a.y2, b.y2, t_num, t_den),
            };
        }
        i += 1;
    }

    shape_from_kf(&keyframes[keyframes.len() - 1])
}

fn shape_from_kf(kf: &Kf) -> Shape {
    Shape {
        x0: kf.x0,
        y0: kf.y0,
        x1: kf.x1,
        y1: kf.y1,
        x2: kf.x2,
        y2: kf.y2,
    }
}

/// Smoothstep easing: 3t² - 2t³, then lerp.
/// All arithmetic in i64 to avoid overflow and truncation jitter.
fn lerp(a: u16, b: u16, t_num: u16, t_den: u16) -> u16 {
    if t_den == 0 {
        return a;
    }
    let a = a as i64;
    let b = b as i64;
    let result = a * t_den as i64 + (b - a) * t_num as i64;
    (result / t_den as i64).clamp(0, 65535) as u16
}
