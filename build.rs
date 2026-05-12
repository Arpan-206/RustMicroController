use std::env;
use std::fs;
use std::path::Path;

use serde::Deserialize;

const MAX_OBJECTS: usize = 8;
const MAX_FRAMES: usize = 64;
const MAX_MOVES_PER_FRAME: usize = 4;
const MAX_ID_LEN: usize = 8;

#[derive(Deserialize)]
struct Colour {
    r: u8,
    g: u8,
    b: u8,
}

#[derive(Deserialize)]
struct SceneFile {
    background: Colour,
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
        colour: Colour,
    },
}

#[derive(Deserialize)]
struct Timeline {
    fps: u32,
    frames: Vec<Frame>,
}

#[derive(Deserialize)]
struct Frame {
    changes: Vec<Change>,
}

#[derive(Deserialize)]
enum Change {
    Move {
        id: String,
        x0: u16,
        y0: u16,
        x1: u16,
        y1: u16,
    },
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

    if scene.scene.len() > MAX_OBJECTS {
        panic!("scene has too many objects (max {MAX_OBJECTS})");
    }
    if scene.timeline.frames.len() > MAX_FRAMES {
        panic!("scene has too many frames (max {MAX_FRAMES})");
    }
    for frame in &scene.timeline.frames {
        if frame.changes.len() > MAX_MOVES_PER_FRAME {
            panic!("frame has too many moves (max {MAX_MOVES_PER_FRAME})");
        }
    }

    let out_dir = env::var("OUT_DIR").expect("OUT_DIR not set");
    let dest_path = Path::new(&out_dir).join("scene_gen.rs");

    let mut output = String::new();
    output.push_str("use crate::dsf;\n\n");
    output.push_str("pub const SCENE: dsf::Scene = dsf::Scene {\n");
    output.push_str(&format!(
        "    background: dsf::Colour {{ r: {}, g: {}, b: {} }},\n",
        scene.background.r, scene.background.g, scene.background.b
    ));

    output.push_str("    rects: [\n");
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
                let (id_bytes, id_len) = id_bytes(id);
                output.push_str(&format!(
                    "        dsf::RectDef {{ id: dsf::Id::from_bytes({}, {}), x0: {}, y0: {}, x1: {}, y1: {}, colour: dsf::Colour {{ r: {}, g: {}, b: {} }} }},\n",
                    id_bytes, id_len, x0, y0, x1, y1, colour.r, colour.g, colour.b
                ));
            }
        }
    }
    for _ in scene.scene.len()..MAX_OBJECTS {
        output.push_str("        dsf::RectDef::empty(),\n");
    }
    output.push_str("    ],\n");
    output.push_str(&format!("    rect_count: {},\n", scene.scene.len()));

    output.push_str("    timeline: dsf::Timeline {\n");
    output.push_str(&format!("        fps: {},\n", scene.timeline.fps.max(1)));
    output.push_str("        frames: [\n");
    for frame in &scene.timeline.frames {
        output.push_str("            dsf::Frame { moves: [\n");
        for change in &frame.changes {
            match change {
                Change::Move { id, x0, y0, x1, y1 } => {
                    let (id_bytes, id_len) = id_bytes(id);
                    output.push_str(&format!(
                        "                dsf::Move {{ id: dsf::Id::from_bytes({}, {}), x0: {}, y0: {}, x1: {}, y1: {} }},\n",
                        id_bytes, id_len, x0, y0, x1, y1
                    ));
                }
            }
        }
        for _ in frame.changes.len()..MAX_MOVES_PER_FRAME {
            output.push_str("                dsf::Move::empty(),\n");
        }
        output.push_str(&format!(
            "            ], move_count: {} }},\n",
            frame.changes.len()
        ));
    }
    for _ in scene.timeline.frames.len()..MAX_FRAMES {
        output.push_str("            dsf::Frame::empty(),\n");
    }
    output.push_str("        ],\n");
    output.push_str(&format!(
        "        frame_count: {},\n",
        scene.timeline.frames.len()
    ));
    output.push_str("    },\n");
    output.push_str("};\n");

    fs::write(&dest_path, output).expect("Failed to write scene_gen.rs");
}

fn id_bytes(id: &str) -> (String, u8) {
    let mut bytes = [0u8; MAX_ID_LEN];
    let mut len = 0usize;
    for (i, b) in id.as_bytes().iter().enumerate() {
        if i >= MAX_ID_LEN {
            break;
        }
        bytes[i] = *b;
        len = i + 1;
    }
    let list = bytes
        .iter()
        .map(|b| b.to_string())
        .collect::<Vec<_>>()
        .join(", ");
    (format!("[{}]", list), len as u8)
}
