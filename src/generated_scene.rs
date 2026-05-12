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

pub const OBJ_SKY0_COLOUR: u8 = 0x01;
pub const OBJ_SKY0_KF: &[Kf] = &[
    Kf { frame: 0, x0: 0, y0: 0, x1: 639, y1: 60, x2: 0, y2: 0 },
];

pub const OBJ_SKY1_COLOUR: u8 = 0x21;
pub const OBJ_SKY1_KF: &[Kf] = &[
    Kf { frame: 0, x0: 0, y0: 60, x1: 639, y1: 140, x2: 0, y2: 0 },
];

pub const OBJ_SKY2_COLOUR: u8 = 0x42;
pub const OBJ_SKY2_KF: &[Kf] = &[
    Kf { frame: 0, x0: 0, y0: 140, x1: 639, y1: 210, x2: 0, y2: 0 },
];

pub const OBJ_SKY3_COLOUR: u8 = 0x86;
pub const OBJ_SKY3_KF: &[Kf] = &[
    Kf { frame: 0, x0: 0, y0: 210, x1: 639, y1: 270, x2: 0, y2: 0 },
];

pub const OBJ_GROUND_COLOUR: u8 = 0x09;
pub const OBJ_GROUND_KF: &[Kf] = &[
    Kf { frame: 0, x0: 0, y0: 270, x1: 639, y1: 479, x2: 0, y2: 0 },
];

pub const OBJ_SUN_COLOUR: u8 = 0xF4;
pub const OBJ_SUN_KF: &[Kf] = &[
    Kf { frame: 0, x0: 320, y0: 270, x1: 85, y1: 0, x2: 0, y2: 0 },
];

pub const OBJ_SL0_COLOUR: u8 = 0x00;
pub const OBJ_SL0_KF: &[Kf] = &[
    Kf { frame: 0, x0: 240, y0: 290, x1: 400, y1: 290, x2: 4, y2: 0 },
];

pub const OBJ_SL1_COLOUR: u8 = 0x00;
pub const OBJ_SL1_KF: &[Kf] = &[
    Kf { frame: 0, x0: 235, y0: 312, x1: 405, y1: 312, x2: 5, y2: 0 },
];

pub const OBJ_SL2_COLOUR: u8 = 0x00;
pub const OBJ_SL2_KF: &[Kf] = &[
    Kf { frame: 0, x0: 228, y0: 336, x1: 412, y1: 336, x2: 6, y2: 0 },
];

pub const OBJ_SL3_COLOUR: u8 = 0x00;
pub const OBJ_SL3_KF: &[Kf] = &[
    Kf { frame: 0, x0: 220, y0: 352, x1: 420, y1: 352, x2: 4, y2: 0 },
];

pub const OBJ_ML0_COLOUR: u8 = 0x22;
pub const OBJ_ML0_KF: &[Kf] = &[
    Kf { frame: 0, x0: 0, y0: 270, x1: 220, y1: 270, x2: 100, y2: 150 },
];

pub const OBJ_ML1_COLOUR: u8 = 0x02;
pub const OBJ_ML1_KF: &[Kf] = &[
    Kf { frame: 0, x0: 30, y0: 270, x1: 170, y1: 270, x2: 90, y2: 190 },
];

pub const OBJ_MR0_COLOUR: u8 = 0x22;
pub const OBJ_MR0_KF: &[Kf] = &[
    Kf { frame: 0, x0: 420, y0: 270, x1: 639, y1: 270, x2: 540, y2: 140 },
];

pub const OBJ_MR1_COLOUR: u8 = 0x02;
pub const OBJ_MR1_KF: &[Kf] = &[
    Kf { frame: 0, x0: 460, y0: 270, x1: 620, y1: 270, x2: 545, y2: 185 },
];

pub const OBJ_GH0_COLOUR: u8 = 0x1F;
pub const OBJ_GH0_KF: &[Kf] = &[
    Kf { frame: 0, x0: 0, y0: 305, x1: 639, y1: 305, x2: 1, y2: 0 },
];

pub const OBJ_GH1_COLOUR: u8 = 0x1F;
pub const OBJ_GH1_KF: &[Kf] = &[
    Kf { frame: 0, x0: 0, y0: 345, x1: 639, y1: 345, x2: 1, y2: 0 },
];

pub const OBJ_GH2_COLOUR: u8 = 0x1F;
pub const OBJ_GH2_KF: &[Kf] = &[
    Kf { frame: 0, x0: 0, y0: 395, x1: 639, y1: 395, x2: 1, y2: 0 },
];

pub const OBJ_GH3_COLOUR: u8 = 0x1F;
pub const OBJ_GH3_KF: &[Kf] = &[
    Kf { frame: 0, x0: 0, y0: 450, x1: 639, y1: 450, x2: 1, y2: 0 },
];

pub const OBJ_GV0_COLOUR: u8 = 0x1F;
pub const OBJ_GV0_KF: &[Kf] = &[
    Kf { frame: 0, x0: 320, y0: 270, x1: 0, y1: 479, x2: 1, y2: 0 },
];

pub const OBJ_GV1_COLOUR: u8 = 0x1F;
pub const OBJ_GV1_KF: &[Kf] = &[
    Kf { frame: 0, x0: 320, y0: 270, x1: 110, y1: 479, x2: 1, y2: 0 },
];

pub const OBJ_GV2_COLOUR: u8 = 0x1F;
pub const OBJ_GV2_KF: &[Kf] = &[
    Kf { frame: 0, x0: 320, y0: 270, x1: 220, y1: 479, x2: 1, y2: 0 },
];

pub const OBJ_GV3_COLOUR: u8 = 0x1F;
pub const OBJ_GV3_KF: &[Kf] = &[
    Kf { frame: 0, x0: 320, y0: 270, x1: 420, y1: 479, x2: 1, y2: 0 },
];

pub const OBJ_GV4_COLOUR: u8 = 0x1F;
pub const OBJ_GV4_KF: &[Kf] = &[
    Kf { frame: 0, x0: 320, y0: 270, x1: 530, y1: 479, x2: 1, y2: 0 },
];

pub const OBJ_GV5_COLOUR: u8 = 0x1F;
pub const OBJ_GV5_KF: &[Kf] = &[
    Kf { frame: 0, x0: 320, y0: 270, x1: 639, y1: 479, x2: 1, y2: 0 },
];

pub const OBJ_PLANET_COLOUR: u8 = 0xEC;
pub const OBJ_PLANET_KF: &[Kf] = &[
    Kf { frame: 0, x0: 530, y0: 75, x1: 32, y1: 0, x2: 0, y2: 0 },
];

pub const OBJ_RING_COLOUR: u8 = 0xFF;
pub const OBJ_RING_KF: &[Kf] = &[
    Kf { frame: 0, x0: 530, y0: 75, x1: 32, y1: 0, x2: 0, y2: 0 },
];

pub const OBJ_ST0_COLOUR: u8 = 0xFF;
pub const OBJ_ST0_KF: &[Kf] = &[
    Kf { frame: 0, x0: 35, y0: 25, x1: 2, y1: 0, x2: 0, y2: 0 },
];

pub const OBJ_ST1_COLOUR: u8 = 0xFF;
pub const OBJ_ST1_KF: &[Kf] = &[
    Kf { frame: 0, x0: 110, y0: 50, x1: 2, y1: 0, x2: 0, y2: 0 },
];

pub const OBJ_ST2_COLOUR: u8 = 0xFF;
pub const OBJ_ST2_KF: &[Kf] = &[
    Kf { frame: 0, x0: 195, y0: 18, x1: 2, y1: 0, x2: 0, y2: 0 },
];

pub const OBJ_ST3_COLOUR: u8 = 0xFF;
pub const OBJ_ST3_KF: &[Kf] = &[
    Kf { frame: 0, x0: 275, y0: 65, x1: 2, y1: 0, x2: 0, y2: 0 },
];

pub const OBJ_ST4_COLOUR: u8 = 0xFF;
pub const OBJ_ST4_KF: &[Kf] = &[
    Kf { frame: 0, x0: 390, y0: 35, x1: 2, y1: 0, x2: 0, y2: 0 },
];

pub const OBJ_ST5_COLOUR: u8 = 0xFF;
pub const OBJ_ST5_KF: &[Kf] = &[
    Kf { frame: 0, x0: 455, y0: 80, x1: 2, y1: 0, x2: 0, y2: 0 },
];

pub const OBJ_ST6_COLOUR: u8 = 0xFF;
pub const OBJ_ST6_KF: &[Kf] = &[
    Kf { frame: 0, x0: 580, y0: 30, x1: 2, y1: 0, x2: 0, y2: 0 },
];

pub const OBJ_ST7_COLOUR: u8 = 0xFF;
pub const OBJ_ST7_KF: &[Kf] = &[
    Kf { frame: 0, x0: 80, y0: 115, x1: 2, y1: 0, x2: 0, y2: 0 },
];

pub const OBJECT_COUNT: usize = 34;
pub const LAST_FRAME: u16 = 0;
pub const OBJECTS: &[Obj] = &[
    Obj { kind: KIND_RECT, colour: OBJ_SKY0_COLOUR, keyframes: OBJ_SKY0_KF },
    Obj { kind: KIND_RECT, colour: OBJ_SKY1_COLOUR, keyframes: OBJ_SKY1_KF },
    Obj { kind: KIND_RECT, colour: OBJ_SKY2_COLOUR, keyframes: OBJ_SKY2_KF },
    Obj { kind: KIND_RECT, colour: OBJ_SKY3_COLOUR, keyframes: OBJ_SKY3_KF },
    Obj { kind: KIND_RECT, colour: OBJ_GROUND_COLOUR, keyframes: OBJ_GROUND_KF },
    Obj { kind: KIND_CIRCLE, colour: OBJ_SUN_COLOUR, keyframes: OBJ_SUN_KF },
    Obj { kind: KIND_LINE, colour: OBJ_SL0_COLOUR, keyframes: OBJ_SL0_KF },
    Obj { kind: KIND_LINE, colour: OBJ_SL1_COLOUR, keyframes: OBJ_SL1_KF },
    Obj { kind: KIND_LINE, colour: OBJ_SL2_COLOUR, keyframes: OBJ_SL2_KF },
    Obj { kind: KIND_LINE, colour: OBJ_SL3_COLOUR, keyframes: OBJ_SL3_KF },
    Obj { kind: KIND_TRIANGLE, colour: OBJ_ML0_COLOUR, keyframes: OBJ_ML0_KF },
    Obj { kind: KIND_TRIANGLE, colour: OBJ_ML1_COLOUR, keyframes: OBJ_ML1_KF },
    Obj { kind: KIND_TRIANGLE, colour: OBJ_MR0_COLOUR, keyframes: OBJ_MR0_KF },
    Obj { kind: KIND_TRIANGLE, colour: OBJ_MR1_COLOUR, keyframes: OBJ_MR1_KF },
    Obj { kind: KIND_LINE, colour: OBJ_GH0_COLOUR, keyframes: OBJ_GH0_KF },
    Obj { kind: KIND_LINE, colour: OBJ_GH1_COLOUR, keyframes: OBJ_GH1_KF },
    Obj { kind: KIND_LINE, colour: OBJ_GH2_COLOUR, keyframes: OBJ_GH2_KF },
    Obj { kind: KIND_LINE, colour: OBJ_GH3_COLOUR, keyframes: OBJ_GH3_KF },
    Obj { kind: KIND_LINE, colour: OBJ_GV0_COLOUR, keyframes: OBJ_GV0_KF },
    Obj { kind: KIND_LINE, colour: OBJ_GV1_COLOUR, keyframes: OBJ_GV1_KF },
    Obj { kind: KIND_LINE, colour: OBJ_GV2_COLOUR, keyframes: OBJ_GV2_KF },
    Obj { kind: KIND_LINE, colour: OBJ_GV3_COLOUR, keyframes: OBJ_GV3_KF },
    Obj { kind: KIND_LINE, colour: OBJ_GV4_COLOUR, keyframes: OBJ_GV4_KF },
    Obj { kind: KIND_LINE, colour: OBJ_GV5_COLOUR, keyframes: OBJ_GV5_KF },
    Obj { kind: KIND_CIRCLE, colour: OBJ_PLANET_COLOUR, keyframes: OBJ_PLANET_KF },
    Obj { kind: KIND_CIRCLE, colour: OBJ_RING_COLOUR, keyframes: OBJ_RING_KF },
    Obj { kind: KIND_CIRCLE, colour: OBJ_ST0_COLOUR, keyframes: OBJ_ST0_KF },
    Obj { kind: KIND_CIRCLE, colour: OBJ_ST1_COLOUR, keyframes: OBJ_ST1_KF },
    Obj { kind: KIND_CIRCLE, colour: OBJ_ST2_COLOUR, keyframes: OBJ_ST2_KF },
    Obj { kind: KIND_CIRCLE, colour: OBJ_ST3_COLOUR, keyframes: OBJ_ST3_KF },
    Obj { kind: KIND_CIRCLE, colour: OBJ_ST4_COLOUR, keyframes: OBJ_ST4_KF },
    Obj { kind: KIND_CIRCLE, colour: OBJ_ST5_COLOUR, keyframes: OBJ_ST5_KF },
    Obj { kind: KIND_CIRCLE, colour: OBJ_ST6_COLOUR, keyframes: OBJ_ST6_KF },
    Obj { kind: KIND_CIRCLE, colour: OBJ_ST7_COLOUR, keyframes: OBJ_ST7_KF },
];
