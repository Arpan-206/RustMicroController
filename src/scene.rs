use crate::display::{draw_rect, Colour as DisplayColour};
use crate::dsf::{Colour, Frame, Id, RectDef, Scene};

#[derive(Copy, Clone)]
struct RectObj {
    id: Id,
    x0: u16,
    y0: u16,
    x1: u16,
    y1: u16,
    colour: DisplayColour,
}

impl RectObj {
    const fn empty() -> Self {
        Self {
            id: Id::empty(),
            x0: 0,
            y0: 0,
            x1: 0,
            y1: 0,
            colour: DisplayColour::BLACK,
        }
    }

    fn from_def(rect: &RectDef) -> Self {
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
    objects: [RectObj; crate::dsf::MAX_OBJECTS],
    object_count: usize,
}

impl SceneState {
    pub fn from_scene(scene: &Scene) -> Self {
        let mut state = Self {
            background: colour_to_display(scene.background),
            objects: [RectObj::empty(); crate::dsf::MAX_OBJECTS],
            object_count: 0,
        };

        let mut i = 0;
        while i < scene.rect_count && i < crate::dsf::MAX_OBJECTS {
            state.objects[i] = RectObj::from_def(&scene.rects[i]);
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
        while i < frame.move_count {
            let mv = frame.moves[i];
            self.apply_move(&mv);
            i += 1;
        }
    }

    fn apply_move(&mut self, mv: &crate::dsf::Move) {
        if let Some(index) = self.find_index(&mv.id) {
            let obj = &mut self.objects[index];
            draw_rect(obj.x0, obj.y0, obj.x1, obj.y1, self.background);
            obj.x0 = mv.x0;
            obj.y0 = mv.y0;
            obj.x1 = mv.x1;
            obj.y1 = mv.y1;
            draw_rect(obj.x0, obj.y0, obj.x1, obj.y1, obj.colour);
        }
    }

    fn find_index(&self, id: &Id) -> Option<usize> {
        let mut i = 0;
        while i < self.object_count {
            if self.objects[i].id.equals(id) {
                return Some(i);
            }
            i += 1;
        }
        None
    }
}

fn colour_to_display(colour: Colour) -> DisplayColour {
    DisplayColour::rgb(colour.r, colour.g, colour.b)
}
