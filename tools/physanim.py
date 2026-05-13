#!/usr/bin/env python3
"""
physanim.py — bouncy ball physics previewer + RON exporter
Usage:
  python3 physanim.py                        # run with defaults
  python3 physanim.py --balls 4 --frames 300 --fps 30
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
import random
import sys
import tkinter as tk

W, H = 640, 480
GRAVITY = 0.1
DAMPEN = 0.98
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


class Ball:
    def __init__(self, x, y, r, vx, vy, colour):
        self.x, self.y = float(x), float(y)
        self.r = r
        self.vx, self.vy = float(vx), float(vy)
        self.colour = colour

    def step(self):
        self.vy += GRAVITY
        self.x += self.vx
        self.y += self.vy

        if self.x - self.r < 0:
            self.x = float(self.r)
            self.vx = abs(self.vx) * DAMPEN
        if self.x + self.r > W:
            self.x = float(W - self.r)
            self.vx = -abs(self.vx) * DAMPEN
        if self.y - self.r < 0:
            self.y = float(self.r)
            self.vy = abs(self.vy) * DAMPEN
        if self.y + self.r > H:
            self.y = float(H - self.r)
            self.vy = -abs(self.vy) * DAMPEN

        if abs(self.vx) < 0.3:
            self.vx = 0.0
        if abs(self.vy) < 0.3 and abs(self.y + self.r - H) < 1:
            self.vy = 0.0


def make_balls(n, seed=42):
    rng = random.Random(seed)
    balls = []
    for i in range(n):
        r = rng.randint(MIN_R, MAX_R)
        x = rng.uniform(r, W - r)
        y = rng.uniform(r, H // 2)
        vx = rng.uniform(-6, 6)
        vy = rng.uniform(-4, 2)
        col = BALL_COLOURS[i % len(BALL_COLOURS)]
        balls.append(Ball(x, y, r, vx, vy, col))
    return balls


def simulate(balls, total_frames):
    # snapshot initial state so we can re-simulate from scratch later
    snapshots = [(b.x, b.y, b.r, b.vx, b.vy, b.colour) for b in balls]
    states = [[] for _ in balls]
    # reset to initial positions
    for b, (x, y, r, vx, vy, col) in zip(balls, snapshots):
        b.x, b.y, b.r, b.vx, b.vy = x, y, r, vx, vy
    for _ in range(total_frames):
        for i, b in enumerate(balls):
            states[i].append((int(b.x), int(b.y), b.r))
            b.step()
    return states


def export_ron(path, balls, states, fps, total_frames):
    lines = [
        "(",
        "    background: (r: 0, g: 0, b: 0),",
        f"    fps: {fps},",
        "    objects: [",
    ]
    for i, b in enumerate(balls):
        r, g, bl = b.colour
        lines.append(
            f'        Circle(id: "ball{i}", colour: (r: {r}, g: {g}, b: {bl})),'
        )
    lines.append("    ],")
    lines.append("    keyframes: [")

    STEP = max(1, total_frames // 60)
    frames_to_emit = sorted(set(range(0, total_frames, STEP)) | {total_frames - 1})

    for i in range(len(balls)):
        for f in frames_to_emit:
            cx, cy, r = states[i][f]
            lines.append(
                f'        AtCircle(frame: {f}, id: "ball{i}", cx: {cx}, cy: {cy}, r: {r}),'
            )

    lines.append("    ],")
    lines.append(")")

    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"Exported {len(balls)} balls x {total_frames} frames -> {path}")


class App:
    def __init__(self, root, balls, total_frames, fps, export_path):
        self.balls = balls
        self.total_frames = total_frames
        self.fps = fps
        self.export_path = export_path
        self.frame = 0
        self.playing = True
        self.states = simulate(balls, total_frames)

        root.title("FPGA Physics Animator")
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
        self.balls.append(Ball(float(e.x), float(e.y), r, vx, vy, col))
        self.states = simulate(self.balls, self.total_frames)
        self.draw()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--balls", type=int, default=5)
    ap.add_argument("--frames", type=int, default=1200)
    ap.add_argument("--fps", type=int, default=10)
    ap.add_argument("--export", type=str, default="physics.ron")
    ap.add_argument("--headless", action="store_true")
    args = ap.parse_args()

    balls = make_balls(args.balls)

    if args.headless:
        states = simulate(balls, args.frames)
        export_ron(args.export, balls, states, args.fps, args.frames)
        return

    root = tk.Tk()
    App(root, balls, args.frames, args.fps, args.export)
    root.mainloop()


if __name__ == "__main__":
    main()
