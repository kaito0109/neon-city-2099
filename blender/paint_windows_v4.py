"""Paint the v4 building window textures (PIL only, no Blender).

Design rule that kills the "mosaic tile" look: each texture is a
TILE meant to repeat at a fixed real-world size, and the Blender
generator maps wall UVs in metres (u = width / TILE_W, v = height /
TILE_H), so a window is always ~1.15 m wide x 1.9 m tall on every
building, at every scale. One tile = 4 windows x 4 floors
(TILE_W 6.8 m, TILE_H 12.4 m, floor 3.1 m).

Variants per style differ in lit ratio / temperature so two
neighbouring towers never share the same light pattern.

v5.9: 512 -> 1024 px (a window is now ~176 px wide instead of 88),
with bevelled frames, transoms, deeper lit interiors and stronger
weathering — plus a height canvas painted in parallel (same layout
decisions, no extra rng) that is converted to a tangent-space
normal map (win_*_n.jpg) so the facades catch real light/shadow
relief instead of reading as printed paper.

Outputs (assets/textures/): win_ent_a.jpg, win_ent_b.jpg,
win_kit_a.jpg, win_kit_b.jpg, win_mil_a.jpg, win_mil_b.jpg
and the matching win_*_n.jpg normal maps.
"""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
SIZE = 1024
CELL = SIZE // 4  # 256 px per window cell
AREA = (SIZE // 512) ** 2  # speckle density scale vs the 512 era


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


def _window(d, dh, rng, cx, cy, kind, dim):
    """One window inside cell (cx, cy) in px. Frame + glass + detail.
    dh is the height canvas draw (greyscale: wall=128, glass=64,
    frame=175, sill=205) painted with the same decisions."""
    x0 = cx + 40
    x1 = cx + CELL - 40
    y0 = cy + 40
    y1 = cy + CELL - 68
    # --- height: recess + frame + sill (under the albedo detail) ---
    dh.rectangle([x0 - 12, y0 - 12, x1 + 12, y1 + 12], fill=172)
    dh.rectangle([x0, y0, x1, y1], fill=64)
    dh.rectangle([x0 - 16, y1 + 12, x1 + 16, y1 + 26], fill=205)
    # --- albedo ---
    # Sill shadow / grime below the window.
    d.rectangle([x0 - 6, y1 + 6, x1 + 6, y1 + 20], fill=(0, 0, 0, 60))
    # Rain drips running down the wall from the sill — the streak
    # that makes a facade read as weathered, not printed.
    for _ in range(2):
        dx = rng.uniform(x0 + 8, x1 - 20)
        d.rectangle([dx, y1 + 18, dx + rng.uniform(6, 14),
                     y1 + 18 + rng.uniform(28, 76)], fill=(0, 0, 0, 44))
    # Frame with a slight per-window tint jitter.
    fj = rng.randint(-8, 8)
    frame = (12 + fj, 13 + fj, 16 + fj) if kind != "kit" else (148 + fj, 152 + fj, 158 + fj)
    d.rectangle([x0 - 10, y0 - 10, x1 + 10, y1 + 10], fill=frame)
    # Frame bevel: lit top/left edges, dark bottom/right.
    d.rectangle([x0 - 10, y0 - 10, x1 + 10, y0 - 5], fill=(255, 255, 255, 42))
    d.rectangle([x0 - 10, y0 - 10, x0 - 5, y1 + 10], fill=(255, 255, 255, 26))
    d.rectangle([x0 - 10, y1 + 5, x1 + 10, y1 + 10], fill=(0, 0, 0, 72))
    g = _glass_color(rng, kind)
    if dim:
        g = tuple(int(v * 0.55) for v in g)
    # Per-window brightness jitter so no two lit windows match.
    jit = rng.uniform(0.85, 1.08)
    g = tuple(min(255, int(v * jit)) for v in g)
    d.rectangle([x0, y0, x1, y1], fill=g)
    # Glass gradient: darker header, faint bounce at the sill —
    # the window sits IN the wall instead of ON it.
    steps = 10
    for i in range(steps):
        f = i / float(steps - 1)
        shade = 0.78 + 0.30 * f
        gg = tuple(min(255, int(v * shade)) for v in g)
        yy0 = int(y0 + (y1 - y0) * i / steps)
        yy1 = int(y0 + (y1 - y0) * (i + 1) / steps)
        d.rectangle([x0, yy0, x1, yy1], fill=gg)
    d.rectangle([x0, y0, x1, y0 + 8], fill=(0, 0, 0, 96))
    d.rectangle([x0, y0, x0 + 8, y1], fill=(0, 0, 0, 64))
    d.rectangle([x0, y1 - 6, x1, y1], fill=(255, 255, 255, 22))
    # Mullions: centre vertical + a horizontal transom (height too).
    mid = (x0 + x1) / 2
    trans = y0 + (y1 - y0) * 0.42
    mull = tuple(int(v * 0.5) for v in g) if sum(g) > 190 else frame
    d.rectangle([mid - 4, y0, mid + 4, y1], fill=mull)
    d.rectangle([x0, trans - 4, x1, trans + 4], fill=mull)
    dh.rectangle([mid - 5, y0, mid + 5, y1], fill=150)
    dh.rectangle([x0, trans - 5, x1, trans + 5], fill=150)
    lit = sum(g) > 190
    if not lit:
        r0 = rng.random()
        if r0 < 0.26:
            # Closed blinds: pale slats over the whole pane.
            slat = tuple(min(255, int(v * 1.9 + 52)) for v in g)
            for yy in range(int(y0) + 8, int(y1) - 8, 16):
                d.rectangle([x0 + 6, yy, x1 - 6, yy + 6], fill=slat)
            for yy in range(int(y0) + 8, int(y1) - 8, 16):
                dh.rectangle([x0 + 4, yy, x1 - 4, yy + 7],
                             fill=104 if (yy // 16) % 2 == 0 else 84)
        elif r0 < 0.40:
            # AC unit in the window corner: grey box + fan disc +
            # louvre lines.
            ax, ay = x1 - 68, y1 - 56
            d.rectangle([ax, ay, ax + 60, ay + 48], fill=(96, 100, 108))
            d.rectangle([ax, ay, ax + 60, ay + 6], fill=(64, 68, 76))
            d.ellipse([ax + 12, ay + 10, ax + 48, ay + 46], fill=(40, 44, 52))
            for lx in range(ax + 16, ax + 46, 8):
                d.line([lx, ay + 12, lx, ay + 44], fill=(24, 26, 32), width=2)
            dh.rectangle([ax, ay, ax + 60, ay + 48], fill=188)
        elif r0 < 0.52:
            # Curtains: soft vertical bands at both edges.
            cur = tuple(min(255, int(v * 1.6 + 34)) for v in g)
            d.rectangle([x0 + 4, y0 + 4, x0 + 32, y1 - 4], fill=cur)
            d.rectangle([x1 - 32, y0 + 4, x1 - 4, y1 - 4], fill=cur)
            dh.rectangle([x0 + 4, y0 + 4, x0 + 32, y1 - 4], fill=88)
            dh.rectangle([x1 - 32, y0 + 4, x1 - 4, y1 - 4], fill=88)
        else:
            # Dark glass sheen: one soft diagonal.
            d.polygon([(x0 + 16, y1), (x0 + 60, y0), (x0 + 88, y0), (x0 + 44, y1)],
                      fill=tuple(min(255, int(v * 1.9 + 14)) for v in g))
    if lit:
        # Interior depth: darker header + details so lit cells are
        # not flat colour cards.
        d.rectangle([x0, y0, x1, y0 + 20], fill=tuple(int(v * 0.72) for v in g))
        if rng.random() < 0.16:
            # TV / monitor glow washing the pane cool blue.
            d.rectangle([x0, y0, x1, y1], fill=(96, 148, 208, 52))
        r = rng.random()
        if r < 0.38:
            # Half-lowered blinds across the top.
            for yy in range(int(y0) + 30, int(y1) - 60, 18):
                d.line([x0 + 6, yy, x1 - 6, yy], fill=tuple(int(v * 0.62) for v in g), width=6)
            for yy in range(int(y0) + 30, int(y1) - 60, 18):
                dh.rectangle([x0 + 4, yy - 3, x1 - 4, yy + 3], fill=96)
        elif r < 0.52:
            # Standing silhouette.
            sx = rng.uniform(x0 + 28, x1 - 60)
            d.rectangle([sx, y0 + 52, sx + 32, y1], fill=(20, 16, 14))
        elif r < 0.64:
            # Desk + plant silhouettes along the sill.
            d.rectangle([x0 + 20, y1 - 44, x1 - 50, y1 - 34], fill=(24, 20, 16))
            px = rng.uniform(x1 - 90, x1 - 40)
            d.rectangle([px, y1 - 66, px + 16, y1 - 40], fill=(22, 26, 18))
            d.ellipse([px - 8, y1 - 92, px + 24, y1 - 58], fill=(26, 34, 20))


def _base(rng, kind):
    img = Image.new("RGB", (SIZE, SIZE), (40, 42, 50))
    d = ImageDraw.Draw(img, "RGBA")
    himg = Image.new("L", (SIZE, SIZE), 128)
    dh = ImageDraw.Draw(himg)
    # Low-amplitude wall noise on the height canvas (wrapped).
    _speckle(dh, rng, (0, 0, SIZE, SIZE), 1500 * AREA, [118, 124, 132, 138],
             smin=2, smax=5)
    if kind == "ent":
        base = (72, 74, 80)
        img.paste(base, (0, 0, SIZE, SIZE))
        _speckle(d, rng, (0, 0, SIZE, SIZE), 2600 * AREA,
                 [(62, 64, 70), (84, 86, 90), (54, 56, 62), (90, 88, 82)],
                 smin=2, smax=5)
        # Weather streaks running down from random points.
        for _ in range(26 * AREA):
            x = rng.uniform(0, SIZE)
            ln = rng.uniform(60, 300)
            d.rectangle([x, 0, x + rng.uniform(4, 12), ln], fill=(44, 46, 50, 70))
        # Floor shadow lines + height grooves.
        for f in range(4):
            y = (f + 1) * CELL - 6
            d.rectangle([0, y, SIZE, y + 6], fill=(46, 47, 52))
            dh.rectangle([0, y, SIZE, y + 5], fill=102)
        # Concrete panel seams: vertical joints at cell borders.
        for cx in range(4):
            x = cx * CELL
            d.rectangle([x, 0, x + 4, SIZE], fill=(40, 41, 46, 90))
            dh.rectangle([x, 0, x + 3, SIZE], fill=106)
    elif kind == "kit":
        base = (100, 106, 114)
        img.paste(base, (0, 0, SIZE, SIZE))
        _speckle(d, rng, (0, 0, SIZE, SIZE), 900 * AREA,
                 [(90, 96, 104), (112, 118, 124), (82, 88, 96)],
                 smin=2, smax=5)
        # Panel seams per cell + slight per-cell tint.
        for cx in range(4):
            for cy in range(4):
                t = rng.randint(-9, 9)
                d.rectangle([cx * CELL, cy * CELL, cx * CELL + CELL, cy * CELL + CELL],
                            fill=(t, t, t, 26))
                d.rectangle([cx * CELL, cy * CELL, cx * CELL + CELL, cy * CELL + 6],
                            fill=(64, 70, 78))
                dh.rectangle([cx * CELL, cy * CELL, cx * CELL + CELL, cy * CELL + 4],
                             fill=108)
    else:  # mil curtain glass: the wall IS glass panes
        base = (13, 16, 22)
        img.paste(base, (0, 0, SIZE, SIZE))
        _speckle(d, rng, (0, 0, SIZE, SIZE), 500 * AREA,
                 [(18, 22, 30), (10, 13, 18), (22, 27, 36)],
                 smin=2, smax=5)
        for f in range(4):
            y = (f + 1) * CELL - 4
            d.rectangle([0, y, SIZE, y + 4], fill=(38, 44, 54))
            dh.rectangle([0, y, SIZE, y + 4], fill=150)
        # Curtain-wall mullion grid: thin verticals every half cell
        # so the glass reads as panes with frames, not one sheet.
        for mx in range(0, SIZE, CELL // 2):
            d.rectangle([mx, 0, mx + 4, SIZE], fill=(44, 52, 64, 160))
            dh.rectangle([mx, 0, mx + 4, SIZE], fill=158)
        # Panes sit slightly recessed between the mullions.
        dh.rectangle([0, 0, SIZE, SIZE], outline=128)
    return img, d, himg, dh


def _normal_from_height(himg, strength=2.6):
    """Height (L image) -> tangent-space normal map (OpenGL, Y+),
    wrap-around Sobel so the tile stays seamless."""
    h = np.asarray(himg, dtype=np.float32) / 255.0
    gx = ((np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 2.0
          + (np.roll(np.roll(h, -1, 0), -1, 1) - np.roll(np.roll(h, -1, 0), 1, 1))
          + (np.roll(np.roll(h, 1, 0), -1, 1) - np.roll(np.roll(h, 1, 0), 1, 1))) / 8.0
    gr = ((np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 2.0
          + (np.roll(np.roll(h, -1, 0), -1, 1) - np.roll(np.roll(h, 1, 0), -1, 1))
          + (np.roll(np.roll(h, -1, 0), 1, 1) - np.roll(np.roll(h, 1, 0), 1, 1))) / 8.0
    nx = -gx * strength
    ny = gr * strength
    nz = np.ones_like(h)
    inv = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
    rgb = np.stack([(nx * inv * 0.5 + 0.5), (ny * inv * 0.5 + 0.5),
                    (nz * inv * 0.5 + 0.5)], axis=-1)
    return Image.fromarray((rgb * 255.0).astype(np.uint8), "RGB")


def paint(kind, variant, seed):
    rng = random.Random(seed)
    img, d, himg, dh = _base(rng, kind)
    dim = variant == "b"
    for cx in range(4):
        for cy in range(4):
            _window(d, dh, rng, cx * CELL, cy * CELL, kind, dim and rng.random() < 0.6)
    path = os.path.join(OUT, "win_%s_%s.jpg" % (kind, variant))
    img.save(path, quality=88)
    print("painted", path)
    npath = os.path.join(OUT, "win_%s_%s_n.jpg" % (kind, variant))
    _normal_from_height(himg).save(npath, quality=92, subsampling=0)
    print("painted", npath)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    paint("ent", "a", 101)
    paint("ent", "b", 202)
    paint("kit", "a", 303)
    paint("kit", "b", 404)
    paint("mil", "a", 505)
    paint("mil", "b", 606)
