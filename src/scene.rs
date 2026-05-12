use crate::display::{draw_rect, Colour as DisplayColour};
use crate::dsf::{Change, Frame, RectObj as RonRectObj, RonColour, Scene, ID_LEN};

#[derive(Copy, Clone)]
struct RectState {
    id: [u8; ID_LEN],
    x0: u16,
    y0: u16,
    x1: u16,
    y1: u16,
    colour: DisplayColour,
}

impl RectState {
    const fn empty() -> Self {
        Self {
            id: [0; ID_LEN],
            x0: 0,
            y0: 0,
            x1: 0,
            y1: 0,
            colour: DisplayColour::BLACK,
        }
    }

    fn from_obj(rect: &RonRectObj) -> Self {
        Self {
            id: rect.id,
            x0: rect.x0,
            y0: rect.y0,
            x1: rect.x1,
            y1: rect.y1,
            colour: colour_to_display(rect.colour),
        }
    }
}

pub struct SceneState {
    pub background: DisplayColour,
    objects: [RectState; crate::dsf::MAX_OBJECTS],
    object_count: usize,
}

impl SceneState {
    pub fn from_scene(scene: &Scene) -> Self {
        let mut state = Self {
            background: colour_to_display(scene.background),
            objects: [RectState::empty(); crate::dsf::MAX_OBJECTS],
            object_count: 0,
        };

        let mut i = 0;
        while i < scene.object_count && i < crate::dsf::MAX_OBJECTS {
            state.objects[i] = RectState::from_obj(&scene.objects[i]);
            i += 1;
        }
        state.object_count = i;
        state
    }

    pub fn draw_all(&self) {
        let mut i = 0;
        while i < self.object_count {
            let obj = &self.objects[i];
            draw_rect(obj.x0, obj.y0, obj.x1, obj.y1, obj.colour);
            i += 1;
        }
    }

    pub fn apply_frame(&mut self, frame: &Frame) {
        let mut i = 0;
        while i < frame.change_count {
            match frame.changes[i] {
                Change::Move { id, dx, dy } => self.apply_move(&id, dx, dy),
                Change::None => {}
            }
            i += 1;
        }
    }

    fn apply_move(&mut self, id: &[u8; ID_LEN], dx: i16, dy: i16) {
        if let Some(index) = self.find_index(id) {
            let obj = &mut self.objects[index];
            draw_rect(obj.x0, obj.y0, obj.x1, obj.y1, self.background);
            obj.x0 = add_delta(obj.x0, dx);
            obj.y0 = add_delta(obj.y0, dy);
            obj.x1 = add_delta(obj.x1, dx);
            obj.y1 = add_delta(obj.y1, dy);
            draw_rect(obj.x0, obj.y0, obj.x1, obj.y1, obj.colour);
        }
    }

    fn find_index(&self, id: &[u8; ID_LEN]) -> Option<usize> {
        let mut i = 0;
        while i < self.object_count {
            if self.objects[i].id == *id {
                return Some(i);
            }
            i += 1;
        }
        None
    }
}

fn add_delta(value: u16, delta: i16) -> u16 {
    let next = value as i32 + delta as i32;
    if next < 0 {
        0
    } else if next > u16::MAX as i32 {
        u16::MAX
    } else {
        next as u16
    }
}

fn colour_to_display(colour: RonColour) -> DisplayColour {
    DisplayColour::rgb(colour.r, colour.g, colour.b)
}
