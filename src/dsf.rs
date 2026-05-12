#![allow(dead_code)]

pub const MAX_OBJECTS: usize = 32;
pub const MAX_FRAMES: usize = 64; // logical frames after repeat expansion
pub const MAX_CHANGES: usize = 8;
pub const ID_LEN: usize = 16;

#[derive(Copy, Clone)]
pub struct RonColour {
    pub r: u8,
    pub g: u8,
    pub b: u8,
}

impl RonColour {
    pub const fn black() -> Self {
        Self { r: 0, g: 0, b: 0 }
    }
}

#[derive(Copy, Clone)]
pub struct RectObj {
    pub id: [u8; ID_LEN],
    pub x0: u16,
    pub y0: u16,
    pub x1: u16,
    pub y1: u16,
    pub colour: RonColour,
}

impl RectObj {
    pub const fn empty() -> Self {
        Self {
            id: [0; ID_LEN],
            x0: 0,
            y0: 0,
            x1: 0,
            y1: 0,
            colour: RonColour::black(),
        }
    }
}

#[derive(Copy, Clone)]
pub enum Change {
    Move { id: [u8; ID_LEN], dx: i16, dy: i16 },
    None,
}

impl Change {
    pub const fn none() -> Self {
        Change::None
    }
}

#[derive(Copy, Clone)]
pub struct Frame {
    pub changes: [Change; MAX_CHANGES],
    pub change_count: usize,
}

impl Frame {
    pub const fn empty() -> Self {
        Self {
            changes: [Change::None; MAX_CHANGES],
            change_count: 0,
        }
    }

    pub fn push_change(&mut self, change: Change) {
        if self.change_count < MAX_CHANGES {
            self.changes[self.change_count] = change;
            self.change_count += 1;
        }
    }
}

#[derive(Copy, Clone)]
pub struct Timeline {
    pub fps: u32,
    pub frames: [Frame; MAX_FRAMES],
    pub frame_count: usize,
}

impl Timeline {
    pub const fn empty() -> Self {
        Self {
            fps: 1,
            frames: [Frame::empty(); MAX_FRAMES],
            frame_count: 0,
        }
    }

    pub fn push_frame(&mut self, frame: Frame) {
        if self.frame_count < MAX_FRAMES {
            self.frames[self.frame_count] = frame;
            self.frame_count += 1;
        }
    }
}

pub struct Scene {
    pub background: RonColour,
    pub objects: [RectObj; MAX_OBJECTS],
    pub object_count: usize,
    pub timeline: Timeline,
}

impl Scene {
    pub const fn empty() -> Self {
        Self {
            background: RonColour::black(),
            objects: [RectObj::empty(); MAX_OBJECTS],
            object_count: 0,
            timeline: Timeline::empty(),
        }
    }

    pub fn push_object(&mut self, obj: RectObj) {
        if self.object_count < MAX_OBJECTS {
            self.objects[self.object_count] = obj;
            self.object_count += 1;
        }
    }
}
