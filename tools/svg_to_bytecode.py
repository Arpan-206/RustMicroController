#!/usr/bin/env python3
"""
Convert a limited SVG subset into Rust bytecode for the framebuffer renderer.

Supported elements:
  - line, rect, circle, polyline, polygon
  - path with M/L/Z commands only (absolute or relative)

The output is written to src/svg_data.rs by default.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import xml.etree.ElementTree as ET

NUM_RE = re.compile(r"[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?")
CMD_RE = re.compile(r"[MLZmlz]|[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?")

DEFAULT_COL = 0xFF

NAMED_COLORS = {
    "black": (0, 0, 0),
    "white": (255, 255, 255),
    "red": (255, 0, 0),
    "green": (0, 255, 0),
    "blue": (0, 0, 255),
    "yellow": (255, 255, 0),
    "cyan": (0, 255, 255),
    "magenta": (255, 0, 255),
}


def strip_ns(tag: str) -> str:
    if "}" in tag:
        return tag.split("}", 1)[1]
    return tag


def parse_float(val: str | None, default: float = 0.0) -> float:
    if not val:
        return default
    m = NUM_RE.search(val)
    return float(m.group(0)) if m else default


def rgb332(r: int, g: int, b: int) -> int:
    return ((r >> 5) << 5) | ((g >> 5) << 2) | (b >> 6)


def parse_color(val: str | None) -> int | None:
    if val is None:
        return None
    s = val.strip().lower()
    if s in ("none", "transparent"):
        return None
    if s in NAMED_COLORS:
        r, g, b = NAMED_COLORS[s]
        return rgb332(r, g, b)
    if s.startswith("#"):
        hexval = s[1:]
        if len(hexval) == 3:
            r = int(hexval[0] * 2, 16)
            g = int(hexval[1] * 2, 16)
            b = int(hexval[2] * 2, 16)
            return rgb332(r, g, b)
        if len(hexval) == 6:
            r = int(hexval[0:2], 16)
            g = int(hexval[2:4], 16)
            b = int(hexval[4:6], 16)
            return rgb332(r, g, b)
    if s.startswith("rgb(") and s.endswith(")"):
        inner = s[4:-1]
        parts = [p.strip() for p in inner.split(",")]
        if len(parts) >= 3:
            rgb_vals = []
            for p in parts[:3]:
                if p.endswith("%"):
                    pct = parse_float(p)
                    rgb_vals.append(int(max(0.0, min(100.0, pct)) * 2.55))
                else:
                    rgb_vals.append(int(max(0.0, min(255.0, parse_float(p)))))
            return rgb332(rgb_vals[0], rgb_vals[1], rgb_vals[2])
    return None


def pick_color(elem: ET.Element, prefer: str) -> int:
    stroke = parse_color(elem.get("stroke"))
    fill = parse_color(elem.get("fill"))
    if prefer == "stroke":
        if stroke is not None:
            return stroke
        if fill is not None:
            return fill
    else:
        if fill is not None:
            return fill
        if stroke is not None:
            return stroke
    return DEFAULT_COL


def parse_points(points: str | None) -> list[tuple[float, float]]:
    nums = [float(n) for n in NUM_RE.findall(points or "")]
    if len(nums) < 2:
        return []
    if len(nums) % 2 != 0:
        nums = nums[:-1]
    return list(zip(nums[0::2], nums[1::2]))


def parse_path(d: str | None) -> list[tuple[float, float, float, float]]:
    d = d or ""
    commands = re.findall(r"[A-Za-z]", d)
    for c in commands:
        if c not in ("M", "m", "L", "l", "Z", "z"):
            raise ValueError(f"Unsupported path command: {c}")

    tokens = CMD_RE.findall(d)
    segments: list[tuple[float, float, float, float]] = []
    i = 0
    cmd: str | None = None
    cur_x = 0.0
    cur_y = 0.0
    start_x = 0.0
    start_y = 0.0

    def is_cmd(tok: str) -> bool:
        return tok in ("M", "m", "L", "l", "Z", "z")

    while i < len(tokens):
        tok = tokens[i]
        if is_cmd(tok):
            cmd = tok
            i += 1
            if cmd in ("Z", "z"):
                if (cur_x, cur_y) != (start_x, start_y):
                    segments.append((cur_x, cur_y, start_x, start_y))
                    cur_x, cur_y = start_x, start_y
                cmd = None
                continue
        if cmd in ("M", "m"):
            first = True
            while i < len(tokens) and not is_cmd(tokens[i]):
                if i + 1 >= len(tokens):
                    return segments
                x = float(tokens[i])
                y = float(tokens[i + 1])
                i += 2
                if cmd == "m":
                    x += cur_x
                    y += cur_y
                if first:
                    cur_x, cur_y = x, y
                    start_x, start_y = x, y
                    first = False
                else:
                    segments.append((cur_x, cur_y, x, y))
                    cur_x, cur_y = x, y
        elif cmd in ("L", "l"):
            while i < len(tokens) and not is_cmd(tokens[i]):
                if i + 1 >= len(tokens):
                    return segments
                x = float(tokens[i])
                y = float(tokens[i + 1])
                i += 2
                if cmd == "l":
                    x += cur_x
                    y += cur_y
                segments.append((cur_x, cur_y, x, y))
                cur_x, cur_y = x, y
        else:
            raise ValueError(f"Unsupported or missing path command in: {d}")

    return segments


def clamp_int(val: float, lo: int, hi: int) -> int:
    return max(lo, min(hi, int(round(val))))


def emit_u16(out: list[int], val: int) -> None:
    val &= 0xFFFF
    out.append(val & 0xFF)
    out.append((val >> 8) & 0xFF)


def main() -> int:
    parser = argparse.ArgumentParser(description="Convert SVG to Rust bytecode")
    parser.add_argument("input", help="Input SVG path")
    parser.add_argument(
        "-o",
        "--output",
        default=os.path.join("src", "svg_data.rs"),
        help="Output Rust file (default: src/svg_data.rs)",
    )
    args = parser.parse_args()

    tree = ET.parse(args.input)
    root = tree.getroot()

    ops: list[tuple] = []
    min_x = None
    max_x = None
    min_y = None
    max_y = None

    def update_bounds(x: float, y: float) -> None:
        nonlocal min_x, max_x, min_y, max_y
        if min_x is None or x < min_x:
            min_x = x
        if max_x is None or x > max_x:
            max_x = x
        if min_y is None or y < min_y:
            min_y = y
        if max_y is None or y > max_y:
            max_y = y

    for elem in root.iter():
        tag = strip_ns(elem.tag)
        if tag == "line":
            x1 = parse_float(elem.get("x1"))
            y1 = parse_float(elem.get("y1"))
            x2 = parse_float(elem.get("x2"))
            y2 = parse_float(elem.get("y2"))
            col = pick_color(elem, "stroke")
            ops.append(("line", x1, y1, x2, y2, col))
            update_bounds(x1, y1)
            update_bounds(x2, y2)
        elif tag == "rect":
            x = parse_float(elem.get("x"))
            y = parse_float(elem.get("y"))
            w = parse_float(elem.get("width"))
            h = parse_float(elem.get("height"))
            fill_col = parse_color(elem.get("fill"))
            stroke_col = parse_color(elem.get("stroke"))
            if fill_col is not None:
                ops.append(("rect", x, y, w, h, fill_col))
            if stroke_col is not None:
                ops.append(("line", x, y, x + w, y, stroke_col))
                ops.append(("line", x + w, y, x + w, y + h, stroke_col))
                ops.append(("line", x + w, y + h, x, y + h, stroke_col))
                ops.append(("line", x, y + h, x, y, stroke_col))
            update_bounds(x, y)
            update_bounds(x + w, y + h)
        elif tag == "circle":
            cx = parse_float(elem.get("cx"))
            cy = parse_float(elem.get("cy"))
            r = parse_float(elem.get("r"))
            col = parse_color(elem.get("stroke"))
            if col is None:
                col = parse_color(elem.get("fill"))
            if col is None:
                col = DEFAULT_COL
            ops.append(("circle", cx, cy, r, col))
            update_bounds(cx - r, cy - r)
            update_bounds(cx + r, cy + r)
        elif tag in ("polyline", "polygon"):
            points = parse_points(elem.get("points"))
            if len(points) >= 2:
                col = pick_color(elem, "stroke")
                for i in range(len(points) - 1):
                    x1, y1 = points[i]
                    x2, y2 = points[i + 1]
                    ops.append(("line", x1, y1, x2, y2, col))
                if tag == "polygon":
                    x1, y1 = points[-1]
                    x2, y2 = points[0]
                    ops.append(("line", x1, y1, x2, y2, col))
                for x, y in points:
                    update_bounds(x, y)
        elif tag == "path":
            segments = parse_path(elem.get("d"))
            if segments:
                col = pick_color(elem, "stroke")
                for x1, y1, x2, y2 in segments:
                    ops.append(("line", x1, y1, x2, y2, col))
                    update_bounds(x1, y1)
                    update_bounds(x2, y2)
        else:
            continue

    if min_x is None or max_x is None or min_y is None or max_y is None:
        min_x = 0.0
        min_y = 0.0
        max_x = 1.0
        max_y = 1.0

    width = max_x - min_x
    height = max_y - min_y
    if width <= 0.0:
        width = 1.0
    if height <= 0.0:
        height = 1.0

    scale_x = 639.0 / width
    scale_y = 479.0 / height
    scale = min(scale_x, scale_y)

    bytecode: list[int] = []

    for op in ops:
        kind = op[0]
        if kind == "line":
            _, x1, y1, x2, y2, col = op
            sx1 = clamp_int((x1 - min_x) * scale, 0, 639)
            sy1 = clamp_int((y1 - min_y) * scale, 0, 479)
            sx2 = clamp_int((x2 - min_x) * scale, 0, 639)
            sy2 = clamp_int((y2 - min_y) * scale, 0, 479)
            bytecode.append(0x02)
            emit_u16(bytecode, sx1)
            emit_u16(bytecode, sy1)
            emit_u16(bytecode, sx2)
            emit_u16(bytecode, sy2)
            bytecode.append(int(col) & 0xFF)
        elif kind == "rect":
            _, x, y, w, h, col = op
            sx = clamp_int((x - min_x) * scale, 0, 639)
            sy = clamp_int((y - min_y) * scale, 0, 479)
            sw = clamp_int(w * scale, 0, 640)
            sh = clamp_int(h * scale, 0, 480)
            bytecode.append(0x03)
            emit_u16(bytecode, sx)
            emit_u16(bytecode, sy)
            emit_u16(bytecode, sw)
            emit_u16(bytecode, sh)
            bytecode.append(int(col) & 0xFF)
        elif kind == "circle":
            _, cx, cy, r, col = op
            scx = clamp_int((cx - min_x) * scale, 0, 639)
            scy = clamp_int((cy - min_y) * scale, 0, 479)
            sr = clamp_int(r * scale, 0, 479)
            bytecode.append(0x04)
            emit_u16(bytecode, scx)
            emit_u16(bytecode, scy)
            emit_u16(bytecode, sr)
            bytecode.append(int(col) & 0xFF)

    bytecode.append(0xFF)

    with open(args.output, "w", encoding="utf-8") as f:
        f.write("// Auto-generated by tools/svg_to_bytecode.py\n")
        f.write(f"// Source: {args.input}\n")
        f.write("pub static SVG_BYTECODE: &[u8] = &[\n")
        for i, b in enumerate(bytecode):
            if i % 12 == 0:
                f.write("    ")
            f.write(f"0x{b:02X}, ")
            if i % 12 == 11:
                f.write("\n")
        if len(bytecode) % 12 != 0:
            f.write("\n")
        f.write("];\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
