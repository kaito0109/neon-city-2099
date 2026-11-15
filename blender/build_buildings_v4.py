"""NEON CITY v4 Phase 2: procedural Blender building generator.

Replaces the v3/v4-Phase-1 building stock (single boxes with a
pasted window texture = the "mosaic tile" look) with modelled
buildings: podium + shaft + setbacks massing, floor-slab rhythm,
style-specific facade geometry (ENT pipes/AC/shutters, KIT rounded
corners/balconies/disc signs, MIL fins/crown glow), rooftop clutter
and sign geometry. Window textures are mapped in METRES
(u = face width / 6.8, v = height / 12.4 with a global v offset),
so windows keep a real-world size on every face of every building.

Authored in Godot coords (x east, y up, z south, front = +Z) and
emitted as Blender (x, -z, y) — a proper rotation, so RH-rule
outward windings survive. Materials are NAMES only (no textures,
no emission — Godot re-applies: model_loader repair rule). Each
variant also gets a *_far.glb (massing only) for the LOD swap.

Outputs: assets/bld/<name>.glb (+ _far), bld_manifest.gd at the
project root (loose .json does not ship in the web pck).
Run: blender --background --python blender/build_buildings_v4.py
"""
import json
import math
import os
import random
import zlib

import bpy

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "assets", "bld")
TILE_W = 6.8    # metres per window-texture tile (4 windows)
TILE_H = 12.4   # metres per tile (4 floors of 3.1)
FLOOR = 3.1
PODIUM_H = 3.4

_WIN_BASE = ["BldEntA", "BldEntB", "BldKitA", "BldKitB", "BldMilA", "BldMilB"]
MAT_NAMES = (
    _WIN_BASE
    + [m + "S" for m in _WIN_BASE]   # side faces: baked shade x0.74
    + [m + "B" for m in _WIN_BASE]   # back face: baked shade x0.52
    + ["BldGlass", "BldGlassLit", "BldDark", "BldConc", "BldPlas", "BldPlas2", "BldYel",
       "SignC", "SignP", "SignY", "SignW", "BldRoof"]
)
WIN_MATS = {"BldEntA", "BldEntB", "BldKitA", "BldKitB", "BldMilA", "BldMilB"}
SIGNS = ["SignC", "SignP", "SignY", "SignW"]


class Geo:
    """Accumulates quads per material with per-vertex UVs."""

    def __init__(self):
        self.verts = []          # Godot-space Vector3 tuples
        self.faces = []          # (mat, [i0,i1,i2,i3], [(u,v) x4])

    def quad(self, mat, pts, uvs):
        base = len(self.verts)
        self.verts.extend(pts)
        self.faces.append((mat, [base, base + 1, base + 2, base + 3], uvs))

    def tri(self, mat, pts, uvs):
        base = len(self.verts)
        self.verts.extend(pts)
        self.faces.append((mat, [base, base + 1, base + 2], uvs))

    def box(self, mat, cx, cy, cz, sx, sy, sz, y_base=None, u_off=0.0,
            top_mat=None, bottom=False):
        """Box with RH-outward faces. Window mats get metre UVs."""
        hx, hy, hz = sx / 2.0, sy / 2.0, sz / 2.0
        x0, x1 = cx - hx, cx + hx
        y0, y1 = cy - hy, cy + hy
        z0, z1 = cz - hz, cz + hz
        if y_base is None:
            y_base = y0
        win = mat in WIN_MATS

        def uv_side(w_m, h_m):
            if win:
                return [(u_off, y_base / TILE_H),
                        (u_off + w_m / TILE_W, y_base / TILE_H),
                        (u_off + w_m / TILE_W, (y_base + h_m) / TILE_H),
                        (u_off, (y_base + h_m) / TILE_H)]
            return [(0, 0), (1, 0), (1, 1), (0, 1)]

        # Baked per-face shading for window facades: front keeps the
        # full texture, sides/back use tinted material variants, so
        # a box stops reading as four identical pasted posters.
        fmat = mat
        smat = mat + "S" if win else mat
        bmat = mat + "B" if win else mat
        uvf = uv_side(sx, sy)
        self.quad(fmat, [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], uvf)  # +Z
        self.quad(bmat, [(x1, y0, z0), (x0, y0, z0), (x0, y1, z0), (x1, y1, z0)], uvf)  # -Z
        uvs = uv_side(sz, sy)
        self.quad(smat, [(x1, y0, z1), (x1, y0, z0), (x1, y1, z0), (x1, y1, z1)], uvs)  # +X
        self.quad(smat, [(x0, y0, z0), (x0, y0, z1), (x0, y1, z1), (x0, y1, z0)], uvs)  # -X
        tm = top_mat if top_mat is not None else ("BldRoof" if win else mat)
        self.quad(tm, [(x0, y1, z1), (x1, y1, z1), (x1, y1, z0), (x0, y1, z0)],
                  [(0, 0), (1, 0), (1, 1), (0, 1)])  # +Y top
        if bottom:
            self.quad(tm, [(x1, y0, z1), (x0, y0, z1), (x0, y0, z0), (x1, y0, z0)],
                      [(0, 0), (1, 0), (1, 1), (0, 1)])  # -Y

    def cyl(self, mat, cx, cz, r, y0, y1, seg=20, win=False, cap=True):
        """Vertical cylinder shell (+ optional top cap disc)."""
        circ = 2.0 * math.pi * r
        for i in range(seg):
            a0 = (i / seg) * math.tau
            a1 = ((i + 1) / seg) * math.tau
            p = lambda a, y: (cx + r * math.sin(a), y, cz + r * math.cos(a))
            if win:
                u0 = (i / seg) * circ / TILE_W
                u1 = ((i + 1) / seg) * circ / TILE_W
                uvs = [(u0, y0 / TILE_H), (u1, y0 / TILE_H),
                       (u1, y1 / TILE_H), (u0, y1 / TILE_H)]
            else:
                uvs = [(0, 0), (1, 0), (1, 1), (0, 1)]
            self.quad(mat, [p(a0, y0), p(a1, y0), p(a1, y1), p(a0, y1)], uvs)
        if cap:
            cbase = len(self.verts)
            self.verts.append((cx, y1, cz))
            ring = []
            for i in range(seg):
                a = (i / seg) * math.tau
                ring.append(len(self.verts))
                self.verts.append((cx + r * math.sin(a), y1, cz + r * math.cos(a)))
            for i in range(seg):
                j = (i + 1) % seg
                self.faces.append((mat, [cbase, ring[i], ring[j]],
                                   [(0.5, 0.5), (0, 0), (1, 0)]))


def _wedge(g, mat, cx, cz, w, d, y0, h_back, h_front, u_off=0.0):
    """Sloped-top prism (v5 'slope' form): the roof plane falls
    from h_back (at z=-d/2) to h_front (at z=+d/2), heights
    absolute from y0. Side profiles are trapezoids. Window
    materials keep metre UVs on the vertical faces; the slope
    itself is BldRoof."""
    x0, x1 = cx - w / 2.0, cx + w / 2.0
    z0, z1 = cz - d / 2.0, cz + d / 2.0
    yb, yf = y0 + h_back, y0 + h_front
    win = mat in WIN_MATS
    fmat = mat
    smat = mat + "S" if win else mat
    bmat = mat + "B" if win else mat

    def uv(w_m, y_top):
        if win:
            return [(u_off, y0 / TILE_H), (u_off + w_m / TILE_W, y0 / TILE_H),
                    (u_off + w_m / TILE_W, y_top / TILE_H),
                    (u_off, y_top / TILE_H)]
        return [(0, 0), (1, 0), (1, 1), (0, 1)]

    g.quad(fmat, [(x0, y0, z1), (x1, y0, z1), (x1, yf, z1), (x0, yf, z1)],
           uv(w, yf))                                   # +Z front
    g.quad(bmat, [(x1, y0, z0), (x0, y0, z0), (x0, yb, z0), (x1, yb, z0)],
           uv(w, yb))                                   # -Z back
    g.quad(smat, [(x1, y0, z1), (x1, y0, z0), (x1, yb, z0), (x1, yf, z1)],
           uv(d, max(yb, yf)))                          # +X trapezoid
    g.quad(smat, [(x0, y0, z0), (x0, y0, z1), (x0, yf, z1), (x0, yb, z0)],
           uv(d, max(yb, yf)))                          # -X trapezoid
    g.quad("BldRoof", [(x0, yf, z1), (x1, yf, z1), (x1, yb, z0), (x0, yb, z0)],
           [(0, 0), (1, 0), (1, 1), (0, 1)])            # sloped top


def _podium_units(g, rng, w, d):
    """v5: the ground floor is individual shop units, not one
    glass band — glass panes split by dark fins, a small sign
    strip over most units, some units shuttered dark. Front and
    back faces; the sides keep the plain band (perf)."""
    for sgn in (1, -1):
        zc = sgn * (d / 2 + 0.62)
        n = max(2, int(round(w / 3.4)))
        uw = w * 0.92 / n
        for i in range(n):
            cx = -w * 0.46 + uw * (i + 0.5)
            if sgn == 1 and abs(cx) < 2.3:
                continue  # entrance recess lives here
            closed = rng.random() < 0.22
            gmat = "BldDark" if closed else (
                "BldGlassLit" if rng.random() < 0.55 else "BldGlass")
            g.box(gmat, cx, 1.55, zc, uw - 0.35, 2.3, 0.14)
            if not closed and rng.random() < 0.62:
                g.box(rng.choice(SIGNS), cx, 3.02, zc + sgn * 0.04,
                      uw - 0.7, 0.48, 0.18)
        for i in range(n + 1):
            fx = -w * 0.46 + uw * i
            g.box("BldDark", fx, PODIUM_H / 2, zc, 0.3, PODIUM_H, 0.2)


def _parapet(g, w, d, top, cx=0.0):
    """Thin rim around the roof edge — crisps the silhouette
    from the street and from the air."""
    g.box("BldDark", cx, top + 0.3, d / 2 - 0.09, w + 0.5, 0.6, 0.18)
    g.box("BldDark", cx, top + 0.3, -d / 2 + 0.09, w + 0.5, 0.6, 0.18)
    g.box("BldDark", cx + w / 2 - 0.09, top + 0.3, 0, 0.18, 0.6, d + 0.5)
    g.box("BldDark", cx - w / 2 + 0.09, top + 0.3, 0, 0.18, 0.6, d + 0.5)


def _helipad(g, top, cx=0.0):
    """Dark pad + pale H, readable from the air (towers only)."""
    g.cyl("BldDark", cx, 0, 3.4, top, top + 0.14, seg=18)
    g.box("BldConc", cx - 0.85, top + 0.18, 0, 0.5, 0.05, 2.6)
    g.box("BldConc", cx + 0.85, top + 0.18, 0, 0.5, 0.05, 2.6)
    g.box("BldConc", cx, top + 0.18, 0, 1.7, 0.05, 0.5)


def _slabs(g, mat, w, d, y_from, y_to, step=FLOOR, thick=0.16, over=0.22, cx=0.0):
    y = y_from + step
    while y < y_to - 0.4:
        g.box(mat, cx, y, 0, w + over, thick, d + over, bottom=True)
        y += step


def _roof_clutter(g, rng, w, d, top, style, cx=0.0):
    n = rng.randint(1, 3)
    for _ in range(n):
        bw = rng.uniform(1.4, 3.2)
        bh = rng.uniform(0.7, 1.6)
        bx = cx + rng.uniform(-w / 2 + bw, w / 2 - bw)
        bz = rng.uniform(-d / 2 + bw, d / 2 - bw)
        g.box("BldDark", bx, top + bh / 2, bz, bw, bh, bw * rng.uniform(0.7, 1.1),
              bottom=True)
    if style == "ent":
        # Rooftop water tank — the entropism silhouette staple.
        tx = cx + rng.uniform(-w / 4, w / 4)
        tz = rng.uniform(-d / 4, d / 4)
        g.cyl("BldConc", tx, tz, 1.5, top, top + 2.6, seg=12)
        g.cyl("BldDark", tx, tz, 1.62, top + 2.6, top + 2.85, seg=12)
        g.box("BldDark", tx, top + 0.3, tz, 2.2, 0.6, 2.2)
    if rng.random() < 0.6:
        ax = cx + rng.uniform(-w / 3, w / 3)
        g.box("BldDark", ax, top + rng.uniform(1.6, 3.0), rng.uniform(-d / 3, d / 3),
              0.14, rng.uniform(3.2, 6.0), 0.14)


def build_building(style, band, w, d, h, seed, far=False, form="stack"):
    """Returns a Geo. Heights arrive pre-quantised to the floor grid.

    v5 forms (silhouette variety — the thing the owner kept
    flagging): stack (setback tiers), cant (offset upper tier on
    stepped corbels), step (staircase of slices), slope (slanted
    roof prism), twin (two slabs + recessed core + skybridges).
    """
    rng = random.Random(seed)
    g = Geo()
    win = {"ent": "BldEntA" if seed % 2 == 0 else "BldEntB",
           "kit": "BldKitA" if seed % 2 == 0 else "BldKitB",
           "mil": "BldMilA" if seed % 2 == 0 else "BldMilB"}[style]
    sign = rng.choice(SIGNS)
    u_off = rng.uniform(0.0, 0.9)
    shaft_top = h
    # --- podium: ground floor ---
    g.box("BldDark", 0, PODIUM_H / 2, 0, w + 1.2, PODIUM_H, d + 1.2, bottom=True)
    if far:
        for sgn, along_x in ((1, True), (-1, True), (1, False), (-1, False)):
            if along_x:
                g.box("BldGlass", 0, 1.55, sgn * (d / 2 + 0.62), w * 0.9, 2.3, 0.14)
            else:
                g.box("BldGlass", sgn * (w / 2 + 0.62), 1.55, 0, 0.14, 2.3, d * 0.9)
    else:
        for sgn in (1, -1):
            g.box("BldGlass", sgn * (w / 2 + 0.62), 1.55, 0, 0.14, 2.3, d * 0.9)
        _podium_units(g, rng, w, d)
    # Sign board over the front entrance + entrance dark recess.
    g.box(sign, 0, PODIUM_H + 0.45, d / 2 + 0.35, w * rng.uniform(0.4, 0.62), 0.85, 0.3)
    g.box("BldDark", 0, 1.5, d / 2 + 0.63, 3.2, 3.0, 0.1)
    # --- shaft: massing by form ---
    top_w, top_d, crown_cx = w, d, 0.0
    if form == "step":
        if band in ("high", "tower"):
            cuts = [(0.40, 1.0), (0.32, 0.72), (0.28, 0.46)]
        else:
            cuts = [(0.55, 1.0), (0.45, 0.62)]
        xcur = -w / 2
        for (frac, hf) in cuts:
            sw = w * frac
            sh = PODIUM_H + round((h - PODIUM_H) * hf / FLOOR) * FLOOR
            if sh > PODIUM_H + FLOOR:
                g.box(win, xcur + sw / 2, (PODIUM_H + sh) / 2, 0, sw,
                      sh - PODIUM_H, d, y_base=PODIUM_H, u_off=u_off,
                      top_mat="BldRoof")
                if not far:
                    _slabs(g, "BldDark", sw, d, PODIUM_H, sh, cx=xcur + sw / 2)
            xcur += sw
        top_w = w * cuts[0][0]
        crown_cx = -w / 2 + top_w / 2
        g.box("BldDark", crown_cx, shaft_top + 0.18, 0, top_w + 0.5, 0.36,
              top_d + 0.5, bottom=True)
        if not far:
            _parapet(g, top_w, top_d, shaft_top + 0.36, cx=crown_cx)
    elif form == "slope":
        slope_h = FLOOR * (3 if band == "tower" else 2)
        y_base2 = h - slope_h
        g.box(win, 0, (PODIUM_H + y_base2) / 2, 0, w, y_base2 - PODIUM_H, d,
              y_base=PODIUM_H, u_off=u_off, top_mat="BldRoof")
        if not far:
            _slabs(g, "BldDark", w, d, PODIUM_H, y_base2)
        _wedge(g, win, 0, 0, w * 0.97, d * 0.97, y_base2, slope_h,
               slope_h * 0.3, u_off)
        g.box("BldDark", 0, h + 0.08, -d * 0.485 + 0.15, w * 0.97, 0.34, 0.3)
    elif form == "twin":
        sw = w * 0.44
        gap = w * 0.12
        for sgn in (1, -1):
            cx = sgn * (gap / 2 + sw / 2)
            g.box(win, cx, (PODIUM_H + h) / 2, 0, sw, h - PODIUM_H, d,
                  y_base=PODIUM_H, u_off=u_off, top_mat="BldRoof")
            if not far:
                _slabs(g, "BldDark", sw, d, PODIUM_H, h, cx=cx)
            g.box("BldDark", cx, shaft_top + 0.18, 0, sw + 0.5, 0.36,
                  d + 0.5, bottom=True)
            if not far:
                _parapet(g, sw, d, shaft_top + 0.36, cx=cx)
        # Recessed dark core + two glass skybridges.
        g.box("BldDark", 0, (PODIUM_H + h) / 2, 0, gap + 0.5,
              h - PODIUM_H - 1.0, d * 0.45)
        if not far:
            for hf in (0.38, 0.72):
                by = PODIUM_H + (h - PODIUM_H) * hf
                g.box("BldGlassLit", 0, by, 0, gap + sw * 0.36, 2.6, d * 0.52)
                g.box(sign, 0, by + 1.55, d * 0.26 + 0.12, w * 0.3, 0.45, 0.2)
        top_w = sw
    else:
        # stack / cant: setback tiers; cant offsets the upper
        # tiers toward +x on stepped corbels.
        tiers = [(w, d, PODIUM_H, shaft_top, 0.0)]
        if band in ("high", "tower"):
            cut1 = PODIUM_H + round((h - PODIUM_H) * 0.52 / FLOOR) * FLOOR
            tiers = [(w, d, PODIUM_H, cut1, 0.0),
                     (w * 0.8, d * 0.8, cut1, shaft_top, 0.0)]
            if band == "tower":
                cut2 = cut1 + round((h - cut1) * 0.55 / FLOOR) * FLOOR
                tiers = [(w, d, PODIUM_H, cut1, 0.0),
                         (w * 0.82, d * 0.82, cut1, cut2, 0.0),
                         (w * 0.62, d * 0.62, cut2, shaft_top, 0.0)]
        if form == "cant" and len(tiers) > 1:
            tiers = [(tw, td, y0, y1, 0.0 if i == 0 else
                      (tiers[0][0] - tw) / 2 + 1.2 * (0.7 if i == 1 else 1.0))
                     for i, (tw, td, y0, y1, _c) in enumerate(tiers)]
            # Stepped corbels under the first offset tier.
            tw1, td1, y01 = tiers[1][0], tiers[1][1], tiers[1][2]
            ex = tiers[1][4] + tw1 / 2
            g.box("BldConc", ex - 0.7, y01 - 0.3, 0, 1.8, 0.6, td1 * 0.92)
            g.box("BldConc", ex - 1.15, y01 - 0.85, 0, 0.9, 0.5, td1 * 0.92)
        for (tw, td, y0, y1, tcx) in tiers:
            g.box(win, tcx, (y0 + y1) / 2, 0, tw, y1 - y0, td, y_base=y0,
                  u_off=u_off, top_mat="BldRoof")
            if not far:
                _slabs(g, "BldDark", tw, td, y0, y1, cx=tcx)
        top_w, top_d = tiers[-1][0], tiers[-1][1]
        crown_cx = tiers[-1][4]
        g.box("BldDark", crown_cx, shaft_top + 0.18, 0, top_w + 0.5, 0.36,
              top_d + 0.5, bottom=True)
        if not far:
            _parapet(g, top_w, top_d, shaft_top + 0.36, cx=crown_cx)
        if not far and (style == "mil" or band == "tower") and rng.random() < 0.8:
            g.box(sign, crown_cx, shaft_top - 0.5, top_d / 2 + 0.1,
                  top_w * 0.7, 0.5, 0.18)
    if far:
        return g
    # --- style details ---
    if style == "ent":
        # Face AC boxes + corner pipes + a shutter door.
        for _ in range(rng.randint(2, 5)):
            fx = rng.uniform(-w / 2 + 1.5, w / 2 - 1.5)
            fy = rng.uniform(PODIUM_H + 3, h - 2.5)
            side = rng.choice((1, -1))
            g.box("BldConc", fx, fy, side * (d / 2 + 0.24), 0.95, 0.7, 0.42)
        for sxn in (-1, 1):
            g.box("BldDark", sxn * (w / 2 + 0.12), h / 2, d / 2 + 0.12,
                  0.24, h - 1.0, 0.24)
        g.box("BldDark", -w * 0.28, 1.6, d / 2 + 0.64, 2.4, 3.2, 0.08)
        # v5: horizontal duct trunking + patched concrete panels.
        for _ in range(rng.randint(1, 2)):
            dy = rng.uniform(PODIUM_H + 5.0, h - 4.0)
            g.box("BldConc", rng.uniform(-w * 0.1, w * 0.1), dy, d / 2 + 0.17,
                  w * rng.uniform(0.55, 0.85), 0.5, 0.3)
        for _ in range(rng.randint(3, 5)):
            px = rng.uniform(-w / 2 + 1.2, w / 2 - 1.2)
            py = rng.uniform(PODIUM_H + 2.0, h - 2.0)
            side = rng.choice((1, -1))
            g.box("BldConc", px, py, side * (d / 2 + 0.045),
                  rng.uniform(1.0, 2.4), rng.uniform(1.2, 2.8), 0.07)
    elif style == "kit":
        # Rounded corner columns + balcony slabs + disc sign.
        for sxn in (-1, 1):
            for szn in (-1, 1):
                g.cyl("BldPlas", sxn * w / 2, szn * d / 2, 0.8, 0, h - 0.6, seg=10, cap=False)
        y = PODIUM_H + FLOOR
        _bi = 0
        while y < h - 2.0:
            bw2 = w * (0.7 if _bi % 2 == 0 else 0.46)
            bx2 = 0.0 if _bi % 2 == 0 else w * 0.16
            g.box("BldPlas2", bx2, y, d / 2 + 0.55, bw2, 0.22, 1.1, bottom=True)
            g.box("BldDark", bx2, y + 0.32, d / 2 + 1.06, bw2, 0.42, 0.07)
            _bi += 1
            y += FLOOR * 2
        g.box("BldYel", 0, h - 0.35, 0, w + 0.3, 0.5, d + 0.3, bottom=True)
        # Round sign board on the front face: a short cylinder whose
        # axis runs along Z reads as a disc from the street.
        g.box("BldDark", 0, h * 0.55, d / 2 + 0.5, 0.18, 0.18, 1.0)
        # Disc lies in the XY plane at fixed z: a 10-sided prism.
        p = lambda a, zz: (1.05 * math.sin(a), h * 0.55 + 1.05 * math.cos(a), zz)
        zlo, zhi = d / 2 + 0.43, d / 2 + 0.67
        for k in range(10):
            a0 = k / 10 * math.tau
            a1 = (k + 1) / 10 * math.tau
            g.quad(sign, [p(a1, zlo), p(a0, zlo), p(a0, zhi), p(a1, zhi)],
                   [(0, 0), (1, 0), (1, 1), (0, 1)])
            g.tri(sign, [(0, h * 0.55, zlo), p(a0, zlo), p(a1, zlo)],
                  [(0.5, 0.5), (0, 0), (1, 0)])
            g.tri(sign, [(0, h * 0.55, zhi), p(a1, zhi), p(a0, zhi)],
                  [(0.5, 0.5), (0, 0), (1, 0)])
        # v5: vertical colour stripes breaking the window grid.
        for _ in range(rng.randint(2, 3)):
            sx = rng.uniform(-w / 2 + 1.0, w / 2 - 1.0)
            g.box("BldYel" if rng.random() < 0.35 else "BldPlas",
                  sx, (PODIUM_H + h) / 2, d / 2 + 0.06, 0.55,
                  h - PODIUM_H - 0.8, 0.1)
    else:  # mil
        # Vertical fins on front/back + entrance canopy.
        fx = -w / 2 + 1.1
        while fx < w / 2 - 0.8:
            for szn in (1, -1):
                g.box("BldDark", fx, (PODIUM_H + h) / 2, szn * (d / 2 + 0.16),
                      0.32, h - PODIUM_H - 0.6, 0.3)
            fx += 2.2
        g.box("BldDark", 0, PODIUM_H + 0.15, d / 2 + 1.0, 6.0, 0.3, 2.2, bottom=True)
        if rng.random() < 0.7:
            g.box(sign, w * 0.3, h * rng.uniform(0.55, 0.75), d / 2 + 0.22,
                  0.35, rng.uniform(3.0, 5.0), 0.3)
        # v5: spandrel bands every 3 floors + a glass sky-lobby.
        yy = PODIUM_H + FLOOR * 3
        while yy < h - 1.5:
            for szn in (1, -1):
                g.box("BldDark", 0, yy, szn * (d / 2 + 0.05), w * 0.96, 0.3, 0.1)
            yy += FLOOR * 3
        if band == "tower" and rng.random() < 0.55:
            ly = PODIUM_H + (h - PODIUM_H) * rng.uniform(0.4, 0.6)
            g.box("BldGlass", 0, ly, d / 2 + 0.3, w * 0.52, 3.0, 0.65)
            g.box(sign, 0, ly + 1.75, d / 2 + 0.32, w * 0.52, 0.4, 0.6)
    _roof_clutter(g, rng, top_w, top_d, shaft_top + 0.36, style, cx=crown_cx)
    if band == "tower" and top_w >= 11.0 and rng.random() < 0.75:
        _helipad(g, shaft_top + 0.4, cx=crown_cx)
    # Wall blade sign on a side face.
    if rng.random() < 0.65:
        g.box(sign, w / 2 + 0.55, rng.uniform(PODIUM_H + 2.5, max(PODIUM_H + 3.0, h - 2.0)),
              rng.uniform(-d / 4, d / 4), 0.9, rng.uniform(1.6, 2.6), 0.22)
    return g


# name, style, band, w, d, floors_above_podium  (h = 3.4 + n*3.1)
VARIANTS = [
    ("ent_low_a", "ent", "low", 13, 13, 3), ("ent_low_b", "ent", "low", 15, 13, 3),
    ("ent_mid_a", "ent", "mid", 14, 14, 6), ("ent_mid_b", "ent", "mid", 16, 14, 7),
    ("ent_high_a", "ent", "high", 15, 15, 11), ("ent_high_b", "ent", "high", 17, 15, 13),
    ("ent_tower_a", "ent", "tower", 16, 16, 18), ("ent_tower_b", "ent", "tower", 17, 17, 23),
    ("kit_low_a", "kit", "low", 12, 12, 2), ("kit_low_b", "kit", "low", 14, 12, 3),
    ("kit_mid_a", "kit", "mid", 13, 13, 5), ("kit_mid_b", "kit", "mid", 15, 13, 6),
    ("kit_high_a", "kit", "high", 14, 14, 8), ("kit_high_b", "kit", "high", 16, 14, 9),
    ("mil_low_a", "mil", "low", 14, 14, 3), ("mil_low_b", "mil", "low", 15, 13, 4),
    ("mil_mid_a", "mil", "mid", 15, 15, 7), ("mil_mid_b", "mil", "mid", 16, 14, 8),
    ("mil_high_a", "mil", "high", 16, 16, 12), ("mil_high_b", "mil", "high", 17, 15, 14),
    ("mil_tower_a", "mil", "tower", 17, 17, 19), ("mil_tower_b", "mil", "tower", 18, 17, 25),
    ("ent_mid_c", "ent", "mid", 15, 14, 7, "cant"),
    ("ent_high_c", "ent", "high", 16, 15, 12, "slope"),
    ("ent_tower_c", "ent", "tower", 17, 16, 21, "step"),
    ("kit_mid_c", "kit", "mid", 14, 13, 6, "step"),
    ("kit_high_c", "kit", "high", 15, 14, 9, "cant"),
    ("kit_tower_a", "kit", "tower", 16, 16, 17, "stack"),
    ("kit_tower_b", "kit", "tower", 17, 16, 21, "slope"),
    ("mil_mid_c", "mil", "mid", 16, 15, 8, "cant"),
    ("mil_high_c", "mil", "high", 17, 16, 13, "twin"),
    ("mil_tower_c", "mil", "tower", 18, 17, 22, "slope"),
]
FAR_BANDS = {"mid", "high", "tower"}


def export_geo(g, name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = {}
    for mn in MAT_NAMES:
        m = bpy.data.materials.new(mn)
        mats[mn] = m
    verts_bl = [(x, -z, y) for (x, y, z) in g.verts]
    faces_idx = [f[1] for f in g.faces]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts_bl, [], faces_idx)
    for mn in MAT_NAMES:
        mesh.materials.append(mats[mn])
    mat_idx = {mn: i for i, mn in enumerate(MAT_NAMES)}
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        poly.material_index = mat_idx[g.faces[poly.index][0]]
        uvs = g.faces[poly.index][2]
        for k, li in enumerate(poly.loop_indices):
            uv_layer.data[li].uv = uvs[k % len(uvs)]
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB",
                              export_apply=True)
    print("exported", name, os.path.getsize(path), "bytes,", len(mesh.polygons), "faces")


def build_mega():
    g = Geo()
    # Tier 1: 104x56, 0..38 (mil glass), podium + slabs + courtyard.
    g.box("BldDark", 0, PODIUM_H / 2, 0, 105.2, PODIUM_H, 57.2, bottom=True)
    g.box("BldGlass", 0, 1.55, 28.65, 92, 2.3, 0.14)
    g.box("BldGlass", 0, 1.55, -28.65, 92, 2.3, 0.14)
    g.box("BldMilA", 0, PODIUM_H + (38 - PODIUM_H) / 2, 0, 104, 38 - PODIUM_H, 56,
          y_base=PODIUM_H, top_mat="BldRoof")
    _slabs(g, "BldDark", 104, 56, PODIUM_H, 38)
    # Tier 2: 84x44, 38..72. Tier 3: 60x32, 72..110.
    g.box("BldMilB", 0, 38 + 17, 0, 84, 34, 44, y_base=38, top_mat="BldRoof")
    _slabs(g, "BldDark", 84, 44, 38, 72)
    g.box("BldMilA", 0, 72 + 19, 0, 60, 38, 32, y_base=72, top_mat="BldRoof")
    _slabs(g, "BldDark", 60, 32, 72, 110)
    # Courtyard glow frame on tier-1 roof + dark inner slab.
    for (sx, sz, px, pz) in ((40, 1.2, 0, 12.6), (40, 1.2, 0, -12.6),
                             (1.2, 24, 20.6, 0), (1.2, 24, -20.6, 0)):
        g.box("BldYel", px, 38.45, pz, sx, 0.5, sz, bottom=True)
    g.box("BldRoof", 0, 38.3, 0, 34, 0.7, 18)
    # Fingerprint cornice on the front/back edges of tier 1.
    g.box("BldYel", 0, 36.5, 28.1, 104.6, 1.1, 0.5)
    g.box("BldYel", 0, 36.5, -28.1, 104.6, 1.1, 0.5)
    # Big sign board on the spawn-facing front.
    g.box("SignY", 0, 30, 28.25, 36, 3.0, 0.35)
    g.box("BldDark", 0, PODIUM_H + 0.2, 29.6, 10, 0.35, 3.4, bottom=True)
    rng = random.Random(777)
    _roof_clutter(g, rng, 60, 32, 110.0, "mil")
    return g


def build_arch():
    g = Geo()
    # Legs (26 x, 26 y, 9 z) at z +-13.5; slab y 26..34; top 34..40.
    for szn in (1, -1):
        g.box("BldEntA", 0, 13, szn * 13.5, 26, 26, 9, y_base=0)
        g.box("BldGlass", 0, 1.55, szn * 18.05, 20, 2.3, 0.14)
        g.box("BldDark", 13.1, 13, szn * 13.5, 0.24, 25, 0.24)
    g.box("BldEntB", 0, 30, 0, 30, 8, 36, y_base=26, top_mat="BldRoof", bottom=True)
    g.box("BldDark", 0, 37, 0, 24, 6, 28, top_mat="BldRoof")
    # Cyan under-glow strip (traffic passes beneath).
    g.box("SignC", 0, 25.8, 0, 28, 0.4, 30)
    g.box("SignP", 0, 33.2, 18.1, 20, 0.8, 0.25)
    return g


def build_cyl():
    g = Geo()
    r, h = 14.0, 64.0
    g.cyl("BldDark", 0, 0, r + 1.0, 0, PODIUM_H, seg=28)
    g.cyl("BldGlass", 0, 0, r + 1.06, 0.6, 2.9, seg=28, cap=False)
    g.cyl("BldMilB", 0, 0, r, PODIUM_H, h, seg=28, win=True)
    for i in range(5):
        mat = "SignC" if i == 2 else "BldDark"
        g.cyl(mat, 0, 0, r + 0.45, 10.0 + i * 12.0, 10.5 + i * 12.0, seg=28, cap=False)
    g.cyl("BldDark", 0, 0, r + 0.5, h, h + 1.0, seg=28)
    g.cyl("SignW", 0, 0, r + 0.52, h + 1.0, h + 1.35, seg=28, cap=False)
    return g


def main():
    os.makedirs(OUT, exist_ok=True)
    export_geo(build_mega(), "hero_mega")
    export_geo(build_arch(), "hero_arch")
    export_geo(build_cyl(), "hero_cyl")
    manifest = {}
    for row in VARIANTS:
        (name, style, band, w, d, floors) = row[:6]
        form = row[6] if len(row) > 6 else "stack"
        h = PODIUM_H + floors * FLOOR
        seed = zlib.crc32(name.encode()) % 100000
        export_geo(build_building(style, band, float(w), float(d), h, seed,
                                  form=form), name)
        entry = {"style": style, "band": band, "w": w, "d": d, "h": round(h, 2),
                 "far": band in FAR_BANDS}
        manifest[name] = entry
        if band in FAR_BANDS:
            export_geo(build_building(style, band, float(w), float(d), h, seed,
                                      far=True, form=form), name + "_far")
    with open(os.path.join(ROOT, "bld_manifest.json"), "w") as f:
        json.dump(manifest, f)
    lines = ["class_name BldManifest", "## Generated by blender/build_buildings_v4.py — do not edit.",
             "const DATA: Dictionary = " + json.dumps(manifest)]
    with open(os.path.join(ROOT, "bld_manifest.gd"), "w") as f:
        f.write("\n".join(lines) + "\n")
    print("BUILDINGS_V4_OK variants:", len(manifest))


if __name__ == "__main__":
    main()
