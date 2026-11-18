#!/usr/bin/env python3
"""NEON CITY 2099 v4 — Phase 1: author the whole terrain in Blender as
one piece (ground plates, NE terraces, canal, road ribbons with
sidewalks, plaza, bridges, elevated skyway) and export:
  assets/terrain/terrain_v4.glb   (geometry, materials by NAME only)
  assets/terrain/layout_v4.json   (plots, roads, POIs, walk blocks)
All design numbers come from design/v4_layout.md (the approved map).
Authoring space = Godot space (x east, y up, z south); vertices are
converted to Blender space (bx, by, bz) = (gx, -gz, gy) on emission.
Materials are created AFTER the factory reset (creating them before
invalidates them — learned in v3). No textures, no emission in the
GLB: Godot re-materials by name, like the v3 kits.
Run: blender --background --python blender/build_terrain_v4.py
"""
import json
import math
import os
import random

import bpy

OUT_DIR = os.path.expanduser("~/workspace/godot_neon/assets/terrain")
os.makedirs(OUT_DIR, exist_ok=True)

# ---------------------------------------------------------------- data

TERRACES = [  # (x_min, z_min, x_max, z_max, height) NE hills
    (66.0, -219.0, 219.0, -76.0, 6.0),
    (104.0, -219.0, 219.0, -114.0, 12.0),
    (142.0, -219.0, 219.0, -152.0, 18.0),
]
BANK_W = 4.5  # v5.6: bench riser width (was a 20 m smooth embankment
# until v5.5, which read as bare dirt mounds in his screenshots)
LIP_W = 1.0  # flat tread lip at the top of each riser
SMOOTH_W = 20.0  # legacy embankment width, kept inside road corridors
PLOT_BANK_W = 20.0  # plot exclusion keeps the legacy bank zone, so
# regenerating the terrain never reshuffles the city layout
# Roads that climb the terraces: inside their corridor the legacy
# 20 m ramp survives (the v5.3-verified car climb); outside, benches.
CORRIDOR_ROADS = []  # filled from ROADS below (v5.7: the ring and
# the east streets cross terrace edges too and need the ramp)
CORRIDOR_IN = 11.0  # pure legacy ramp within this distance (m)
CORRIDOR_OUT = 18.0  # pure bench beyond this distance (m)

def height_at(x, z):
    """Stepped terrace heights (NE hills)."""
    if x >= 142.0 and z <= -152.0:
        return 18.0
    if x >= 104.0 and z <= -114.0:
        return 12.0
    if x >= 66.0 and z <= -76.0:
        return 6.0
    return 0.0

def _smooth_f(d, w):
    if d <= 0.0:
        return 1.0
    if d >= w:
        return 0.0
    t = 1.0 - d / w
    return t * t * (3.0 - 2.0 * t)

def _bench_f(d):
    """Bench profile: flat lip for LIP_W, then a steep smoothstep
    riser down to 0 at BANK_W."""
    if d <= LIP_W:
        return 1.0
    if d >= BANK_W:
        return 0.0
    t = 1.0 - (d - LIP_W) / (BANK_W - LIP_W)
    return t * t * (3.0 - 2.0 * t)

def _corridor_dist(x, z):
    best = 1e9
    for pts in CORRIDOR_ROADS:
        for i in range(len(pts) - 1):
            best = min(best, _seg_dist(x, z, pts[i], pts[i + 1]))
    return best

def height_smooth(x, z):
    """v5.6 bench terraces with a road-corridor exception. Roads and
    banks sample this so a road crossing a terrace edge ramps WITH
    the ground; away from roads the ground falls in steep benches.
    world_v4.gd _height_smooth_gd mirrors this function EXACTLY
    (cross-checked by tests/v56_test.gd against dumped samples)."""
    bench = 0.0
    smooth = 0.0
    for (x1, z1, x2, z2, h) in TERRACES:
        dx = max(x1 - x, 0.0, x - x2)
        dz = max(z1 - z, 0.0, z - z2)
        d = math.hypot(dx, dz)
        bench = max(bench, h * _bench_f(d))
        smooth = max(smooth, h * _smooth_f(d, SMOOTH_W))
    cd = _corridor_dist(x, z)
    if cd <= CORRIDOR_IN:
        return smooth
    if cd >= CORRIDOR_OUT:
        return bench
    c = (cd - CORRIDOR_IN) / (CORRIDOR_OUT - CORRIDOR_IN)
    c = c * c * (3.0 - 2.0 * c)
    return bench * c + smooth * (1.0 - c)

def _ring_points():
    pts = []
    for cx, cz, a0 in ((105, -105, 180), (105, 105, 270), (-105, 105, 0), (-105, -105, 90)):
        for k in range(13):
            ang = math.radians(a0 + k * 7.5)
            pts.append((cx + 55 * math.cos(ang), cz + 55 * math.sin(ang)))
    return pts

CANAL = [(-225, 176), (-120, 182), (-20, 174), (80, 178), (225, 188)]
DECK = [(-225, -58), (-130, -72), (-30, -60), (70, -78), (160, -88), (225, -96)]

# name, points, width, kind, sidewalk?
ROADS = [
    ("ring", _ring_points(), 14.0, "street", True),
    ("ave_a_sw", [(-225, 198), (-120, 110), (-52, 55)], 18.0, "avenue", True),
    ("ave_a_ne", [(52, -55), (105, -92), (152, -124)], 18.0, "avenue", True),
    ("ave_b_nw", [(-225, -118), (-120, -62), (-58, -30)], 14.0, "avenue", True),
    ("ave_b_se", [(58, 32), (130, 78), (225, 138)], 14.0, "avenue", True),
    ("ns_main", [(0, 34), (0, 120), (0, 164)], 16.0, "avenue", True),
    ("ns_south", [(0, 190), (0, 225)], 16.0, "street", True),
    ("h1_w", [(-225, -105), (-120, -102), (-58, -102)], 12.0, "street", True),
    ("h1_e", [(64, -106), (118, -100)], 12.0, "street", True),
    ("s2", [(-225, 60), (-120, 66), (-40, 60)], 10.0, "street", True),
    ("e_st", [(120, -100), (126, 20), (118, 120), (122, 164)], 11.0, "street", True),
    ("e_south", [(122, 190), (120, 225)], 11.0, "street", False),
    ("w_st", [(-150, -160), (-146, -40), (-152, 80), (-146, 164)], 11.0, "street", True),
    ("w_south", [(-144, 190), (-142, 225)], 11.0, "street", False),
    ("switch", [(105, -92), (155, -88), (138, -128), (188, -138), (172, -182), (196, -205)], 9.0, "switch", False),
    ("market", [(-115, 138), (120, 138)], 9.0, "market", False),
]
DASH_ROADS = {"ring", "ave_a_sw", "ave_a_ne", "ave_b_nw", "ave_b_se", "ns_main"}
CORRIDOR_ROADS.extend([pts for (name, pts, _w, _k, _wk) in ROADS
                       if name in {"ave_a_ne", "switch", "ring",
                                   "e_st", "h1_e"}])

def _terrace_ring(x1, z1, x2, z2, d, h, yoff=0.0):
    """One offset contour of a terrace rect as (gx, gy, gz) points:
    edge stations marched CCW plus quarter-arc stations at corners.
    d=0 is the rect itself (height h); outer rings sample
    height_smooth, whose level sets are exactly these contours."""
    corners = [(x1, z2), (x2, z2), (x2, z1), (x1, z1)]  # SW SE NE NW
    # (edge dir, edge outward normal, corner arc start/end angles deg)
    edges = [((1, 0), (0, 1), 90.0, 0.0),      # south edge -> SE corner
             ((0, -1), (1, 0), 0.0, -90.0),    # east edge  -> NE corner
             ((-1, 0), (0, -1), -90.0, -180.0),  # north edge -> NW corner
             ((0, 1), (-1, 0), -180.0, -270.0)]  # west edge -> SW corner
    pts = []
    for ei in range(4):
        a = corners[ei]
        b = corners[(ei + 1) % 4]
        edir, n, a0, a1 = edges[ei]
        seg = subdivide([a, b], 7.0)
        for (px, pz) in seg[:-1]:
            qx, qz = px + n[0] * d, pz + n[1] * d
            y = h if d == 0.0 else height_smooth(qx, qz)
            pts.append((qx, y + yoff, qz))
        # corner arc at b (degenerate to the corner point when d=0)
        steps = 4
        for k in range(1, steps + 1):
            ang = math.radians(a0 + (a1 - a0) * k / steps)
            qx, qz = b[0] + math.cos(ang) * d, b[1] + math.sin(ang) * d
            y = h if d == 0.0 else height_smooth(qx, qz)
            pts.append((qx, y + yoff, qz))
    return pts

# ---------------------------------------------------------------- mesh kit

FACES = []  # (verts[(gx,gy,gz) x4 or x3], material_name)

def _norm(pts):
    ux, uy, uz = (pts[1][0] - pts[0][0], pts[1][1] - pts[0][1], pts[1][2] - pts[0][2])
    vx, vy, vz = (pts[2][0] - pts[0][0], pts[2][1] - pts[0][1], pts[2][2] - pts[0][2])
    return (uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx)

def add_quad(p1, p2, p3, p4, mat, up=False):
    """Quad in Godot coords (any winding). Converted to Blender space;
    when up=True the winding is fixed so the normal points +Y."""
    pts = [(p[0], -p[2], p[1]) for p in (p1, p2, p3, p4)]  # -> Blender
    if up:
        n = _norm(pts)
        if n[2] < 0:
            pts = [pts[0], pts[3], pts[2], pts[1]]
    FACES.append((pts, mat))

def add_tri(p1, p2, p3, mat, up=False):
    pts = [(p[0], -p[2], p[1]) for p in (p1, p2, p3)]
    if up:
        n = _norm(pts)
        if n[2] < 0:
            pts = [pts[0], pts[2], pts[1]]
    FACES.append((pts, mat))

def subdivide(pts, step=7.0):
    out = [pts[0]]
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        d = math.hypot(b[0] - a[0], b[1] - a[1])
        n = max(1, int(d / step))
        for k in range(1, n + 1):
            t = k / n
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out

def _perp(pts, i):
    a = pts[max(0, i - 1)]
    b = pts[min(len(pts) - 1, i + 1)]
    dx, dz = b[0] - a[0], b[1] - a[1]
    l = max(math.hypot(dx, dz), 0.001)
    return (-dz / l, dx / l)

def ribbon(pts, width, lift, mat, heights=None, closed=False):
    """Ribbon following a polyline in XZ. With heights=None every
    CORNER is draped on height_smooth at its own XZ (+ lift): the
    collision surface is that same function, so the ribbon can
    neither hover above the ground (floating paint) nor chord
    through a bend (the visible 'plates' on the climbs). Explicit
    heights keep the old per-point behaviour (canal)."""
    seq = list(pts)
    if closed:
        seq = seq + [seq[0]]
    hw = width / 2.0
    corners = []
    for i, (x, z) in enumerate(seq):
        q = _perp(seq, i)
        lx, lz = x + q[0] * hw, z + q[1] * hw
        rx, rz = x - q[0] * hw, z - q[1] * hw
        if heights is not None:
            ly = ry = heights[i] + lift
        else:
            ly = height_smooth(lx, lz) + lift
            ry = height_smooth(rx, rz) + lift
        corners.append(((lx, ly, lz), (rx, ry, rz)))
    for i in range(len(seq) - 1):
        (L0, R0), (L1, R1) = corners[i], corners[i + 1]
        add_quad(L0, R0, R1, L1, mat, up=True)

def offset_pts(pts, off):
    out = []
    for i, (x, z) in enumerate(pts):
        q = _perp(pts, i)
        out.append((x + q[0] * off, z + q[1] * off))
    return out

def flat_quad(x1, z1, x2, z2, y, mat):
    add_quad((x1, y, z1), (x2, y, z1), (x2, y, z2), (x1, y, z2), mat, up=True)

def box(x1, z1, x2, z2, y_bot, y_top, mat_top, mat_side):
    flat_quad(x1, z1, x2, z2, y_top, mat_top)
    for a, b in (((x1, z1), (x2, z1)), ((x2, z1), (x2, z2)),
                 ((x2, z2), (x1, z2)), ((x1, z2), (x1, z1))):
        add_quad((a[0], y_top, a[1]), (b[0], y_top, b[1]),
                 (b[0], y_bot, b[1]), (a[0], y_bot, a[1]), mat_side)

# ---------------------------------------------------------------- build

def build_geometry():
    # Ground plates (canal band 166..196.5 is canal geometry + bridges).
    flat_quad(-225, -225, 225, 166, 0.0, "GroundMat")
    flat_quad(-225, 196.5, 225, 225, 0.0, "GroundMat")
    # Outer apron so the city edge never shows void.
    flat_quad(-700, -700, 700, -225, -0.08, "ApronMat")
    flat_quad(-700, 225, 700, 700, -0.08, "ApronMat")
    flat_quad(-700, -225, -225, 225, -0.08, "ApronMat")
    flat_quad(225, -225, 700, 225, -0.08, "ApronMat")
    # Terraces: flat top plate + embankment rings built on the
    # offset contours of the rect (the level sets of height_smooth),
    # so the bank surface IS the smooth height function and road
    # ribbons crossing it agree instead of wedging cars.
    for (x1, z1, x2, z2, h) in TERRACES:
        # v5.6 cap lip stays (it sits on the flat lip zone, where
        # the draped grid below has the same height).
        cap_a = _terrace_ring(x1, z1, x2, z2, -0.55, h, 0.03)
        cap_b = _terrace_ring(x1, z1, x2, z2, 0.9, h, 0.03)
        for i in range(len(cap_a)):
            a0, a1 = cap_a[i], cap_a[(i + 1) % len(cap_a)]
            b0, b1 = cap_b[i], cap_b[(i + 1) % len(cap_b)]
            add_quad(a0, a1, b1, b0, "WallMat", up=True)
    # v5.7: ONE draped ground grid over the whole terrace quadrant
    # replaces the flat top plates + bench rings. The visual surface
    # and the collision surface are now the same function everywhere
    # in the quadrant — the plates/rings could not follow the road
    # corridors' ramps or the feather band, so the ground floated
    # or sank against the physics there. Steep cells take BankMat.
    # v5.8: the grid must be the SAME surface as the physics, not
    # just the same function — a 3 m visual grid over the 2 m
    # collision patch deviated up to ~1 m on the bench risers and
    # NPCs stood waist-deep in the slope on his iPhone. So: same
    # extent (x 44..244, z -244..-52), same 2 m lattice, and the
    # cells are emitted as explicit triangles with the collision
    # builder's exact split (a,b,c) + (a,c,d) — a quad left to the
    # exporter would pick its own diagonal per cell.
    gx0, gz0, gx1, gz1, gstep = 44.0, -244.0, 244.0, -52.0, 2.0
    gxs = [gx0 + i * gstep for i in range(int((gx1 - gx0) / gstep) + 1)]
    gzs = [gz0 + i * gstep for i in range(int((gz1 - gz0) / gstep) + 1)]
    gh = [[height_smooth(x, z) + 0.02 for x in gxs] for z in gzs]
    for j in range(len(gzs) - 1):
        for i in range(len(gxs) - 1):
            hs = [gh[j][i], gh[j][i + 1], gh[j + 1][i + 1], gh[j + 1][i]]
            mat = "BankMat" if max(hs) - min(hs) > 1.0 else "GroundMat"
            va = (gxs[i], hs[0], gzs[j])
            vb = (gxs[i + 1], hs[1], gzs[j])
            vc = (gxs[i + 1], hs[2], gzs[j + 1])
            vd = (gxs[i], hs[3], gzs[j + 1])
            add_tri(va, vb, vc, mat, up=True)
            add_tri(va, vc, vd, mat, up=True)
    # Plaza.
    flat_quad(-34, -34, 34, 34, 0.06, "PlazaMat")
    # Canal: floor, water, bank walls, promenades.
    cp = subdivide(CANAL, 9.0)
    ribbon(cp, 44.0, 0.0, "WallMat", heights=[-2.7] * len(cp))
    ribbon(cp, 16.6, 0.0, "WaterMat", heights=[-2.0] * len(cp))
    for sgn in (-1.0, 1.0):
        wall_top = offset_pts(cp, sgn * 8.5)
        for i in range(len(wall_top) - 1):
            a, b = wall_top[i], wall_top[i + 1]
            add_quad((a[0], 0.14, a[1]), (b[0], 0.14, b[1]),
                     (b[0], -2.7, b[1]), (a[0], -2.7, a[1]), "WallMat")
        prom = offset_pts(cp, sgn * 10.6)
        ribbon(prom, 3.4, 0.0, "SideMat", heights=[0.05] * len(prom))
    # Bridges (3) across the canal.
    for bx in (-146.0, 0.0, 121.0):
        box(bx - 5.5, 160, bx + 5.5, 199, -0.6, 0.16, "RoadMat", "WallMat")
    # Roads + sidewalks + centre dashes.
    for (name, pts, w, kind, walk) in ROADS:
        sp = subdivide(pts, 2.5)
        closed = name == "ring"
        ribbon(sp, w, 0.07, "RoadMat", closed=closed)
        if walk:
            for sgn in (-1.0, 1.0):
                off = offset_pts(sp, sgn * (w / 2.0 + 0.85))
                ribbon(off, 1.7, 0.16, "SideMat", closed=closed)
        if name in DASH_ROADS:
            _dashes(sp, closed)
            _edge_lines(sp, w, closed)
    # v5.6 road dressing: zebra crossings at the busy junctions and
    # manhole covers scattered on the carriageway — the v5.3 photos
    # showed clean ribbons with nothing on them.
    _zebra(0, 44, 0.0, 1.0, 16.0)
    _zebra(0, 152, 0.0, 1.0, 16.0)
    _zebra(-100, 138, 1.0, 0.0, 9.0)
    _zebra(100, 138, 1.0, 0.0, 9.0)
    _zebra(124, 62, -0.08, 1.0, 11.0)
    _zebra(95, 55, 0.845, 0.54, 14.0)
    _zebra(-90, 82, 0.778, -0.629, 18.0)
    _manholes()
    # Market street surface reads warmer (stalls zone).
    # Skyway deck: per-segment boxes at y 9.3..10.05 + pillars.
    dp = subdivide(DECK, 11.0)
    for i in range(len(dp) - 1):
        a, b = dp[i], dp[i + 1]
        q = _perp(dp, i)
        hw = 5.5
        c = [(a[0] + q[0] * hw, a[1] + q[1] * hw), (a[0] - q[0] * hw, a[1] - q[1] * hw),
             (b[0] - q[0] * hw, b[1] - q[1] * hw), (b[0] + q[0] * hw, b[1] + q[1] * hw)]
        add_quad((c[0][0], 10.05, c[0][1]), (c[1][0], 10.05, c[1][1]),
                 (c[2][0], 10.05, c[2][1]), (c[3][0], 10.05, c[3][1]), "DeckMat", up=True)
        for s in range(4):
            a2, b2 = c[s], c[(s + 1) % 4]
            add_quad((a2[0], 10.05, a2[1]), (b2[0], 10.05, b2[1]),
                     (b2[0], 9.3, b2[1]), (a2[0], 9.3, a2[1]), "WallMat")
    return dp


def _seg_seg_closest(p1, q1, p2, q2):
    """(distance, midpoint) of the closest points of two segments."""
    d1 = (q1[0] - p1[0], q1[1] - p1[1])
    d2 = (q2[0] - p2[0], q2[1] - p2[1])
    r = (p1[0] - p2[0], p1[1] - p2[1])
    a = d1[0] * d1[0] + d1[1] * d1[1]
    e = d2[0] * d2[0] + d2[1] * d2[1]
    f = d2[0] * r[0] + d2[1] * r[1]
    if a <= 1e-9 and e <= 1e-9:
        return math.hypot(r[0], r[1]), p1
    if a <= 1e-9:
        s, t = 0.0, max(0.0, min(1.0, f / e))
    elif e <= 1e-9:
        t = 0.0
        s = max(0.0, min(1.0, -(d1[0] * r[0] + d1[1] * r[1]) / a))
    else:
        c = d1[0] * r[0] + d1[1] * r[1]
        b = d1[0] * d2[0] + d1[1] * d2[1]
        denom = a * e - b * b
        s = max(0.0, min(1.0, (b * f - c * e) / denom)) if denom > 1e-9 else 0.0
        t = (b * s + f) / e
        if t < 0.0:
            t, s = 0.0, max(0.0, min(1.0, -c / a))
        elif t > 1.0:
            t, s = 1.0, max(0.0, min(1.0, (b - c) / a))
    c1 = (p1[0] + d1[0] * s, p1[1] + d1[1] * s)
    c2 = (p2[0] + d2[0] * t, p2[1] + d2[1] * t)
    return math.hypot(c1[0] - c2[0], c1[1] - c2[1]), \
        ((c1[0] + c2[0]) / 2.0, (c1[1] + c2[1]) / 2.0)


def _compute_junctions():
    """Discs where road paint must stop: the plaza (a pedestrian
    square — no carriageway markings inside), every place two roads
    cross or touch, and every interior road end (a T-junction).
    Real roads paint neither a centre line nor edge lines through
    an intersection."""
    discs = [(0.0, 0.0, 41.0)]

    def add(x, z, r):
        for (cx, cz, _cr) in discs:
            if (x - cx) ** 2 + (z - cz) ** 2 < 36.0:
                return
        discs.append((x, z, r))

    segs = []
    for (name, pts, w, _kind, _walk) in ROADS:
        ss = [(pts[i], pts[i + 1], w) for i in range(len(pts) - 1)]
        if name == "ring":
            ss.append((pts[-1], pts[0], w))
        segs.append((name, ss))
        if name != "ring":
            for p in (pts[0], pts[-1]):
                if max(abs(p[0]), abs(p[1])) < 215.0:
                    add(p[0], p[1], w / 2.0 + 3.0)
    for i in range(len(segs)):
        for j in range(i + 1, len(segs)):
            for (a, b, w1) in segs[i][1]:
                for (c, d, w2) in segs[j][1]:
                    dist, mid = _seg_seg_closest(a, b, c, d)
                    if dist < 1.5:
                        add(mid[0], mid[1], max(w1, w2) / 2.0 + 3.0)
    return discs


JUNCTIONS = _compute_junctions()


def _in_junction(x, z):
    for (cx, cz, r) in JUNCTIONS:
        if (x - cx) ** 2 + (z - cz) ** 2 < r * r:
            return True
    return False

def _dashes(sp, closed):
    seq = list(sp)
    if closed:
        seq = seq + [seq[0]]
    acc = 0.0
    for i in range(len(seq) - 1):
        a, b = seq[i], seq[i + 1]
        seg = math.hypot(b[0] - a[0], b[1] - a[1])
        t = 0.0
        while t < seg:
            if (acc + t) % 9.0 < 3.0:
                t0 = t / seg
                t1 = min(t + 0.9, seg) / seg
                p0 = (a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0)
                p1 = (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)
                mx = (p0[0] + p1[0]) / 2.0
                mz = (p0[1] + p1[1]) / 2.0
                if _in_junction(mx, mz):
                    t += 0.9
                    continue
                q = _perp(seq, i)
                hw = 0.16
                cs = [(p0[0] + q[0] * hw, p0[1] + q[1] * hw),
                      (p0[0] - q[0] * hw, p0[1] - q[1] * hw),
                      (p1[0] - q[0] * hw, p1[1] - q[1] * hw),
                      (p1[0] + q[0] * hw, p1[1] + q[1] * hw)]
                add_quad(*[(cx, height_smooth(cx, cz) + 0.1, cz)
                           for (cx, cz) in cs], "LineMat", up=True)
            t += 0.9
        acc += seg

def _edge_lines(sp, w, closed):
    """Continuous edge lines for the dashed roads: built per segment
    with every corner draped on the height function (the v5.6 lines
    took CENTRELINE heights and bridged bends as floating beams),
    and suppressed inside junction discs — real roads paint no edge
    line through an intersection or across the plaza."""
    seq = list(sp)
    if closed:
        seq = seq + [seq[0]]
    for sgn in (-1.0, 1.0):
        off = offset_pts(seq, sgn * (w / 2.0 - 0.45))
        for i in range(len(off) - 1):
            a, b = off[i], off[i + 1]
            if _in_junction((a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0):
                continue
            q = _perp(off, i)
            hw = 0.07
            cs = [(a[0] + q[0] * hw, a[1] + q[1] * hw),
                  (a[0] - q[0] * hw, a[1] - q[1] * hw),
                  (b[0] - q[0] * hw, b[1] - q[1] * hw),
                  (b[0] + q[0] * hw, b[1] + q[1] * hw)]
            add_quad(*[(cx, height_smooth(cx, cz) + 0.085, cz)
                       for (cx, cz) in cs], "LineMat", up=True)

def _zebra(cx, cz, dx, dz, road_w):
    """Zebra crossing: 5 bars elongated across the road, repeated
    along the road direction (dx, dz) (unit). All call sites are on
    flat ground, so one sampled height serves the whole crossing."""
    y = height_smooth(cx, cz) + 0.09
    px, pz = -dz, dx
    bar_l = (road_w - 2.0) / 2.0
    bar_w = 0.275
    for k in range(5):
        t = (k - 2.0) * 1.1
        bx, bz = cx + dx * t, cz + dz * t
        ax, az = px * bar_l, pz * bar_l
        lx, lz = dx * bar_w, dz * bar_w
        add_quad((bx + ax + lx, y, bz + az + lz),
                 (bx - ax + lx, y, bz - az + lz),
                 (bx - ax - lx, y, bz - az - lz),
                 (bx + ax - lx, y, bz + az - lz), "LineMat", up=True)

def _disc(cx, cz, r, y, mat):
    prev = None
    for k in range(9):
        ang = math.radians(k * 45.0)
        pt = (cx + math.cos(ang) * r, y, cz + math.sin(ang) * r)
        if prev is not None:
            add_tri((cx, y, cz), prev, pt, mat, up=True)
        prev = pt

def _manholes():
    rng = random.Random(56)
    for (name, pts, w, kind, walk) in ROADS:
        if kind == "switch":
            continue
        sp = subdivide(pts, 7.0)
        nxt = rng.uniform(6.0, 16.0)
        dist = 0.0
        for i in range(len(sp) - 1):
            a, b = sp[i], sp[i + 1]
            seg = math.hypot(b[0] - a[0], b[1] - a[1])
            while seg > 0.0 and nxt <= dist + seg:
                tt = (nxt - dist) / seg
                mx = a[0] + (b[0] - a[0]) * tt
                mz = a[1] + (b[1] - a[1]) * tt
                q = _perp(sp, i)
                sgn = 1.0 if rng.random() < 0.5 else -1.0
                ox = mx + q[0] * sgn * w * 0.22
                oz = mz + q[1] * sgn * w * 0.22
                _disc(ox, oz, 0.55, height_smooth(ox, oz) + 0.082,
                      "ApronMat")
                nxt += rng.uniform(19.0, 30.0)
            dist += seg

PILLAR_SPOTS = []

def collect_pillars(dp):
    acc = 0.0
    for i in range(len(dp) - 1):
        a, b = dp[i], dp[i + 1]
        seg = math.hypot(b[0] - a[0], b[1] - a[1])
        t = 0.0
        while t < seg:
            if acc % 34.0 < 11.0 and t == 0.0:
                # Never plant a pillar in a street below: the deck
                # cantilevers over crossings instead (a centre-road
                # pillar dead-stopped the v24 climb car).
                clear = True
                for (_n, pts, w, _k, _s) in ROADS:
                    sp = subdivide(pts, 14.0)
                    for j in range(len(sp) - 1):
                        if _seg_dist(a[0], a[1], sp[j], sp[j + 1]) < w / 2.0 + 2.2:
                            clear = False
                if clear:
                    PILLAR_SPOTS.append(a)
            t += seg
        acc += seg

# ---------------------------------------------------------------- plots

def _seg_dist(px, pz, a, b):
    vx, vz = b[0] - a[0], b[1] - a[1]
    wx, wz = px - a[0], pz - a[1]
    c1 = vx * wx + vz * wz
    c2 = vx * vx + vz * vz
    t = 0.0 if c2 <= 0 else max(0.0, min(1.0, c1 / c2))
    dx = wx - vx * t
    dz = wz - vz * t
    return math.hypot(dx, dz)

def _road_dist(x, z):
    best = 1e9
    for (_n, pts, w, _k, _s) in ROADS:
        sp = subdivide(pts, 14.0)
        for i in range(len(sp) - 1):
            best = min(best, _seg_dist(x, z, sp[i], sp[i + 1]) - w / 2.0)
    # canal + deck count as obstacles for plots too (a tall plot under
    # the skyway would poke through the deck)
    csp = subdivide(CANAL, 14.0)
    for i in range(len(csp) - 1):
        best = min(best, _seg_dist(x, z, csp[i], csp[i + 1]) - 13.0)
    dsp = subdivide(DECK, 14.0)
    for i in range(len(dsp) - 1):
        best = min(best, _seg_dist(x, z, dsp[i], dsp[i + 1]) - 8.0)
    return best

def gen_plots():
    rng = random.Random(7)
    plots = []
    heroes = [(-52, -128, 52, -72), (-112, 60, -66, 106), (74, 34, 116, 76)]
    cand = []
    for gx in range(-214, 215, 17):
        for gz in range(-214, 215, 17):
            cand.append((gx + rng.uniform(-3, 3), gz + rng.uniform(-3, 3)))
    cand.sort(key=lambda p: math.hypot(p[0], p[1]))  # downtown wins overlaps
    for (x, z) in cand:
            if abs(x) < 42 and abs(z) < 42:
                continue  # plaza
            skip = False
            for (hx1, hz1, hx2, hz2) in heroes:
                if hx1 - 4 < x < hx2 + 4 and hz1 - 4 < z < hz2 + 4:
                    skip = True
            if skip:
                continue
            pw = rng.uniform(11, 16.5)
            pd = rng.uniform(11, 16.5)
            # centre must clear every road edge by half the plot + 1.2m
            if _road_dist(x, z) < max(pw, pd) * 0.62 + 1.2:
                continue
            # ... and stay off the terrace embankments (sloped ground
            # would leave the base floating / buried). Plots INSIDE a
            # terrace rect sit on its flat top and are fine.
            bank_bad = False
            for (tx1, tz1, tx2, tz2, _th) in TERRACES:
                ddx = max(tx1 - x, 0.0, x - tx2)
                ddz = max(tz1 - z, 0.0, z - tz2)
                dout = math.hypot(ddx, ddz)
                if 0.0 < dout < PLOT_BANK_W + 1.5:
                    bank_bad = True
                    break
            if bank_bad:
                continue
            # no two plots may touch (1.5m fire gap, AABB approximation)
            clash = False
            for q in plots:
                if abs(x - q["x"]) < (pw + q["w"]) / 2.0 + 1.5 and \
                   abs(z - q["z"]) < (pd + q["d"]) / 2.0 + 1.5:
                    clash = True
                    break
            if clash:
                continue
            y = height_at(x, z)
            d = math.hypot(x, z)
            if d < 95:
                h = rng.uniform(34, 95)
            elif d < 165:
                h = rng.uniform(18, 48)
            elif y > 0:
                h = rng.uniform(8, 18)
            else:
                h = rng.uniform(8, 26)
            if x < -110:
                style = "ent"
            elif x > 115 and z < 60:
                style = "mil"
            elif y > 0:
                style = "kit"
            elif z > 110:
                style = "ent" if rng.random() < 0.5 else "kit"
            else:
                style = ["ent", "kit", "mil"][rng.randrange(3)]
            w = pw
            dep = pd
            rot = 0.0
            # diagonal avenues tilt nearby plots
            da = _seg_dist(x, z, (-120, 110), (-52, 55))
            db = _seg_dist(x, z, (58, 32), (130, 78))
            if min(da, db) < 34:
                rot = 0.68 if da < db else -0.69
            kit = max(w, dep) <= 21.5 and h <= 27 and rng.random() < 0.8
            plots.append({"x": round(x, 1), "z": round(z, 1), "y": y,
                          "w": round(w, 1), "d": round(dep, 1),
                          "rot": rot, "h": round(h, 1), "style": style,
                          "kit": kit})
    return plots

# ---------------------------------------------------------------- main

def main():
    if os.environ.get("V56_DUMP"):
        # Cross-check samples for tests/v56_test.gd: dump height_smooth
        # on transects + a coarse grid over the terrace quadrant, then
        # stop before touching any Blender state.
        pts = []
        x = 30.0
        while x <= 230.0:
            z = -230.0
            while z <= -30.0:
                pts.append((x, z))
                z += 9.7
            x += 9.3
        for (ax, az, bx, bz) in ((30.0, -100.0, 230.0, -100.0),
                                 (150.0, -40.0, 150.0, -170.0),
                                 (52.0, -55.0, 152.0, -124.0),
                                 (105.0, -92.0, 196.0, -205.0)):
            for k in range(41):
                t = k / 40.0
                pts.append((ax + (bx - ax) * t, az + (bz - az) * t))
        with open("/tmp/v56_samples.json", "w") as f:
            json.dump([[round(px, 2), round(pz, 2),
                        round(height_smooth(px, pz), 4)]
                       for (px, pz) in pts], f)
        print("V56_DUMP_OK", len(pts))
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mats = {}
    for name in ("GroundMat", "RoadMat", "SideMat", "PlazaMat", "WaterMat",
                 "WallMat", "DeckMat", "LineMat", "ApronMat", "BankMat"):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        mats[name] = m
    dp = build_geometry()
    collect_pillars(dp)

    verts = []
    polys = []
    poly_mat = []
    mat_index = {name: i for i, name in enumerate(mats)}
    for (pts, mat) in FACES:
        base = len(verts)
        verts.extend(pts)
        polys.append(tuple(range(base, base + len(pts))))
        poly_mat.append(mat_index[mat])
    mesh = bpy.data.meshes.new("TerrainV4")
    mesh.from_pydata(verts, [], polys)
    mesh.update()
    for i, poly in enumerate(mesh.polygons):
        poly.material_index = poly_mat[i]
    obj = bpy.data.objects.new("TerrainV4", mesh)
    bpy.context.collection.objects.link(obj)
    for name, m in mats.items():
        mesh.materials.append(m)
    # fix material indices after append order (append follows dict order)
    # (from_pydata + append in same order keeps indices aligned)

    # Plaza holo disc base + pillars as real objects.
    bpy.ops.mesh.primitive_cylinder_add(radius=7.0, depth=0.12,
                                        location=(0, 0, 0.1))
    disc = bpy.context.object
    disc.name = "PlazaDisc"
    disc.data.materials.append(mats["LineMat"])
    for (x, z) in PILLAR_SPOTS:
        g = height_at(x, z)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.9, depth=9.3 - g,
                                            vertices=10,
                                            location=(x, -z, g + (9.3 - g) / 2.0))
        pil = bpy.context.object
        pil.name = "SkywayPillar"
        pil.data.materials.append(mats["WallMat"])

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT_DIR, "terrain_v4.glb"),
                              export_format="GLB", export_yup=True)

    layout = {
        "roads": [{"name": n, "pts": [list(p) for p in pts], "w": w, "kind": k}
                  for (n, pts, w, k, _s) in ROADS],
        "canal": [list(p) for p in CANAL],
        "deck": [list(p) for p in DECK],
        "plots": gen_plots(),
        "heroes": {
            "mega": {"x": 0, "z": -100, "w": 104, "d": 56, "h": 110},
            "arch": {"x": -89, "z": 83, "rot": 0.68, "h": 38},
            "cylinder": {"x": 95, "z": 55, "r": 14, "h": 64},
        },
        "pois": {
            "spawn": [0, 0.3, 48],
            "clinic": [38, 0.3, 22],
            "kiosks": [[24, 0.3, -24], [-60, 0.3, 130], [-8, 0.3, 156],
                       [150, 12.3, -116], [-172, 0.3, 42]],
            "terminals": [[58, 0.3, 26], [-96, 0.3, 126], [150, 12.3, -104],
                          [-160, 0.3, -30]],
            "pickups": [[-14, 0.3, 118], [92, 0.3, 130], [168, 6.3, -92],
                        [-118, 0.3, -88]],
        },
        "walk_blocks": [
            {"cx": 0, "cz": 0, "half": 26, "y": 0.06},
            {"cx": 40, "cz": 122, "half": 13, "y": 0.0},
            {"cx": -120, "cz": 164, "half": 6, "y": 0.0},
            {"cx": -180, "cz": 20, "half": 18, "y": 0.0},
            {"cx": 170, "cz": 58, "half": 17, "y": 0.0},
            {"cx": 150, "cz": -136, "half": 15, "y": 12.0},
            {"cx": 90, "cz": -95, "half": 11, "y": 6.0},
        ],
        "race_points": [[0, 80], [120, -30], [-86, 82], [150, -100],
                        [0, 150], [-150, -100], [60, 120], [-40, -160],
                        [170, 60], [-170, 120]],
        "pillars": [[round(p[0], 1), round(p[1], 1)] for p in PILLAR_SPOTS],
    }
    with open(os.path.join(OUT_DIR, "layout_v4.json"), "w") as f:
        json.dump(layout, f)
    # The layout also ships as a GDScript const: loose .json/.txt
    # files are NOT included in Godot web exports, a .gd always is.
    gd = ("class_name LayoutV4\nextends RefCounted\n"
          "## GENERATED by blender/build_terrain_v4.py from the v4 layout\n"
          "## (design/v4_layout.md). Do not edit by hand.\n"
          "const DATA := " + json.dumps(layout) + "\n")
    with open(os.path.expanduser("~/workspace/godot_neon/layout_v4.gd"), "w") as f:
        f.write(gd)
    print("TERRAIN_V4_OK faces:", len(FACES), "plots:", len(layout["plots"]),
          "pillars:", len(PILLAR_SPOTS))

main()
