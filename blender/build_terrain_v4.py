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
BANK_W = 20.0  # embankment width around each terrace (20 m keeps the
# steepest bank at ~24 deg so cars can climb the road ramps)

def height_at(x, z):
    """Stepped terrace heights (NE hills)."""
    if x >= 142.0 and z <= -152.0:
        return 18.0
    if x >= 104.0 and z <= -114.0:
        return 12.0
    if x >= 66.0 and z <= -76.0:
        return 6.0
    return 0.0

def height_smooth(x, z):
    """Terrace height with embankment falloff: roads and banks sample
    this so a road crossing a terrace edge ramps WITH the ground
    instead of grinding into a vertical retaining wall."""
    best = 0.0
    for (x1, z1, x2, z2, h) in TERRACES:
        dx = max(x1 - x, 0.0, x - x2)
        dz = max(z1 - z, 0.0, z - z2)
        d = math.hypot(dx, dz)
        if d <= 0.0:
            best = max(best, h)
        elif d < BANK_W:
            t = 1.0 - d / BANK_W
            best = max(best, h * (t * t * (3.0 - 2.0 * t)))
    return best

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

def _terrace_ring(x1, z1, x2, z2, d, h):
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
            pts.append((qx, y, qz))
        # corner arc at b (degenerate to the corner point when d=0)
        steps = 4
        for k in range(1, steps + 1):
            ang = math.radians(a0 + (a1 - a0) * k / steps)
            qx, qz = b[0] + math.cos(ang) * d, b[1] + math.sin(ang) * d
            y = h if d == 0.0 else height_smooth(qx, qz)
            pts.append((qx, y, qz))
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
    """Flat ribbon following a polyline in XZ. heights: per-point Y or
    None -> terrain height_at + lift."""
    seq = list(pts)
    if closed:
        seq = seq + [seq[0]]
    hs = []
    for i, (x, z) in enumerate(seq):
        base = heights[i] if heights is not None else height_smooth(x, z)
        hs.append(base + lift)
    for i in range(len(seq) - 1):
        p0, p1 = seq[i], seq[i + 1]
        q0, q1 = _perp(seq, i), _perp(seq, i + 1)
        hw = width / 2.0
        L0 = (p0[0] + q0[0] * hw, hs[i], p0[1] + q0[1] * hw)
        R0 = (p0[0] - q0[0] * hw, hs[i], p0[1] - q0[1] * hw)
        L1 = (p1[0] + q1[0] * hw, hs[i + 1], p1[1] + q1[1] * hw)
        R1 = (p1[0] - q1[0] * hw, hs[i + 1], p1[1] - q1[1] * hw)
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
        flat_quad(x1, z1, x2, z2, h, "GroundMat")
        rings = [_terrace_ring(x1, z1, x2, z2, d, h) for d in (0.0, BANK_W * 0.5, BANK_W)]
        for r in range(2):
            ra, rb = rings[r], rings[r + 1]
            for i in range(len(ra)):
                a0, a1 = ra[i], ra[(i + 1) % len(ra)]
                b0, b1 = rb[i], rb[(i + 1) % len(rb)]
                # up=True is load-bearing: a flipped bank quad reads
                # as a ceiling to move_and_slide and traps cars under
                # the sheet (found by the v24 climb test).
                add_quad(a0, a1, b1, b0, "BankMat", up=True)
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
        sp = subdivide(pts, 7.0)
        closed = name == "ring"
        ribbon(sp, w, 0.07, "RoadMat", closed=closed)
        if walk:
            for sgn in (-1.0, 1.0):
                off = offset_pts(sp, sgn * (w / 2.0 + 0.85))
                ribbon(off, 1.7, 0.16, "SideMat", closed=closed)
        if name in DASH_ROADS:
            _dashes(sp, closed)
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
                y0 = height_smooth(p0[0], p0[1]) + 0.1
                y1 = height_smooth(p1[0], p1[1]) + 0.1
                q = _perp(seq, i)
                hw = 0.16
                add_quad((p0[0] + q[0] * hw, y0, p0[1] + q[1] * hw),
                         (p0[0] - q[0] * hw, y0, p0[1] - q[1] * hw),
                         (p1[0] - q[0] * hw, y1, p1[1] - q[1] * hw),
                         (p1[0] + q[0] * hw, y1, p1[1] + q[1] * hw), "LineMat", up=True)
            t += 0.9
        acc += seg

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
                if 0.0 < dout < BANK_W + 1.5:
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
