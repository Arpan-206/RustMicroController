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

pub const KIND_LINE: u8 = 3;

#[derive(Copy, Clone)]
pub struct Obj {
    pub kind: u8,
    pub colour: u8,
    pub keyframes: &'static [Kf],
}

pub const OBJ_BALL45_COLOUR: u8 = 0xE0;
pub const OBJ_BALL45_KF: &[Kf] = &[
    Kf { frame: 0, x0: 280, y0: 94, x1: 35, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 20, x0: 242, y0: 137, x1: 35, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 40, x0: 217, y0: 268, x1: 35, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 60, x0: 195, y0: 276, x1: 35, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 80, x0: 200, y0: 288, x1: 35, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 100, x0: 204, y0: 294, x1: 35, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 120, x0: 208, y0: 298, x1: 35, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 140, x0: 209, y0: 298, x1: 35, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 1199, x0: 209, y0: 298, x1: 35, y1: 0, x2: 0, y2: 0 },
];

pub const OBJ_BALL46_COLOUR: u8 = 0x1F;
pub const OBJ_BALL46_KF: &[Kf] = &[
    Kf { frame: 0, x0: 336, y0: 110, x1: 18, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 20, x0: 368, y0: 222, x1: 18, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 40, x0: 366, y0: 357, x1: 18, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 60, x0: 365, y0: 356, x1: 18, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 80, x0: 376, y0: 352, x1: 18, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 100, x0: 382, y0: 350, x1: 18, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 120, x0: 386, y0: 349, x1: 18, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 140, x0: 387, y0: 348, x1: 18, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 1199, x0: 387, y0: 348, x1: 18, y1: 0, x2: 0, y2: 0 },
];

pub const OBJ_BALL47_COLOUR: u8 = 0xFC;
pub const OBJ_BALL47_KF: &[Kf] = &[
    Kf { frame: 0, x0: 279, y0: 44, x1: 15, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 20, x0: 228, y0: 88, x1: 15, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 40, x0: 205, y0: 233, x1: 15, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 60, x0: 164, y0: 195, x1: 15, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 80, x0: 192, y0: 233, x1: 15, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 100, x0: 166, y0: 255, x1: 15, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 120, x0: 165, y0: 272, x1: 15, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 140, x0: 165, y0: 273, x1: 15, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 1199, x0: 165, y0: 273, x1: 15, y1: 0, x2: 0, y2: 0 },
];

pub const OBJ_BALL48_COLOUR: u8 = 0xA3;
pub const OBJ_BALL48_KF: &[Kf] = &[
    Kf { frame: 0, x0: 333, y0: 75, x1: 37, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 20, x0: 320, y0: 98, x1: 37, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 40, x0: 302, y0: 232, x1: 37, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 60, x0: 273, y0: 273, x1: 37, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 80, x0: 275, y0: 281, x1: 37, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 100, x0: 277, y0: 285, x1: 37, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 120, x0: 279, y0: 286, x1: 37, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 140, x0: 280, y0: 286, x1: 37, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 1199, x0: 280, y0: 286, x1: 37, y1: 0, x2: 0, y2: 0 },
];

pub const OBJ_BALL49_COLOUR: u8 = 0x1C;
pub const OBJ_BALL49_KF: &[Kf] = &[
    Kf { frame: 0, x0: 355, y0: 96, x1: 40, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 20, x0: 391, y0: 154, x1: 40, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 40, x0: 395, y0: 302, x1: 40, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 60, x0: 414, y0: 306, x1: 40, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 100, x0: 419, y0: 301, x1: 40, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 120, x0: 423, y0: 298, x1: 40, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 140, x0: 424, y0: 298, x1: 40, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 1199, x0: 424, y0: 298, x1: 40, y1: 0, x2: 0, y2: 0 },
];

pub const OBJ_BALL50_COLOUR: u8 = 0xEC;
pub const OBJ_BALL50_KF: &[Kf] = &[
    Kf { frame: 0, x0: 284, y0: 115, x1: 23, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 20, x0: 244, y0: 195, x1: 23, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 40, x0: 224, y0: 326, x1: 23, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 60, x0: 228, y0: 329, x1: 23, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 80, x0: 235, y0: 334, x1: 23, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 100, x0: 242, y0: 338, x1: 23, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 120, x0: 247, y0: 340, x1: 23, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 140, x0: 248, y0: 341, x1: 23, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 1199, x0: 248, y0: 341, x1: 23, y1: 0, x2: 0, y2: 0 },
];

pub const OBJ_BALL51_COLOUR: u8 = 0xFF;
pub const OBJ_BALL51_KF: &[Kf] = &[
    Kf { frame: 0, x0: 304, y0: 54, x1: 18, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 20, x0: 266, y0: 86, x1: 18, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 40, x0: 246, y0: 226, x1: 18, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 60, x0: 236, y0: 205, x1: 18, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 80, x0: 229, y0: 240, x1: 18, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 100, x0: 234, y0: 247, x1: 18, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 120, x0: 236, y0: 252, x1: 18, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 140, x0: 236, y0: 253, x1: 18, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 1199, x0: 236, y0: 253, x1: 18, y1: 0, x2: 0, y2: 0 },
];

pub const OBJ_BALL52_COLOUR: u8 = 0x03;
pub const OBJ_BALL52_KF: &[Kf] = &[
    Kf { frame: 0, x0: 323, y0: 118, x1: 29, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 20, x0: 283, y0: 257, x1: 29, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 40, x0: 272, y0: 344, x1: 29, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 60, x0: 277, y0: 345, x1: 29, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 80, x0: 285, y0: 347, x1: 29, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 100, x0: 293, y0: 349, x1: 29, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 120, x0: 298, y0: 349, x1: 29, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 140, x0: 299, y0: 349, x1: 29, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 1199, x0: 299, y0: 349, x1: 29, y1: 0, x2: 0, y2: 0 },
];

pub const OBJ_BALL53_COLOUR: u8 = 0xE0;
pub const OBJ_BALL53_KF: &[Kf] = &[
    Kf { frame: 0, x0: 332, y0: 107, x1: 35, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 20, x0: 304, y0: 197, x1: 35, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 40, x0: 320, y0: 302, x1: 35, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 60, x0: 333, y0: 314, x1: 35, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 80, x0: 340, y0: 313, x1: 35, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 100, x0: 345, y0: 312, x1: 35, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 120, x0: 349, y0: 311, x1: 35, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 140, x0: 350, y0: 311, x1: 35, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 1199, x0: 350, y0: 311, x1: 35, y1: 0, x2: 0, y2: 0 },
];

pub const OBJ_BALL54_COLOUR: u8 = 0x1F;
pub const OBJ_BALL54_KF: &[Kf] = &[
    Kf { frame: 0, x0: 338, y0: 99, x1: 16, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 20, x0: 329, y0: 150, x1: 16, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 40, x0: 351, y0: 261, x1: 16, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 60, x0: 378, y0: 243, x1: 16, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 80, x0: 373, y0: 257, x1: 16, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 100, x0: 375, y0: 264, x1: 16, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 120, x0: 372, y0: 265, x1: 16, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 140, x0: 376, y0: 267, x1: 16, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 160, x0: 377, y0: 267, x1: 16, y1: 0, x2: 0, y2: 0 },
    Kf { frame: 1199, x0: 377, y0: 267, x1: 16, y1: 0, x2: 0, y2: 0 },
];

pub const OBJECT_COUNT: usize = 10;
pub const LAST_FRAME: u16 = 1199;
pub const OBJECTS: &[Obj] = &[
    Obj { kind: KIND_CIRCLE, colour: OBJ_BALL45_COLOUR, keyframes: OBJ_BALL45_KF },
    Obj { kind: KIND_CIRCLE, colour: OBJ_BALL46_COLOUR, keyframes: OBJ_BALL46_KF },
    Obj { kind: KIND_CIRCLE, colour: OBJ_BALL47_COLOUR, keyframes: OBJ_BALL47_KF },
    Obj { kind: KIND_CIRCLE, colour: OBJ_BALL48_COLOUR, keyframes: OBJ_BALL48_KF },
    Obj { kind: KIND_CIRCLE, colour: OBJ_BALL49_COLOUR, keyframes: OBJ_BALL49_KF },
    Obj { kind: KIND_CIRCLE, colour: OBJ_BALL50_COLOUR, keyframes: OBJ_BALL50_KF },
    Obj { kind: KIND_CIRCLE, colour: OBJ_BALL51_COLOUR, keyframes: OBJ_BALL51_KF },
    Obj { kind: KIND_CIRCLE, colour: OBJ_BALL52_COLOUR, keyframes: OBJ_BALL52_KF },
    Obj { kind: KIND_CIRCLE, colour: OBJ_BALL53_COLOUR, keyframes: OBJ_BALL53_KF },
    Obj { kind: KIND_CIRCLE, colour: OBJ_BALL54_COLOUR, keyframes: OBJ_BALL54_KF },
];
