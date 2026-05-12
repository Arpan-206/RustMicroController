use std::env;
use std::fs;
use std::path::Path;

use serde::Deserialize;

const MAX_OBJECTS: usize = 32;
const MAX_FRAMES: usize = 64;
const MAX_CHANGES: usize = 8;
const ID_LEN: usize = 16;

#[derive(Deserialize, Copy, Clone)]
struct RonColour {
    r: u8,
    g: u8,
    b: u8,
}

#[derive(Deserialize)]
struct SceneFile {
    background: RonColour,
    scene: Vec<SceneItem>,
    timeline: Timeline,
}

#[derive(Deserialize)]
enum SceneItem {
    Rect {
        id: String,
        x0: u16,
        y0: u16,
        x1: u16,
        y1: u16,
        colour: RonColour,
    },
}

#[derive(Deserialize)]
struct Timeline {
    fps: u32,
    frames: Vec<FrameEntry>,
}

#[derive(Deserialize)]
enum FrameEntry {
    Frame { changes: Vec<ChangeRon> },
    None,
}

#[derive(Deserialize)]
enum ChangeRon {
    Move {
        id: String,
        dx: i16,
        dy: i16,
        repeat: u16,
    },
    None,
}

#[derive(Copy, Clone)]
struct MoveSpec {
    id: [u8; ID_LEN],
    dx: i16,
    dy: i16,
    repeat: u16,
}

#[derive(Copy, Clone)]
struct MoveOut {
    id: [u8; ID_LEN],
    dx: i16,
    dy: i16,
}

struct FrameOut {
    moves: Vec<MoveOut>,
}

fn main() {
    println!("cargo:rerun-if-changed=src/os.s");
    println!("cargo:rerun-if-changed=assets/scene.ron");

    cc::Build::new()
        .compiler("riscv64-unknown-elf-gcc")
        .flag("-march=rv32im_zicsr")
        .flag("-mabi=ilp32")
        .flag("-nostdlib")
        .flag("-mno-relax") // ← stops R_RISCV_RELAX being emitted
        .file("src/os.s")
        .compile("os");

    generate_scene();
}

fn generate_scene() {
    let scene_path = Path::new("assets/scene.ron");
    let scene_str = fs::read_to_string(scene_path).expect("Failed to read assets/scene.ron");
    let scene: SceneFile = ron::from_str(&scene_str).expect("Failed to parse scene.ron");

    validate_colour(&scene.background);

    if scene.scene.len() > MAX_OBJECTS {
        panic!("scene has too many objects (max {MAX_OBJECTS})");
    }

    for item in &scene.scene {
        match item {
            SceneItem::Rect { colour, .. } => validate_colour(colour),
        }
    }

    let expanded_frames = expand_frames(&scene.timeline.frames);
    if expanded_frames.len() > MAX_FRAMES {
        panic!("scene has too many frames after expansion (max {MAX_FRAMES})");
    }

    let out_dir = env::var("OUT_DIR").expect("OUT_DIR not set");
    let dest_path = Path::new(&out_dir).join("scene_gen.rs");

    let mut output = String::new();
    output.push_str("use crate::dsf;\n\n");
    output.push_str("pub const SCENE: dsf::Scene = dsf::Scene {\n");
    output.push_str(&format!(
        "    background: dsf::RonColour {{ r: {}, g: {}, b: {} }},\n",
        scene.background.r, scene.background.g, scene.background.b
    ));

    output.push_str("    objects: [\n");
    for item in &scene.scene {
        match item {
            SceneItem::Rect {
                id,
                x0,
                y0,
                x1,
                y1,
                colour,
            } => {
                let id_bytes = id_bytes(id);
                let id_literal = id_literal(&id_bytes);
                output.push_str(&format!(
                    "        dsf::RectObj {{ id: {}, x0: {}, y0: {}, x1: {}, y1: {}, colour: dsf::RonColour {{ r: {}, g: {}, b: {} }} }},\n",
                    id_literal, x0, y0, x1, y1, colour.r, colour.g, colour.b
                ));
            }
        }
    }
    for _ in scene.scene.len()..MAX_OBJECTS {
        output.push_str("        dsf::RectObj::empty(),\n");
    }
    output.push_str("    ],\n");
    output.push_str(&format!("    object_count: {},\n", scene.scene.len()));

    output.push_str("    timeline: dsf::Timeline {\n");
    output.push_str(&format!("        fps: {},\n", scene.timeline.fps.max(1)));
    output.push_str("        frames: [\n");
    for frame in &expanded_frames {
        output.push_str("            dsf::Frame { changes: [\n");
        for mv in &frame.moves {
            let id_literal = id_literal(&mv.id);
            output.push_str(&format!(
                "                dsf::Change::Move {{ id: {}, dx: {}, dy: {} }},\n",
                id_literal, mv.dx, mv.dy
            ));
        }
        for _ in frame.moves.len()..MAX_CHANGES {
            output.push_str("                dsf::Change::None,\n");
        }
        output.push_str(&format!(
            "            ], change_count: {} }},\n",
            frame.moves.len()
        ));
    }
    for _ in expanded_frames.len()..MAX_FRAMES {
        output.push_str("            dsf::Frame::empty(),\n");
    }
    output.push_str("        ],\n");
    output.push_str(&format!(
        "        frame_count: {},\n",
        expanded_frames.len()
    ));
    output.push_str("    },\n");
    output.push_str("};\n");

    fs::write(&dest_path, output).expect("Failed to write scene_gen.rs");
}

fn expand_frames(frames: &[FrameEntry]) -> Vec<FrameOut> {
    let mut expanded = Vec::new();
    for entry in frames {
        match entry {
            FrameEntry::None => expanded.push(FrameOut { moves: Vec::new() }),
            FrameEntry::Frame { changes } => {
                let mut moves = Vec::new();
                for change in changes {
                    match change {
                        ChangeRon::Move { id, dx, dy, repeat } => {
                            moves.push(MoveSpec {
                                id: id_bytes(id),
                                dx: *dx,
                                dy: *dy,
                                repeat: *repeat,
                            });
                        }
                        ChangeRon::None => {}
                    }
                }

                if moves.len() > MAX_CHANGES {
                    panic!("frame has too many moves (max {MAX_CHANGES})");
                }

                let mut max_repeat = 0u16;
                for mv in &moves {
                    if mv.repeat > max_repeat {
                        max_repeat = mv.repeat;
                    }
                }

                if max_repeat == 0 {
                    expanded.push(FrameOut { moves: Vec::new() });
                    continue;
                }

                for step in 0..max_repeat {
                    let mut frame_moves = Vec::new();
                    for mv in &moves {
                        if step < mv.repeat {
                            frame_moves.push(MoveOut {
                                id: mv.id,
                                dx: mv.dx,
                                dy: mv.dy,
                            });
                        }
                    }
                    expanded.push(FrameOut { moves: frame_moves });
                }
            }
        }
    }
    expanded
}

fn validate_colour(colour: &RonColour) {
    if colour.r > 7 || colour.g > 7 || colour.b > 3 {
        panic!(
            "colour out of range: r/g must be 0-7, b must be 0-3 (got r={}, g={}, b={})",
            colour.r, colour.g, colour.b
        );
    }
}

fn id_bytes(id: &str) -> [u8; ID_LEN] {
    if id.as_bytes().len() > ID_LEN {
        panic!("id '{id}' is too long (max {ID_LEN} bytes)");
    }
    let mut bytes = [0u8; ID_LEN];
    for (i, b) in id.as_bytes().iter().enumerate() {
        bytes[i] = *b;
    }
    bytes
}

fn id_literal(bytes: &[u8; ID_LEN]) -> String {
    let list = bytes
        .iter()
        .map(|b| b.to_string())
        .collect::<Vec<_>>()
        .join(", ");
    format!("[{}]", list)
}
