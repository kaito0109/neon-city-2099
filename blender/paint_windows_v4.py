"""Paint the v4 building window textures (PIL only, no Blender).

Design rule that kills the "mosaic tile" look: each texture is a
TILE meant to repeat at a fixed real-world size, and the Blender
generator maps wall UVs in metres (u = width / TILE_W, v = height /
TILE_H), so a window is always ~1.15 m wide x 1.9 m tall on every
building, at every scale. One tile = 4 windows x 4 floors
(TILE_W 6.8 m, TILE_H 12.4 m, floor 3.1 m).

Variants per style differ in lit ratio / temperature so two
neighbouring towers never share the same light pattern.

Outputs (assets/textures/): win_ent_a.jpg, win_ent_b.jpg,
win_kit_a.jpg, win_kit_b.jpg, win_mil_a.jpg, win_mil_b.jpg
"""
import math
import os
import random

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
SIZE = 512
CELL = SIZE // 4  # 128 px per window cell


def _speckle(d, rng, box, n, colors, smin=1, smax=3):
    x0, y0, x1, y1 = box
    for _ in range(n):
        x = rng.uniform(x0, x1)
        y = rng.uniform(y0, y1)
        s = rng.uniform(smin, smax)
        c = colors[rng.randrange(len(colors))]
        # Draw wrapped so the tile stays seamless.
        for dx in (-SIZE, 0, SIZE):
            for dy in (-SIZE, 0, SIZE):
                d.rectangle([x + dx, y + dy, x + dx + s, y + dy + s], fill=c)


def _glass_color(rng, kind):
    r = rng.random()
    if kind == "ent":
        if r < 0.68:
            return (22, 26, 34)          # dark
        if r < 0.90:
            return (216, 150 + rng.randint(-14, 14), 88)    # warm lit, dimmer
        return (122, 152, 182)           # cool lit, dimmer
    if kind == "kit":
        if r < 0.55:
            return (24, 28, 38)
        if r < 0.74:
            return (228, 164, 104)
        if r < 0.88:
            return (92, 158, 172)        # cyan tint glass, deeper
        return (186, 112, 150)           # pink tint glass, deeper
    # mil: mostly dark reflective, sparse office light
    if r < 0.78:
        return (13, 17, 24)
    if r < 0.93:
        return (148, 174, 198)           # cool office, dimmer
    return (214, 158, 100)


def _window(d, rng, cx, cy, kind, dim):
    """One window inside cell (cx, cy) in px. Frame + glass + detail."""
    x0 = cx + 20
    x1 = cx + CELL - 20
    y0 = cy + 20
    y1 = cy + CELL - 34
    # Sill shadow / grime below the window.
    d.rectangle([x0 - 3, y1 + 3, x1 + 3, y1 + 10], fill=(0, 0, 0, 60))
    # v5: rain drip running down the wall from the sill — the
    # streak that makes a facade read as weathered, not printed.
    dx = rng.uniform(x0 + 4, x1 - 10)
    d.rectangle([dx, y1 + 9, dx + rng.uniform(3, 7),
                 y1 + 9 + rng.uniform(14, 38)], fill=(0, 0, 0, 44))
    # Frame.
    frame = (12, 13, 16) if kind != "kit" else (148, 152, 158)
    d.rectangle([x0 - 5, y0 - 5, x1 + 5, y1 + 5], fill=frame)
    g = _glass_color(rng, kind)
    if dim:
        g = tuple(int(v * 0.55) for v in g)
    # Per-window brightness jitter so no two lit windows match.
    jit = rng.uniform(0.85, 1.08)
    g = tuple(min(255, int(v * jit)) for v in g)
    d.rectangle([x0, y0, x1, y1], fill=g)
    # Recess shading: dark reveal at the top, faint bounce at the
    # sill — the window sits IN the wall instead of ON it.
    d.rectangle([x0, y0, x1, y0 + 4], fill=(0, 0, 0, 96))
    d.rectangle([x0, y0, x0 + 4, y1], fill=(0, 0, 0, 64))
    d.rectangle([x0, y1 - 3, x1, y1], fill=(255, 255, 255, 22))
    lit = sum(g) > 190
    if not lit:
        r0 = rng.random()
        if r0 < 0.26:
            # Closed blinds: pale slats over the whole pane.
            slat = tuple(min(255, int(v * 1.9 + 52)) for v in g)
            for yy in range(int(y0) + 4, int(y1) - 4, 8):
                d.rectangle([x0 + 3, yy, x1 - 3, yy + 3], fill=slat)
        elif r0 < 0.40:
            # AC unit in the window corner: grey box + fan disc.
            ax, ay = x1 - 34, y1 - 28
            d.rectangle([ax, ay, ax + 30, ay + 24], fill=(96, 100, 108))
            d.rectangle([ax, ay, ax + 30, ay + 3], fill=(64, 68, 76))
            d.ellipse([ax + 6, ay + 5, ax + 24, ay + 23], fill=(40, 44, 52))
        elif r0 < 0.52:
            # Curtains: soft vertical bands at both edges.
            cur = tuple(min(255, int(v * 1.6 + 34)) for v in g)
            d.rectangle([x0 + 2, y0 + 2, x0 + 16, y1 - 2], fill=cur)
            d.rectangle([x1 - 16, y0 + 2, x1 - 2, y1 - 2], fill=cur)
    if lit:
        # Interior depth: darker header + a hint of blinds or a
        # silhouette on some windows so lit cells are not flat.
        d.rectangle([x0, y0, x1, y0 + 10], fill=tuple(int(v * 0.72) for v in g))
        if rng.random() < 0.16:
            # TV / monitor glow washing the pane cool blue.
            d.rectangle([x0, y0, x1, y1], fill=(96, 148, 208, 52))
        r = rng.random()
        if r < 0.38:
            for yy in range(int(y0) + 16, int(y1) - 8, 9):
                d.line([x0 + 3, yy, x1 - 3, yy], fill=tuple(int(v * 0.62) for v in g), width=3)
        elif r < 0.52:
            sx = rng.uniform(x0 + 14, x1 - 30)
            d.rectangle([sx, y0 + 26, sx + 16, y1], fill=(20, 16, 14))
        # Centre mullion.
        d.rectangle([(x0 + x1) / 2 - 2, y0, (x0 + x1) / 2 + 2, y1],
                    fill=tuple(int(v * 0.55) for v in g))
    else:
        # Dark glass: faint top-down gradient + one diagonal sheen.
        for i in range(5):
            gg = tuple(min(255, int(v * (1.0 + 0.16 * (4 - i)))) for v in g)
            d.rectangle([x0, y0 + i * 6, x1, y0 + i * 6 + 6], fill=gg)
        d.polygon([(x0 + 8, y1), (x0 + 30, y0), (x0 + 44, y0), (x0 + 22, y1)],
                  fill=tuple(min(255, int(v * 1.9 + 14)) for v in g))


def _base(rng, kind):
    img = Image.new("RGB", (SIZE, SIZE), (40, 42, 50))
    d = ImageDraw.Draw(img, "RGBA")
    if kind == "ent":
        base = (72, 74, 80)
        img.paste(base, (0, 0, SIZE, SIZE))
        _speckle(d, rng, (0, 0, SIZE, SIZE), 2600,
                 [(62, 64, 70), (84, 86, 90), (54, 56, 62), (90, 88, 82)])
        # Weather streaks running down from random points.
        for _ in range(26):
            x = rng.uniform(0, SIZE)
            ln = rng.uniform(30, 150)
            d.rectangle([x, 0, x + rng.uniform(2, 6), ln], fill=(44, 46, 50, 70))
        # Floor shadow lines.
        for f in range(4):
            y = (f + 1) * CELL - 3
            d.rectangle([0, y, SIZE, y + 3], fill=(46, 47, 52))
        # Concrete panel seams: vertical joints at cell borders.
        for cx in range(4):
            x = cx * CELL
            d.rectangle([x, 0, x + 2, SIZE], fill=(40, 41, 46, 90))
    elif kind == "kit":
        base = (100, 106, 114)
        img.paste(base, (0, 0, SIZE, SIZE))
        _speckle(d, rng, (0, 0, SIZE, SIZE), 900,
                 [(90, 96, 104), (112, 118, 124), (82, 88, 96)])
        # Panel seams per cell + slight per-cell tint.
        for cx in range(4):
            for cy in range(4):
                t = rng.randint(-9, 9)
                d.rectangle([cx * CELL, cy * CELL, cx * CELL + CELL, cy * CELL + CELL],
                            fill=(t, t, t, 26))
                d.rectangle([cx * CELL, cy * CELL, cx * CELL + CELL, cy * CELL + 3],
                            fill=(64, 70, 78))
    else:  # mil curtain glass: the wall IS glass panes
        base = (13, 16, 22)
        img.paste(base, (0, 0, SIZE, SIZE))
        _speckle(d, rng, (0, 0, SIZE, SIZE), 500,
                 [(18, 22, 30), (10, 13, 18), (22, 27, 36)])
        for f in range(4):
            y = (f + 1) * CELL - 2
            d.rectangle([0, y, SIZE, y + 2], fill=(38, 44, 54))
        # Curtain-wall mullion grid: thin verticals every half cell
        # so the glass reads as panes with frames, not one sheet.
        for mx in range(0, SIZE, CELL // 2):
            d.rectangle([mx, 0, mx + 2, SIZE], fill=(44, 52, 64, 160))
    return img, d


def paint(kind, variant, seed):
    rng = random.Random(seed)
    img, d = _base(rng, kind)
    dim = variant == "b"
    for cx in range(4):
        for cy in range(4):
            _window(d, rng, cx * CELL, cy * CELL, kind, dim and rng.random() < 0.6)
    path = os.path.join(OUT, "win_%s_%s.jpg" % (kind, variant))
    img.save(path, quality=88)
    print("painted", path)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    paint("ent", "a", 101)
    paint("ent", "b", 202)
    paint("kit", "a", 303)
    paint("kit", "b", 404)
    paint("mil", "a", 505)
    paint("mil", "b", 606)
