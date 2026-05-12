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
    Kf { frame: 19, x0: 110, y0: 235, x1: 120, y1: 245 },
];

pub const OBJ_RISE_COLOUR: u8 = 0x1E;
pub const OBJ_RISE_KF: &[Kf] = &[
    Kf { frame: 0, x0: 300, y0: 400, x1: 318, y1: 418 },
    Kf { frame: 19, x0: 300, y0: 300, x1: 318, y1: 318 },
];

pub const OBJ_DROP_COLOUR: u8 = 0xE5;
pub const OBJ_DROP_KF: &[Kf] = &[
    Kf { frame: 0, x0: 560, y0: 80, x1: 578, y1: 98 },
    Kf { frame: 19, x0: 460, y0: 180, x1: 478, y1: 198 },
];

pub const OBJECT_COUNT: usize = 3;
pub const LAST_FRAME: u16 = 19;
pub const OBJECTS: &[Obj] = &[
    Obj { colour: OBJ_SQ_COLOUR, keyframes: OBJ_SQ_KF },
    Obj { colour: OBJ_RISE_COLOUR, keyframes: OBJ_RISE_KF },
    Obj { colour: OBJ_DROP_COLOUR, keyframes: OBJ_DROP_KF },
];
