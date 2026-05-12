// generated - do not edit

pub const FPS: u32 = 20;
pub const BG: u8 = 0x00;

#[derive(Copy, Clone)]
pub struct Kf {
    pub frame: u16,
    pub x0: u16,
    pub y0: u16,
    pub x1: u16,
    pub y1: u16,
    pub x2: u16,
    pub y2: u16,
}

pub const KIND_RECT: u8 = 0;
pub const KIND_TRIANGLE: u8 = 1;
pub const KIND_CIRCLE: u8 = 2;

#[derive(Copy, Clone)]
pub struct Obj {
    pub kind: u8,
    pub colour: u8,
    pub keyframes: &'static [Kf],
}

pub const OBJ_SQ_COLOUR: u8 = 0xFF;
pub const OBJ_SQ_KF: &[Kf] = &[
    Kf {
        frame: 0,
        x0: 10,
        y0: 235,
        x1: 20,
        y1: 245,
        x2: 0,
        y2: 0,
    },
    Kf {
        frame: 29,
        x0: 110,
        y0: 408,
        x1: 120,
        y1: 418,
        x2: 0,
        y2: 0,
    },
];

pub const OBJ_TRI_COLOUR: u8 = 0xE2;
pub const OBJ_TRI_KF: &[Kf] = &[
    Kf {
        frame: 0,
        x0: 500,
        y0: 80,
        x1: 540,
        y1: 120,
        x2: 460,
        y2: 125,
    },
    Kf {
        frame: 29,
        x0: 390,
        y0: 120,
        x1: 430,
        y1: 165,
        x2: 350,
        y2: 165,
    },
];

pub const OBJ_SUN_COLOUR: u8 = 0x1B;
pub const OBJ_SUN_KF: &[Kf] = &[
    Kf {
        frame: 0,
        x0: 150,
        y0: 90,
        x1: 18,
        y1: 0,
        x2: 0,
        y2: 0,
    },
    Kf {
        frame: 29,
        x0: 520,
        y0: 330,
        x1: 34,
        y1: 0,
        x2: 0,
        y2: 0,
    },
];

pub const OBJECT_COUNT: usize = 3;
pub const LAST_FRAME: u16 = 29;
pub const OBJECTS: &[Obj] = &[
    Obj {
        kind: KIND_RECT,
        colour: OBJ_SQ_COLOUR,
        keyframes: OBJ_SQ_KF,
    },
    Obj {
        kind: KIND_TRIANGLE,
        colour: OBJ_TRI_COLOUR,
        keyframes: OBJ_TRI_KF,
    },
    Obj {
        kind: KIND_CIRCLE,
        colour: OBJ_SUN_COLOUR,
        keyframes: OBJ_SUN_KF,
    },
];
