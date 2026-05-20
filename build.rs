#![allow(clippy::if_same_then_else)]

use std::fs;
use std::path::Path;

use serde_derive::Deserialize;

#[derive(Deserialize)]
struct Colour {
    r: u8,
    g: u8,
    b: u8,
}

type Rgb = Colour;

#[derive(Deserialize)]
struct SceneFile {
    background: Colour,
    fps: u32,
    objects: Vec<Object>,
    keyframes: Vec<Keyframe>,
}

#[derive(Deserialize)]
enum Object {
    Rect { id: String, colour: Colour },
    Triangle { id: String, colour: Colour },
    Circle { id: String, colour: Colour },
    Line { id: String, colour: Rgb },
}

#[derive(Deserialize)]
enum Keyframe {
    At {
        frame: u16,
        id: String,
        x0: u16,
        y0: u16,
        x1: u16,
        y1: u16,
    },
    AtTriangle {
        frame: u16,
        id: String,
        x0: u16,
        y0: u16,
        x1: u16,
        y1: u16,
        x2: u16,
        y2: u16,
    },
    AtCircle {
        frame: u16,
        id: String,
        cx: u16,
        cy: u16,
        r: u16,
    },
    AtLine {
        frame: u32,
        id: String,
        x0: u16,
        y0: u16,
        x1: u16,
        y1: u16,
        thickness: u16,
    },
}

#[derive(Copy, Clone)]
struct GeneratedKf {
    frame: u16,
    x0: u16,
    y0: u16,
    x1: u16,
    y1: u16,
    x2: u16,
    y2: u16,
}

fn dedup_kfs(kfs: &[GeneratedKf]) -> Vec<GeneratedKf> {
    let mut out = Vec::new();
    if kfs.is_empty() {
        return out;
    }

    let last_index = kfs.len().saturating_sub(1);
    for (i, &kf) in kfs.iter().enumerate() {
        if i == 0 || i == last_index {
            out.push(kf);
        } else if !same_kf_position(out.last().unwrap(), &kf) {
            out.push(kf);
        }
    }
    out
}

fn same_kf_position(a: &GeneratedKf, b: &GeneratedKf) -> bool {
    a.x0 == b.x0 && a.y0 == b.y0 && a.x1 == b.x1 && a.y1 == b.y1 && a.x2 == b.x2 && a.y2 == b.y2
}

fn main() {
    println!("cargo:rerun-if-changed=src/os.s");
    println!("cargo:rerun-if-changed=assets/scene.ron");

    cc::Build::new()
        .compiler("riscv64-unknown-elf-gcc")
        .flag("-march=rv32im_zicsr")
        .flag("-mabi=ilp32")
        .flag("-nostdlib")
        .flag("-mno-relax")
        .file("src/os.s")
        .compile("os");

    generate_scene();
}

fn generate_scene() {
    let scene_path = Path::new("assets/scene.ron");
    let scene_str = fs::read_to_string(scene_path).expect("Failed to read assets/scene.ron");
    let scene: SceneFile = ron::from_str(&scene_str).expect("Failed to parse assets/scene.ron");

    let mut output = String::new();
    output.push_str("// generated - do not edit\n\n");
    output.push_str(&format!("pub const FPS: u32 = {};\n", scene.fps.max(1)));
    output.push_str(&format!(
        "pub const BG: u8 = 0x{:02X};\n\n",
        pack_colour(&scene.background)
    ));
    output.push_str("#[derive(Copy, Clone)]\n");
    output.push_str("pub struct Kf {\n");
    output.push_str("    pub frame: u16,\n");
    output.push_str("    pub x0: u16,\n");
    output.push_str("    pub y0: u16,\n");
    output.push_str("    pub x1: u16,\n");
    output.push_str("    pub y1: u16,\n");
    output.push_str("    pub x2: u16,\n");
    output.push_str("    pub y2: u16,\n");
    output.push_str("}\n\n");
    output.push_str("pub const KIND_RECT: u8 = 0;\n");
    output.push_str("pub const KIND_TRIANGLE: u8 = 1;\n");
    output.push_str("pub const KIND_CIRCLE: u8 = 2;\n\n");
    output.push_str("pub const KIND_LINE: u8 = 3;\n\n");
    output.push_str("#[derive(Copy, Clone)]\n");
    output.push_str("pub struct Obj {\n");
    output.push_str("    pub kind: u8,\n");
    output.push_str("    pub colour: u8,\n");
    output.push_str("    pub keyframes: &'static [Kf],\n");
    output.push_str("}\n\n");

    let mut object_names = Vec::new();
    let mut last_frame = 0u16;

    for object in &scene.objects {
        let id = object_id(object);
        let const_name = const_name(id);
        if object_names
            .iter()
            .any(|(name, _, _): &(String, &str, &str)| name == &const_name)
        {
            panic!("duplicate object const name OBJ_{const_name}");
        }

        let mut keyframes = Vec::new();
        for keyframe in &scene.keyframes {
            if let Some(kf) = keyframe_for_object(object, keyframe) {
                keyframes.push(kf);
                if kf.frame > last_frame {
                    last_frame = kf.frame;
                }
            }
        }

        if keyframes.is_empty() {
            panic!("object {id} has no keyframes");
        }

        keyframes.sort_by_key(|kf| kf.frame);
        for i in 1..keyframes.len() {
            if keyframes[i - 1].frame == keyframes[i].frame {
                panic!("object {id} has duplicate keyframe {}", keyframes[i].frame);
            }
        }

        let keyframes = dedup_kfs(&keyframes);

        output.push_str(&format!(
            "pub const OBJ_{}_COLOUR: u8 = 0x{:02X};\n",
            const_name,
            pack_colour(object_colour(object))
        ));
        output.push_str(&format!("pub const OBJ_{}_KF: &[Kf] = &[\n", const_name));
        for kf in &keyframes {
            output.push_str(&format!(
                "    Kf {{ frame: {}, x0: {}, y0: {}, x1: {}, y1: {}, x2: {}, y2: {} }},\n",
                kf.frame, kf.x0, kf.y0, kf.x1, kf.y1, kf.x2, kf.y2
            ));
        }
        output.push_str("];\n\n");
        object_names.push((const_name, id, object_kind_name(object)));
    }

    for keyframe in &scene.keyframes {
        let id = keyframe_id(keyframe);
        let Some(object) = scene.objects.iter().find(|object| object_id(object) == id) else {
            panic!("keyframe references unknown object {id}");
        };
        if !keyframe_matches_object(object, keyframe) {
            panic!("keyframe kind does not match object {id}");
        }
    }

    output.push_str(&format!(
        "pub const OBJECT_COUNT: usize = {};\n",
        object_names.len()
    ));
    output.push_str(&format!("pub const LAST_FRAME: u16 = {};\n", last_frame));
    output.push_str("pub const OBJECTS: &[Obj] = &[\n");
    for (const_name, _, kind_name) in &object_names {
        output.push_str(&format!(
            "    Obj {{ kind: {}, colour: OBJ_{}_COLOUR, keyframes: OBJ_{}_KF }},\n",
            kind_name, const_name, const_name
        ));
    }
    output.push_str("];\n");

    write_if_changed(Path::new("src/generated_scene.rs"), &output);
}

fn keyframe_for_object(object: &Object, keyframe: &Keyframe) -> Option<GeneratedKf> {
    match (object, keyframe) {
        (
            Object::Rect { id, .. },
            Keyframe::At {
                frame,
                id: key_id,
                x0,
                y0,
                x1,
                y1,
            },
        ) if key_id == id => Some(GeneratedKf {
            frame: *frame,
            x0: *x0,
            y0: *y0,
            x1: *x1,
            y1: *y1,
            x2: 0,
            y2: 0,
        }),
        (
            Object::Triangle { id, .. },
            Keyframe::AtTriangle {
                frame,
                id: key_id,
                x0,
                y0,
                x1,
                y1,
                x2,
                y2,
            },
        ) if key_id == id => Some(GeneratedKf {
            frame: *frame,
            x0: *x0,
            y0: *y0,
            x1: *x1,
            y1: *y1,
            x2: *x2,
            y2: *y2,
        }),
        (
            Object::Circle { id, .. },
            Keyframe::AtCircle {
                frame,
                id: key_id,
                cx,
                cy,
                r,
            },
        ) if key_id == id => Some(GeneratedKf {
            frame: *frame,
            x0: *cx,
            y0: *cy,
            x1: *r,
            y1: 0,
            x2: 0,
            y2: 0,
        }),
        (
            Object::Line { id, .. },
            Keyframe::AtLine {
                frame,
                id: key_id,
                x0,
                y0,
                x1,
                y1,
                thickness,
            },
        ) if key_id == id => Some(GeneratedKf {
            frame: frame_to_u16(*frame),
            x0: *x0,
            y0: *y0,
            x1: *x1,
            y1: *y1,
            x2: *thickness,
            y2: 0,
        }),
        _ => None,
    }
}

fn keyframe_matches_object(object: &Object, keyframe: &Keyframe) -> bool {
    match (object, keyframe) {
        (Object::Rect { id, .. }, Keyframe::At { id: key_id, .. })
        | (Object::Triangle { id, .. }, Keyframe::AtTriangle { id: key_id, .. })
        | (Object::Circle { id, .. }, Keyframe::AtCircle { id: key_id, .. })
        | (Object::Line { id, .. }, Keyframe::AtLine { id: key_id, .. }) => key_id == id,
        _ => false,
    }
}

fn keyframe_id(keyframe: &Keyframe) -> &str {
    match keyframe {
        Keyframe::At { id, .. }
        | Keyframe::AtTriangle { id, .. }
        | Keyframe::AtCircle { id, .. }
        | Keyframe::AtLine { id, .. } => id,
    }
}

fn object_id(object: &Object) -> &str {
    match object {
        Object::Rect { id, .. }
        | Object::Triangle { id, .. }
        | Object::Circle { id, .. }
        | Object::Line { id, .. } => id,
    }
}

fn object_colour(object: &Object) -> &Colour {
    match object {
        Object::Rect { colour, .. }
        | Object::Triangle { colour, .. }
        | Object::Circle { colour, .. }
        | Object::Line { colour, .. } => colour,
    }
}

fn object_kind_name(object: &Object) -> &'static str {
    match object {
        Object::Rect { .. } => "KIND_RECT",
        Object::Triangle { .. } => "KIND_TRIANGLE",
        Object::Circle { .. } => "KIND_CIRCLE",
        Object::Line { .. } => "KIND_LINE",
    }
}

fn frame_to_u16(frame: u32) -> u16 {
    if frame > u16::MAX as u32 {
        panic!("line keyframe frame out of range");
    }
    frame as u16
}

fn pack_colour(colour: &Colour) -> u8 {
    if colour.r > 7 || colour.g > 7 || colour.b > 3 {
        panic!("colour out of range");
    }
    (colour.r << 5) | (colour.g << 2) | colour.b
}

fn const_name(id: &str) -> String {
    let mut name = String::new();
    for ch in id.chars() {
        if ch.is_ascii_alphanumeric() {
            name.push(ch.to_ascii_uppercase());
        } else {
            name.push('_');
        }
    }
    if name.is_empty() || name.as_bytes()[0].is_ascii_digit() {
        name.insert(0, '_');
    }
    name
}

fn write_if_changed(path: &Path, output: &str) {
    if let Ok(existing) = fs::read_to_string(path) {
        if existing == output {
            return;
        }
    }
    fs::write(path, output).expect("Failed to write generated scene");
}
