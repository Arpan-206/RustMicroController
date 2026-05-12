#![no_std]
#![no_main]

mod display;
mod dsf;
mod io;
mod scene;
mod syscall;

use core::panic::PanicInfo;

use display::draw_rect;

mod scene_data {
    include!(concat!(env!("OUT_DIR"), "/scene_gen.rs"));
}

use scene_data::SCENE;

#[no_mangle]
pub extern "C" fn user_main() {
    syscall::vdu_init(0); // 8bpp mode

    let scene = &SCENE;
    let mut state = scene::SceneState::from_scene(scene);

    draw_rect(0, 0, 639, 479, state.background);
    state.draw_all();

    io::timer_start(io::TIMER_1MS);
    syscall::counter_clr();

    let fps = if scene.timeline.fps == 0 {
        1
    } else {
        scene.timeline.fps
    };
    let mut ticks_per_frame = 1000 / fps;
    if ticks_per_frame == 0 {
        ticks_per_frame = 1;
    }

    let mut frame_index = 0usize;
    loop {
        let start = syscall::counter_get();

        if scene.timeline.frame_count > 0 {
            let frame = &scene.timeline.frames[frame_index];
            state.apply_frame(frame);
            frame_index = (frame_index + 1) % scene.timeline.frame_count;
        }

        while syscall::counter_get().wrapping_sub(start) < ticks_per_frame {}
    }
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}
