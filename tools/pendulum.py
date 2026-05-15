#!/usr/bin/env python3
"""
pendulum.py — pendulum + rolling balls scene
python3 pendulum.py
python3 pendulum.py --headless --export pendulum.ron
"""

import argparse
import math
import os
import tkinter as tk

import pymunk

W, H = 640, 480


def r332_to_hex(r, g, b):
    return f"#{int(r / 7 * 255):02x}{int(g / 7 * 255):02x}{int(b / 3 * 255):02x}"


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def simulate(total_frames, fps):
    space = pymunk.Space()
    space.gravity = (0, 500)

    # ── ground ────────────────────────────────────────────────────────────
    ground = pymunk.Segment(space.static_body, (0, H - 40), (W, H - 40), 4)
    ground.elasticity = 0.4
    ground.friction = 0.9
    space.add(ground)

    # ── pendulum pivot at top-centre ──────────────────────────────────────
    pivot_x, pivot_y = W // 2, 60
    arm_len = 160

    bob_mass = 8.0
    bob_r = 28
    bob_moment = pymunk.moment_for_circle(bob_mass, 0, bob_r)
    bob_body = pymunk.Body(bob_mass, bob_moment)
    # start displaced 70° to the right
    angle = math.radians(70)
    bob_body.position = (
        pivot_x + arm_len * math.sin(angle),
        pivot_y + arm_len * math.cos(angle),
    )
    bob_shape = pymunk.Circle(bob_body, bob_r)
    bob_shape.elasticity = 0.2
    bob_shape.friction = 0.5
    space.add(bob_body, bob_shape)

    # pin joint — connects bob to a static pivot point
    pivot_body = pymunk.Body(body_type=pymunk.Body.STATIC)
    pivot_body.position = (pivot_x, pivot_y)
    space.add(pivot_body)
    joint = pymunk.PinJoint(pivot_body, bob_body, (0, 0), (0, 0))
    space.add(joint)

    # ── rolling ball 1 ────────────────────────────────────────────────────
    r1_mass = 3.0
    r1_r = 18
    r1_moment = pymunk.moment_for_circle(r1_mass, 0, r1_r)
    r1_body = pymunk.Body(r1_mass, r1_moment)
    r1_body.position = (60, H - 40 - r1_r)
    r1_body.velocity = (180, 0)
    r1_shape = pymunk.Circle(r1_body, r1_r)
    r1_shape.elasticity = 0.6
    r1_shape.friction = 0.8
    space.add(r1_body, r1_shape)

    # ── rolling ball 2 ────────────────────────────────────────────────────
    r2_mass = 2.0
    r2_r = 13
    r2_moment = pymunk.moment_for_circle(r2_mass, 0, r2_r)
    r2_body = pymunk.Body(r2_mass, r2_moment)
    r2_body.position = (W - 60, H - 40 - r2_r)
    r2_body.velocity = (-140, -60)
    r2_shape = pymunk.Circle(r2_body, r2_r)
    r2_shape.elasticity = 0.75
    r2_shape.friction = 0.7
    space.add(r2_body, r2_shape)

    # ── record ────────────────────────────────────────────────────────────
    bob_states = []
    r1_states = []
    r2_states = []
    pivot_states = [(pivot_x, pivot_y)] * total_frames  # static

    dt = 1.0 / fps
    for _ in range(total_frames):
        space.step(dt)
        bob_states.append((int(bob_body.position.x), int(bob_body.position.y), bob_r))
        r1_states.append((int(r1_body.position.x), int(r1_body.position.y), r1_r))
        r2_states.append((int(r2_body.position.x), int(r2_body.position.y), r2_r))

    return (
        {
            "pivot": pivot_states,
            "bob": bob_states,
            "ball1": r1_states,
            "ball2": r2_states,
        },
        pivot_x,
        pivot_y,
        arm_len,
    )


def export_ron(path, states, fps, total_frames, pivot_x, pivot_y, arm_len):
    STEP = max(1, total_frames // 80)
    frames_to_emit = sorted(set(range(0, total_frames, STEP)) | {total_frames - 1})

    lines = [
        "(",
        "    background: (r: 0, g: 0, b: 0),",
        f"    fps: {fps},",
        "    objects: [",
        '        Rect(id: "ground",  colour: (r: 2, g: 2, b: 1)),',
        '        Line(id: "arm",    colour: (r: 4, g: 4, b: 2)),',
        '        Circle(id: "pivot", colour: (r: 7, g: 7, b: 3)),',
        '        Circle(id: "bob",   colour: (r: 7, g: 3, b: 0)),',
        '        Circle(id: "ball1", colour: (r: 0, g: 7, b: 0)),',
        '        Circle(id: "ball2", colour: (r: 0, g: 4, b: 3)),',
        "    ],",
        "    keyframes: [",
        # ground — static
        '        At(frame: 0,    id: "ground",  x0: 0, y0: 440, x1: 639, y1: 444),',
        f'        At(frame: {total_frames - 1}, id: "ground",  x0: 0, y0: 440, x1: 639, y1: 444),',
        # pivot — static dot
        f'        AtCircle(frame: 0,    id: "pivot", cx: {pivot_x}, cy: {pivot_y}, r: 5),',
        f'        AtCircle(frame: {total_frames - 1}, id: "pivot", cx: {pivot_x}, cy: {pivot_y}, r: 5),',
    ]

    # arm + bob — both driven by bob_states
    for f in frames_to_emit:
        cx, cy, r = states["bob"][f]
        cx = clamp(cx, 0, 639)
        cy = clamp(cy, 0, 479)
        # arm: pivot → bob centre
        lines.append(
            f'        AtLine(frame: {f}, id: "arm", '
            f"x0: {pivot_x}, y0: {pivot_y}, x1: {cx}, y1: {cy}, thickness: 2),"
        )
        # bob circle
        lines.append(
            f'        AtCircle(frame: {f}, id: "bob", cx: {cx}, cy: {cy}, r: {r}),'
        )

    # ball1 and ball2 separately
    for label in ("ball1", "ball2"):
        for f in frames_to_emit:
            cx, cy, r = states[label][f]
            cx = clamp(cx, 0, 639)
            cy = clamp(cy, 0, 479)
            lines.append(
                f'        AtCircle(frame: {f}, id: "{label}", cx: {cx}, cy: {cy}, r: {r}),'
            )

    lines += ["    ],", ")"]

    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"Exported -> {path}")


class App:
    COLOURS = {
        "pivot": "#ffff99",
        "bob": "#ff8800",
        "ball1": "#00ee00",
        "ball2": "#00bbbb",
    }
    BOB_R = 28
    R1_R = 18
    R2_R = 13
    PIV_R = 5

    def __init__(
        self, root, states, fps, total_frames, export_path, pivot_x, pivot_y, arm_len
    ):
        self.states = states
        self.fps = fps
        self.total_frames = total_frames
        self.export_path = export_path
        self.pivot_x = pivot_x
        self.pivot_y = pivot_y
        self.frame = 0
        self.playing = True

        root.title("Pendulum + Balls")
        root.resizable(False, False)
        root.bind("<KeyPress>", self.on_key)

        self.canvas = tk.Canvas(
            root, width=W, height=H, bg="black", highlightthickness=0
        )
        self.canvas.pack()
        self.hud = tk.Label(
            root, text="", bg="#111", fg="#ccc", font=("Courier", 11), anchor="w"
        )
        self.hud.pack(fill="x", padx=4, pady=2)
        self.draw()
        self.tick()

    def draw(self):
        c = self.canvas
        c.delete("all")

        # ground
        c.create_rectangle(0, 440, W, 444, fill="#666644", outline="")

        # arm line
        bx, by, _ = self.states["bob"][self.frame]
        c.create_line(self.pivot_x, self.pivot_y, bx, by, fill="#888888", width=2)

        # pivot
        pr = self.PIV_R
        c.create_oval(
            self.pivot_x - pr,
            self.pivot_y - pr,
            self.pivot_x + pr,
            self.pivot_y + pr,
            fill="#ffff99",
            outline="",
        )

        # bob
        r = self.BOB_R
        c.create_oval(bx - r, by - r, bx + r, by + r, fill="#ff8800", outline="")

        # ball1
        x1, y1, _ = self.states["ball1"][self.frame]
        r = self.R1_R
        c.create_oval(x1 - r, y1 - r, x1 + r, y1 + r, fill="#00ee00", outline="")

        # ball2
        x2, y2, _ = self.states["ball2"][self.frame]
        r = self.R2_R
        c.create_oval(x2 - r, y2 - r, x2 + r, y2 + r, fill="#00bbbb", outline="")

        st = "▶" if self.playing else "⏸"
        self.hud.config(
            text=f"{st}  frame {self.frame}/{self.total_frames - 1}  |  "
            "SPACE play/pause  ←→ step  R rewind  E export  Q quit"
        )

    def tick(self):
        if self.playing:
            self.frame = (self.frame + 1) % self.total_frames
            self.draw()
        self.canvas.after(1000 // self.fps, self.tick)

    def on_key(self, e):
        k = e.keysym.lower()
        if k in ("q", "escape"):
            self.canvas.winfo_toplevel().destroy()
        elif k == "space":
            self.playing = not self.playing
            self.draw()
        elif k == "r":
            self.frame = 0
            self.draw()
        elif k == "right":
            self.frame = min(self.frame + 1, self.total_frames - 1)
            self.playing = False
            self.draw()
        elif k == "left":
            self.frame = max(self.frame - 1, 0)
            self.playing = False
            self.draw()
        elif k == "e":
            export_ron(
                self.export_path,
                self.states,
                self.fps,
                self.total_frames,
                self.pivot_x,
                self.pivot_y,
                160,
            )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--frames", type=int, default=1200)
    ap.add_argument("--fps", type=int, default=20)
    ap.add_argument("--export", type=str, default="pendulum.ron")
    ap.add_argument("--headless", action="store_true")
    args = ap.parse_args()

    states, pivot_x, pivot_y, arm_len = simulate(args.frames, args.fps)

    if args.headless:
        export_ron(
            args.export, states, args.fps, args.frames, pivot_x, pivot_y, arm_len
        )
        return

    root = tk.Tk()
    App(root, states, args.fps, args.frames, args.export, pivot_x, pivot_y, arm_len)
    root.mainloop()


if __name__ == "__main__":
    main()
