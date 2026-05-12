#![allow(dead_code)]

pub const MAX_OBJECTS: usize = 8;
pub const MAX_FRAMES: usize = 64;
pub const MAX_MOVES_PER_FRAME: usize = 4;
pub const MAX_ID_LEN: usize = 8;

#[derive(Copy, Clone)]
pub struct Id {
    bytes: [u8; MAX_ID_LEN],
    len: u8,
}

impl Id {
    pub const fn empty() -> Self {
        Self {
            bytes: [0; MAX_ID_LEN],
            len: 0,
        }
    }

    pub const fn from_bytes(bytes: [u8; MAX_ID_LEN], len: u8) -> Self {
        Self { bytes, len }
    }

    pub fn equals(&self, other: &Id) -> bool {
        if self.len != other.len {
            return false;
        }
        let mut i = 0;
        while i < self.len as usize {
            if self.bytes[i] != other.bytes[i] {
                return false;
            }
            i += 1;
        }
        true
    }
}

#[derive(Copy, Clone)]
pub struct Colour {
    pub r: u8,
    pub g: u8,
    pub b: u8,
}

impl Colour {
    pub const fn black() -> Self {
        Self { r: 0, g: 0, b: 0 }
    }
}

#[derive(Copy, Clone)]
pub struct RectDef {
    pub id: Id,
    pub x0: u16,
    pub y0: u16,
    pub x1: u16,
    pub y1: u16,
    pub colour: Colour,
}

impl RectDef {
    pub const fn empty() -> Self {
        Self {
            id: Id::empty(),
            x0: 0,
            y0: 0,
            x1: 0,
            y1: 0,
            colour: Colour::black(),
        }
    }
}

#[derive(Copy, Clone)]
pub struct Move {
    pub id: Id,
    pub x0: u16,
    pub y0: u16,
    pub x1: u16,
    pub y1: u16,
}

impl Move {
    pub const fn empty() -> Self {
        Self {
            id: Id::empty(),
            x0: 0,
            y0: 0,
            x1: 0,
            y1: 0,
        }
    }
}

#[derive(Copy, Clone)]
pub struct Frame {
    pub moves: [Move; MAX_MOVES_PER_FRAME],
    pub move_count: usize,
}

impl Frame {
    pub const fn empty() -> Self {
        Self {
            moves: [Move::empty(); MAX_MOVES_PER_FRAME],
            move_count: 0,
        }
    }

    pub fn push_move(&mut self, mv: Move) {
        if self.move_count < MAX_MOVES_PER_FRAME {
            self.moves[self.move_count] = mv;
            self.move_count += 1;
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
    pub background: Colour,
    pub rects: [RectDef; MAX_OBJECTS],
    pub rect_count: usize,
    pub timeline: Timeline,
}

impl Scene {
    pub const fn empty() -> Self {
        Self {
            background: Colour::black(),
            rects: [RectDef::empty(); MAX_OBJECTS],
            rect_count: 0,
            timeline: Timeline::empty(),
        }
    }

    pub fn push_rect(&mut self, rect: RectDef) {
        if self.rect_count < MAX_OBJECTS {
            self.rects[self.rect_count] = rect;
            self.rect_count += 1;
        }
    }
}
