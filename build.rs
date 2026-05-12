use std::fs;
use std::path::Path;

use serde_derive::Deserialize;

#[derive(Deserialize)]
struct Colour {
    r: u8,
    g: u8,
    b: u8,
}

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
    output.push_str("}\n\n");
    output.push_str("#[derive(Copy, Clone)]\n");
    output.push_str("pub struct Obj {\n");
    output.push_str("    pub colour: u8,\n");
    output.push_str("    pub keyframes: &'static [Kf],\n");
    output.push_str("}\n\n");

    let mut object_names = Vec::new();
    let mut last_frame = 0u16;

    for object in &scene.objects {
        let (id, colour) = match object {
            Object::Rect { id, colour } => (id, colour),
        };
        let const_name = const_name(id);
        if object_names.iter().any(|(name, _)| name == &const_name) {
            panic!("duplicate object const name OBJ_{const_name}");
        }

        let mut keyframes = Vec::new();
        for keyframe in &scene.keyframes {
            match keyframe {
                Keyframe::At {
                    frame,
                    id: key_id,
                    x0,
                    y0,
                    x1,
                    y1,
                } if key_id == id => {
                    keyframes.push((*frame, *x0, *y0, *x1, *y1));
                    if *frame > last_frame {
                        last_frame = *frame;
                    }
                }
                _ => {}
            }
        }

        if keyframes.is_empty() {
            panic!("object {id} has no keyframes");
        }

        keyframes.sort_by_key(|kf| kf.0);
        let mut i = 1;
        while i < keyframes.len() {
            if keyframes[i - 1].0 == keyframes[i].0 {
                panic!("object {id} has duplicate keyframe {}", keyframes[i].0);
            }
            i += 1;
        }

        output.push_str(&format!(
            "pub const OBJ_{}_COLOUR: u8 = 0x{:02X};\n",
            const_name,
            pack_colour(colour)
        ));
        output.push_str(&format!("pub const OBJ_{}_KF: &[Kf] = &[\n", const_name));
        for (frame, x0, y0, x1, y1) in &keyframes {
            output.push_str(&format!(
                "    Kf {{ frame: {}, x0: {}, y0: {}, x1: {}, y1: {} }},\n",
                frame, x0, y0, x1, y1
            ));
        }
        output.push_str("];\n\n");
        object_names.push((const_name, id));
    }

    for keyframe in &scene.keyframes {
        let Keyframe::At { id, .. } = keyframe;
        if !object_names.iter().any(|(_, object_id)| *object_id == id) {
            panic!("keyframe references unknown object {id}");
        }
    }

    output.push_str(&format!(
        "pub const OBJECT_COUNT: usize = {};\n",
        object_names.len()
    ));
    output.push_str(&format!("pub const LAST_FRAME: u16 = {};\n", last_frame));
    output.push_str("pub const OBJECTS: &[Obj] = &[\n");
    for (const_name, _) in &object_names {
        output.push_str(&format!(
            "    Obj {{ colour: OBJ_{}_COLOUR, keyframes: OBJ_{}_KF }},\n",
            const_name, const_name
        ));
    }
    output.push_str("];\n");

    write_if_changed(Path::new("src/generated_scene.rs"), &output);
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
