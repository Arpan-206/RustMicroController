#!/usr/bin/env python3
"""
physanim.py — bouncy ball physics previewer + RON exporter
Uses pymunk for high-quality physics simulation.
Usage:
  python3 physanim.py                        # run with defaults
  python3 physanim.py --balls 4 --frames 1200 --fps 30
  python3 physanim.py --headless --export out.ron

Controls:
  SPACE       play / pause
  LEFT/RIGHT  step one frame
  R           rewind
  E           export .ron
  Q / ESC     quit
  Click       add a ball at cursor
"""

import argparse
import math
import os
import random
import sys
import tkinter as tk

import pymunk

W, H = 640, 480
MIN_R, MAX_R = 15, 40

# RGB332: r=0-7 (3 bits), g=0-7 (3 bits), b=0-3 (2 bits)
BALL_COLOURS = [
    (7, 0, 0),  # red
    (0, 7, 3),  # cyan
    (7, 7, 0),  # yellow
    (5, 0, 3),  # magenta
    (0, 7, 0),  # green
    (7, 3, 0),  # orange
    (7, 7, 3),  # white
    (0, 0, 3),  # blue
]


def r332_to_hex(r, g, b):
    ri = int((r / 7.0) * 255)
    gi = int((g / 7.0) * 255)
    bi = int((b / 3.0) * 255)
    return f"#{ri:02x}{gi:02x}{bi:02x}"


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


class BallDef:
    """Stores initial configuration for a ball to allow re-simulation."""

    def __init__(self, x, y, r, vx, vy, colour, is_static=False):
        self.x, self.y = float(x), float(y)
        self.r = r
        self.vx, self.vy = float(vx), float(vy)
        self.colour = colour
        self.is_static = is_static


def make_balls(n, seed=42):
    rng = random.Random(seed)
    balls = []

    # Create a bowl out of static balls
    bowl_center_x = W / 2
    bowl_center_y = H / 2 - 50
    bowl_radius = 200
    num_bowl_balls = 45
    bowl_ball_r = 10

    for i in range(num_bowl_balls):
        # Semi-circle from angle 0 to pi (bottom half)
        # In screen coords, +y is down. So we want angles from 0 to pi.
        a = math.pi * i / (num_bowl_balls - 1)
        x = bowl_center_x - bowl_radius * math.cos(a)
        y = bowl_center_y + bowl_radius * math.sin(a)
        # Use a neutral grey-ish colour
        balls.append(BallDef(x, y, bowl_ball_r, 0, 0, (4, 4, 2), is_static=True))

    for i in range(n):
        r = rng.randint(MIN_R, MAX_R)
        x = rng.uniform(W // 2 - 50, W // 2 + 50)
        y = rng.uniform(20, H // 4)
        vx = rng.uniform(-2, 2)
        vy = rng.uniform(0, 2)
        col = BALL_COLOURS[i % len(BALL_COLOURS)]
        balls.append(BallDef(x, y, r, vx, vy, col))
    return balls


def simulate(balls, total_frames, fps=30):
    space = pymunk.Space()
    # Gravity tuned to be slow/floaty
    space.gravity = (0, 90)

    # Screen boundaries
    static_lines = [
        pymunk.Segment(space.static_body, (0, 0), (W, 0), 0.0),
        pymunk.Segment(space.static_body, (0, H), (W, H), 0.0),
        pymunk.Segment(space.static_body, (0, 0), (0, H), 0.0),
        pymunk.Segment(space.static_body, (W, 0), (W, H), 0.0),
    ]
    for line in static_lines:
        line.elasticity = 0.98
        line.friction = 0.0
    space.add(*static_lines)

    bodies = []
    for b in balls:
        if b.is_static:
            shape = pymunk.Circle(space.static_body, b.r, offset=(b.x, b.y))
            shape.elasticity = 0.5
            shape.friction = 0.5
            space.add(shape)
            bodies.append(None)
        else:
            # Give mass proportional to area so they interact realistically
            mass = (b.r**2) / 100.0
            moment = pymunk.moment_for_circle(mass, 0, b.r)
            body = pymunk.Body(mass, moment)
            body.position = (b.x, b.y)
            # Scale initial velocity to match per-second values
            body.velocity = (b.vx * fps, b.vy * fps)

            shape = pymunk.Circle(body, b.r)
            shape.elasticity = 0.8
            shape.friction = 0.5

            space.add(body, shape)
            bodies.append(body)

    states = [[] for _ in balls]
    dt = 1.0 / fps
    for _ in range(total_frames):
        space.step(dt)
        for i, body in enumerate(bodies):
            if body is None:
                states[i].append((int(balls[i].x), int(balls[i].y), balls[i].r))
            else:
                states[i].append(
                    (int(body.position.x), int(body.position.y), balls[i].r)
                )

    return states


def export_ron(path, balls, states, fps, total_frames):
    lines = [
        "(",
        "    background: (r: 0, g: 0, b: 0),",
        f"    fps: {fps},",
        "    objects: [",
    ]
    # Filter out static balls for the export
    export_balls = [(i, b) for i, b in enumerate(balls) if not b.is_static]

    for i, b in export_balls:
        r, g, bl = b.colour
        lines.append(
            f'        Circle(id: "ball{i}", colour: (r: {r}, g: {g}, b: {bl})),'
        )
    lines.append("    ],")
    lines.append("    keyframes: [")

    STEP = max(1, total_frames // 60)
    frames_to_emit = sorted(set(range(0, total_frames, STEP)) | {total_frames - 1})

    for i, _ in export_balls:
        for f in frames_to_emit:
            cx, cy, r = states[i][f]
            cx = clamp(cx, 0, 639)
            cy = clamp(cy, 0, 479)
            lines.append(
                f'        AtCircle(frame: {f}, id: "ball{i}", cx: {cx}, cy: {cy}, r: {r}),'
            )

    lines.append("    ],")
    lines.append(")")

    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"Exported {len(export_balls)} balls x {total_frames} frames -> {path}")


class App:
    def __init__(self, root, balls, total_frames, fps, export_path):
        self.balls = balls
        self.total_frames = total_frames
        self.fps = fps
        self.export_path = export_path
        self.frame = 0
        self.playing = True
        self.states = simulate(balls, total_frames, fps)

        root.title("FPGA Physics Animator (Pymunk)")
        root.resizable(False, False)
        root.bind("<KeyPress>", self.on_key)

        self.canvas = tk.Canvas(
            root, width=W, height=H, bg="black", highlightthickness=0
        )
        self.canvas.pack()
        self.canvas.bind("<Button-1>", self.on_click)

        self.hud = tk.Label(
            root, text="", bg="#111", fg="#ccc", font=("Courier", 11), anchor="w"
        )
        self.hud.pack(fill="x", padx=4, pady=2)

        self.draw()
        self.tick()

    def draw(self):
        self.canvas.delete("all")
        for i, b in enumerate(self.balls):
            cx, cy, r = self.states[i][self.frame]
            self.canvas.create_oval(
                cx - r, cy - r, cx + r, cy + r, fill=r332_to_hex(*b.colour), outline=""
            )
        status = "▶" if self.playing else "⏸"
        self.hud.config(
            text=(
                f"{status}  frame {self.frame}/{self.total_frames - 1}  |  "
                "SPACE play/pause   ←→ step   R rewind   E export   Q quit   click adds ball"
            )
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
                self.export_path, self.balls, self.states, self.fps, self.total_frames
            )

    def on_click(self, e):
        rng = random.Random()
        r = rng.randint(MIN_R, MAX_R)
        vx = rng.uniform(-5, 5)
        vy = rng.uniform(-8, -2)
        col = BALL_COLOURS[len(self.balls) % len(BALL_COLOURS)]
        self.balls.append(BallDef(float(e.x), float(e.y), r, vx, vy, col))
        self.states = simulate(self.balls, self.total_frames, self.fps)
        self.draw()


def main():
    default_export = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "physics.ron"
    )
    ap = argparse.ArgumentParser()
    ap.add_argument("--balls", type=int, default=10)
    ap.add_argument("--frames", type=int, default=1200)
    ap.add_argument("--fps", type=int, default=20)
    ap.add_argument("--export", type=str, default=default_export)
    ap.add_argument("--headless", action="store_true")
    args = ap.parse_args()

    balls = make_balls(args.balls)

    if args.headless:
        states = simulate(balls, args.frames, args.fps)
        export_ron(args.export, balls, states, args.fps, args.frames)
        return

    root = tk.Tk()
    App(root, balls, args.frames, args.fps, args.export)
    root.mainloop()


if __name__ == "__main__":
    main()
