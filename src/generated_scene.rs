// generated - do not edit

pub const FPS: u32 = 10;
pub const BG: u8 = 0x00;

#[derive(Copy, Clone)]
pub struct Kf {
    pub frame: u16,
    pub x0: u16,
    pub y0: u16,
    pub x1: u16,
    pub y1: u16,
}

#[derive(Copy, Clone)]
pub struct Obj {
    pub colour: u8,
    pub keyframes: &'static [Kf],
}

pub const OBJ_SQ_COLOUR: u8 = 0xFF;
pub const OBJ_SQ_KF: &[Kf] = &[
    Kf { frame: 0, x0: 10, y0: 235, x1: 20, y1: 245 },
    Kf { frame: 19, x0: 110, y0: 235, x1: 120, y1: 150 },
];

pub const OBJECT_COUNT: usize = 1;
pub const LAST_FRAME: u16 = 19;
pub const OBJECTS: &[Obj] = &[
    Obj { colour: OBJ_SQ_COLOUR, keyframes: OBJ_SQ_KF },
];
