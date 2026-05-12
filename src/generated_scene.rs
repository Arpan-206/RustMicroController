// generated - do not edit

pub const FPS: u32 = 30;
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

pub const KIND_LINE: u8 = 3;

#[derive(Copy, Clone)]
pub struct Obj {
    pub kind: u8,
    pub colour: u8,
    pub keyframes: &'static [Kf],
}

pub const OBJ_SKY_COLOUR: u8 = 0x62;
pub const OBJ_SKY_KF: &[Kf] = &[
    Kf { frame: 0, x0: 0, y0: 0, x1: 639, y1: 270, x2: 0, y2: 0 },
    Kf { frame: 299, x0: 0, y0: 0, x1: 639, y1: 270, x2: 0, y2: 0 },
];

pub const OBJ_GROUND_COLOUR: u8 = 0x09;
pub const OBJ_GROUND_KF: &[Kf] = &[
    Kf { frame: 0, x0: 0, y0: 270, x1: 639, y1: 479, x2: 0, y2: 0 },
    Kf { frame: 299, x0: 0, y0: 270, x1: 639, y1: 479, x2: 0, y2: 0 },
];

pub const OBJ_SUN_COLOUR: u8 = 0xF4;
pub const OBJ_SUN_KF: &[Kf] = &[
    Kf { frame: 0, x0: 320, y0: 360, x1: 30, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 299, x0: 320, y0: 270, x1: 90, y1: 0, x2: 0, y2: 0 },
];

pub const OBJ_ML_COLOUR: u8 = 0x21;
pub const OBJ_ML_KF: &[Kf] = &[
    Kf { frame: 0, x0: 0, y0: 270, x1: 180, y1: 270, x2: 80, y2: 170 },
    Kf { frame: 299, x0: 0, y0: 270, x1: 180, y1: 270, x2: 80, y2: 170 },
];

pub const OBJ_MR_COLOUR: u8 = 0x21;
pub const OBJ_MR_KF: &[Kf] = &[
    Kf { frame: 0, x0: 460, y0: 270, x1: 639, y1: 270, x2: 550, y2: 155 },
    Kf { frame: 299, x0: 460, y0: 270, x1: 639, y1: 270, x2: 550, y2: 155 },
];

pub const OBJ_GH0_COLOUR: u8 = 0x1F;
pub const OBJ_GH0_KF: &[Kf] = &[
    Kf { frame: 0, x0: 0, y0: 340, x1: 639, y1: 340, x2: 1, y2: 0 },
    Kf { frame: 299, x0: 0, y0: 340, x1: 639, y1: 340, x2: 1, y2: 0 },
];

pub const OBJ_GH1_COLOUR: u8 = 0x1F;
pub const OBJ_GH1_KF: &[Kf] = &[
    Kf { frame: 0, x0: 0, y0: 410, x1: 639, y1: 410, x2: 1, y2: 0 },
    Kf { frame: 299, x0: 0, y0: 410, x1: 639, y1: 410, x2: 1, y2: 0 },
];

pub const OBJ_GV0_COLOUR: u8 = 0x1F;
pub const OBJ_GV0_KF: &[Kf] = &[
    Kf { frame: 0, x0: 320, y0: 270, x1: 160, y1: 479, x2: 1, y2: 0 },
    Kf { frame: 299, x0: 320, y0: 270, x1: 160, y1: 479, x2: 1, y2: 0 },
];

pub const OBJ_GV1_COLOUR: u8 = 0x1F;
pub const OBJ_GV1_KF: &[Kf] = &[
    Kf { frame: 0, x0: 320, y0: 270, x1: 320, y1: 479, x2: 1, y2: 0 },
    Kf { frame: 299, x0: 320, y0: 270, x1: 320, y1: 479, x2: 1, y2: 0 },
];

pub const OBJ_GV2_COLOUR: u8 = 0x1F;
pub const OBJ_GV2_KF: &[Kf] = &[
    Kf { frame: 0, x0: 320, y0: 270, x1: 480, y1: 479, x2: 1, y2: 0 },
    Kf { frame: 299, x0: 320, y0: 270, x1: 480, y1: 479, x2: 1, y2: 0 },
];

pub const OBJECT_COUNT: usize = 10;
pub const LAST_FRAME: u16 = 299;
pub const OBJECTS: &[Obj] = &[
    Obj { kind: KIND_RECT, colour: OBJ_SKY_COLOUR, keyframes: OBJ_SKY_KF },
    Obj { kind: KIND_RECT, colour: OBJ_GROUND_COLOUR, keyframes: OBJ_GROUND_KF },
    Obj { kind: KIND_CIRCLE, colour: OBJ_SUN_COLOUR, keyframes: OBJ_SUN_KF },
    Obj { kind: KIND_TRIANGLE, colour: OBJ_ML_COLOUR, keyframes: OBJ_ML_KF },
    Obj { kind: KIND_TRIANGLE, colour: OBJ_MR_COLOUR, keyframes: OBJ_MR_KF },
    Obj { kind: KIND_LINE, colour: OBJ_GH0_COLOUR, keyframes: OBJ_GH0_KF },
    Obj { kind: KIND_LINE, colour: OBJ_GH1_COLOUR, keyframes: OBJ_GH1_KF },
    Obj { kind: KIND_LINE, colour: OBJ_GV0_COLOUR, keyframes: OBJ_GV0_KF },
    Obj { kind: KIND_LINE, colour: OBJ_GV1_COLOUR, keyframes: OBJ_GV1_KF },
    Obj { kind: KIND_LINE, colour: OBJ_GV2_COLOUR, keyframes: OBJ_GV2_KF },
];
