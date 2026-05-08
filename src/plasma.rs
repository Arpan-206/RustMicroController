//! Plasma effect — full-screen 8bpp animation via scanline DMA.
//!
//! All trigonometry is precomputed; the hot path is pure integer table lookups.
//! Select the variant by changing `Plasma::new(variant)`:
//!   0 — classic smooth waves
//!   1 — concentric rings (alpha-max/beta-min distance approx)
//!   2 — diagonal XOR interference fringes

use crate::display::vdu_hline_buf;

// ── Precomputed sine table ───────────────────────────────────────────────────
// SINE[i] = ((sin(i * 2π / 256) + 1.0) * 127.5) as u8
// Maps 0..255 → 0..255 (unsigned sine, full range).
#[rustfmt::skip]
const SINE: [u8; 256] = [
    127, 130, 133, 136, 139, 143, 146, 149, 152, 155, 158, 161, 164, 167, 170, 173,
    176, 179, 182, 184, 187, 190, 193, 195, 198, 200, 203, 205, 208, 210, 213, 215,
    217, 219, 221, 224, 226, 228, 229, 231, 233, 235, 236, 238, 239, 241, 242, 244,
    245, 246, 247, 248, 249, 250, 251, 251, 252, 253, 253, 254, 254, 254, 254, 254,
    255, 254, 254, 254, 254, 254, 253, 253, 252, 251, 251, 250, 249, 248, 247, 246,
    245, 244, 242, 241, 239, 238, 236, 235, 233, 231, 229, 228, 226, 224, 221, 219,
    217, 215, 213, 210, 208, 205, 203, 200, 198, 195, 193, 190, 187, 184, 182, 179,
    176, 173, 170, 167, 164, 161, 158, 155, 152, 149, 146, 143, 139, 136, 133, 130,
    127, 124, 121, 118, 115, 111, 108, 105, 102,  99,  96,  93,  90,  87,  84,  81,
     78,  75,  72,  70,  67,  64,  61,  59,  56,  54,  51,  49,  46,  44,  41,  39,
     37,  35,  33,  30,  28,  26,  25,  23,  21,  19,  18,  16,  15,  13,  12,  10,
      9,   8,   7,   6,   5,   4,   3,   3,   2,   1,   1,   0,   0,   0,   0,   0,
      0,   0,   0,   0,   0,   0,   1,   1,   2,   3,   3,   4,   5,   6,   7,   8,
      9,  10,  12,  13,  15,  16,  18,  19,  21,  23,  25,  26,  28,  30,  33,  35,
     37,  39,  41,  44,  46,  49,  51,  54,  56,  59,  61,  64,  67,  70,  72,  75,
     78,  81,  84,  87,  90,  93,  96,  99, 102, 105, 108, 111, 115, 118, 121, 124,
];

// ── Precomputed colour palette (HSV hue rotation → RGB332) ──────────────────
// PALETTE[i]: hue = i/256*360°, S=1, V=1 → RGB → pack as RGB332.
// RGB332: bits [7:5]=R3, [4:2]=G3, [1:0]=B2
// Formula: ((r >> 5) << 5) | ((g >> 5) << 2) | (b >> 6)
#[rustfmt::skip]
const PALETTE: [u8; 256] = [
    224, 224, 224, 224, 224, 224, 228, 228, 228, 228, 228, 232, 232, 232, 232, 232,
    232, 236, 236, 236, 236, 236, 240, 240, 240, 240, 240, 244, 244, 244, 244, 244,
    244, 248, 248, 248, 248, 248, 252, 252, 252, 252, 252, 252, 252, 252, 252, 252,
    220, 220, 220, 220, 220, 220, 188, 188, 188, 188, 188, 156, 156, 156, 156, 156,
    124, 124, 124, 124, 124, 124,  92,  92,  92,  92,  92,  60,  60,  60,  60,  60,
     28,  28,  28,  28,  28,  28,  28,  28,  28,  28,  28,  28,  28,  28,  28,  28,
     28,  29,  29,  29,  29,  29,  29,  29,  29,  29,  29,  30,  30,  30,  30,  30,
     30,  30,  30,  30,  30,  30,  31,  31,  31,  31,  31,  31,  31,  31,  31,  31,
     31,  31,  31,  31,  31,  31,  27,  27,  27,  27,  27,  23,  23,  23,  23,  23,
     19,  19,  19,  19,  19,  19,  15,  15,  15,  15,  15,  11,  11,  11,  11,  11,
      7,   7,   7,   7,   7,   7,   3,   3,   3,   3,   3,   3,   3,   3,   3,   3,
      3,  35,  35,  35,  35,  35,  67,  67,  67,  67,  67,  99,  99,  99,  99,  99,
     99, 131, 131, 131, 131, 131, 163, 163, 163, 163, 163, 195, 195, 195, 195, 195,
    195, 227, 227, 227, 227, 227, 227, 227, 227, 227, 227, 227, 227, 227, 227, 227,
    226, 226, 226, 226, 226, 226, 226, 226, 226, 226, 226, 225, 225, 225, 225, 225,
    225, 225, 225, 225, 225, 225, 224, 224, 224, 224, 224, 224, 224, 224, 224, 224,
];

// ── Distance approximation (no sqrt, no float) ───────────────────────────────
// Alpha-max plus beta-min: ~4% error vs true Euclidean.
#[inline(always)]
fn dist_approx(dx: i32, dy: i32) -> u8 {
    let adx = dx.unsigned_abs();
    let ady = dy.unsigned_abs();
    let (max, min) = if adx > ady { (adx, ady) } else { (ady, adx) };
    ((max * 123 + min * 51) >> 7) as u8
}

// ── Plasma struct ────────────────────────────────────────────────────────────

pub struct Plasma {
    /// Frame counter / time variable — incremented each tick.
    t: u32,
    /// Which variant to render (0, 1, or 2).
    variant: u8,
}

impl Plasma {
    pub const fn new(variant: u8) -> Self {
        Self { t: 0, variant }
    }

    /// Render one full frame scanline by scanline, writing directly to the
    /// framebuffer via `vdu_hline_buf`.  `line_buf` is a caller-supplied
    /// 640-byte scratch buffer (lives on the user stack).
    pub fn render(&self, line_buf: &mut [u8; 640]) {
        let t = self.t as usize;

        match self.variant {
            1 => self.render_rings(line_buf, t),
            2 => self.render_diagonal(line_buf, t),
            _ => self.render_classic(line_buf, t),
        }
    }

    // ── Variant 0: classic smooth waves ─────────────────────────────────────
    fn render_classic(&self, line_buf: &mut [u8; 640], t: usize) {
        let t2 = t >> 1; // t/2 with no division
        for y in 0u32..480 {
            let yu = y as usize;
            let sy = SINE[(yu.wrapping_add(t2)) & 0xFF] as usize;
            for x in 0usize..640 {
                let sx = SINE[(x.wrapping_add(t)) & 0xFF] as usize;
                let sxy = SINE[((x.wrapping_add(yu)) >> 1) & 0xFF] as usize;
                // hypot approximation reused: dist from (x,y) to (0,0) scaled
                let sh = SINE[dist_approx(x as i32, yu as i32) as usize & 0xFF] as usize;
                let idx = sx.wrapping_add(sy).wrapping_add(sxy).wrapping_add(sh) & 0xFF;
                line_buf[x] = PALETTE[idx];
            }
            vdu_hline_buf(y, line_buf);
        }
    }

    // ── Variant 1: concentric rings ──────────────────────────────────────────
    fn render_rings(&self, line_buf: &mut [u8; 640], t: usize) {
        const CX: i32 = 320;
        const CY: i32 = 240;
        for y in 0u32..480 {
            let dy = y as i32 - CY;
            for x in 0usize..640 {
                let dx = x as i32 - CX;
                let d = dist_approx(dx, dy) as usize;
                let idx = SINE[(d.wrapping_add(t)) & 0xFF] as usize;
                line_buf[x] = PALETTE[idx];
            }
            vdu_hline_buf(y, line_buf);
        }
    }

    // ── Variant 2: diagonal XOR interference ────────────────────────────────
    fn render_diagonal(&self, line_buf: &mut [u8; 640], t: usize) {
        for y in 0u32..480 {
            let yu = y as usize;
            let sy = SINE[((yu * 2).wrapping_add(t)) & 0xFF] as usize;
            for x in 0usize..640 {
                let sx = SINE[((x * 2).wrapping_add(t)) & 0xFF] as usize;
                let idx = (sx ^ sy) & 0xFF;
                line_buf[x] = PALETTE[idx];
            }
            vdu_hline_buf(y, line_buf);
        }
    }

    /// Advance the time counter by one frame.
    #[inline(always)]
    pub fn tick(&mut self) {
        self.t = self.t.wrapping_add(1);
    }
}
