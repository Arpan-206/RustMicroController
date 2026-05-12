use crate::display::{draw_rect, fill_circle, fill_triangle, Colour};
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
        }
    }
}

pub fn run() -> ! {
    let background = Colour(generated_scene::BG);
    let mut previous = [Shape::empty(); generated_scene::OBJECT_COUNT];
    let mut next = [Shape::empty(); generated_scene::OBJECT_COUNT];

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

        i = 0;
        while i < generated_scene::OBJECT_COUNT {
            next[i] = shape_at(generated_scene::OBJECTS[i].keyframes, frame);
            i += 1;
        }

        i = 0;
        while i < generated_scene::OBJECT_COUNT {
            previous[i].draw(generated_scene::OBJECTS[i].kind, background.0);
            i += 1;
        }

        i = 0;
        while i < generated_scene::OBJECT_COUNT {
            next[i].draw(
                generated_scene::OBJECTS[i].kind,
                generated_scene::OBJECTS[i].colour,
            );
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

fn shape_from_kf(keyframe: &Kf) -> Shape {
    Shape {
        x0: keyframe.x0,
        y0: keyframe.y0,
        x1: keyframe.x1,
        y1: keyframe.y1,
        x2: keyframe.x2,
        y2: keyframe.y2,
    }
}

fn lerp(a: u16, b: u16, t_num: u16, t_den: u16) -> u16 {
    if t_den == 0 {
        return a;
    }

    let a = a as i32;
    let b = b as i32;
    (a + (b - a) * t_num as i32 / t_den as i32) as u16
}
