"""NEON CITY v3 building kits: three Cyberpunk-2077 style kits
(Entropism / Kitsch / Neo-Militarism), three ground-floor shop modules
and two perpendicular blade signs.

Every textured face is UV-mapped into blender/paint_atlas.py's kit
atlas. Materials are exported UNTEXURED on purpose: Godot re-applies
the atlas by material name (KitShade = shaded PBR, KitGlow = unshaded
neon, KitDark = dark metal, KitPlastic / KitYellow = solid accents),
which keeps the GLBs tiny and dodges the WebGL emission blow-out.

Front of every kit faces Blender -Y (Godot +Z after glTF conversion),
matching build_facade.py. Run:
  blender --background --python blender/build_kits_v3.py
Outputs assets/kits/*.glb + preview renders in /tmp/kit_previews/.
"""
import bpy
import math
import os
import random
from mathutils import Vector

ROOT = "/home/hatch/workspace/godot_neon"
OUT = os.path.join(ROOT, "assets", "kits")
PREV = "/tmp/kit_previews"
os.makedirs(OUT, exist_ok=True)
os.makedirs(PREV, exist_ok=True)
ATLAS = os.path.join(ROOT, "assets", "textures", "kit_atlas.jpg")

# Atlas regions (u0, v0, u1, v1) — mirror of paint_atlas.py.
ENT = (0.0, 0.5, 0.5, 1.0)
KITW = (0.5, 0.5625, 1.0, 1.0)
MIL = (0.0, 0.25, 0.4375, 0.5)
STORE = (0.4375, 0.3125, 1.0, 0.5625)
PANES = (0.5, 0.125, 1.0, 0.3125)
SIGN_Y = (0.0, 0.0, 0.25, 0.125)
SIGN_C = (0.25, 0.0, 0.5, 0.125)
SIGN_P = (0.5, 0.0, 0.75, 0.125)
HAZARD = (0.75, 0.0, 0.875, 0.125)
SHUTTER = (0.875, 0.0, 1.0, 0.125)
AWNING = (0.0, 0.125, 0.125, 0.25)
POSTER = (0.125, 0.125, 0.25, 0.25)
GRILLE = (0.25, 0.125, 0.375, 0.25)
METAL = (0.375, 0.125, 0.5, 0.25)


def pane_cell(col, row):
    """One cell of the 8x3 pane grid (row 0 = warm, 1 = cool, 2 = dim/bright)."""
    cw = (PANES[2] - PANES[0]) / 8.0
    ch = (PANES[3] - PANES[1]) / 3.0
    u0 = PANES[0] + col * cw
    v1 = PANES[3] - row * ch
    return (u0 + 0.004, v1 - ch + 0.004, u0 + cw - 0.004, v1 - 0.004)


MATS = {}


def make_mats():
    img = bpy.data.images.load(ATLAS)

    def plain(name, color, rough=0.8, metal=0.0):
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        b.inputs["Base Color"].default_value = (*color, 1.0)
        b.inputs["Roughness"].default_value = rough
        b.inputs["Metallic"].default_value = metal
        return m

    shade = plain("KitShade", (0.9, 0.9, 0.9), 0.85)
    tex = shade.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    shade.node_tree.links.new(tex.outputs["Color"],
                              shade.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    glow = plain("KitGlow", (0.05, 0.05, 0.05), 0.6)
    tex2 = glow.node_tree.nodes.new("ShaderNodeTexImage")
    tex2.image = img
    glow.node_tree.links.new(tex2.outputs["Color"],
                             glow.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
    MATS.update({
        "KitShade": shade, "KitGlow": glow,
        "KitDark": plain("KitDark", (0.10, 0.10, 0.13), 0.55, 0.45),
        "KitPlastic": plain("KitPlastic", (0.05, 0.62, 0.66), 0.35),
        "KitYellow": plain("KitYellow", (0.99, 0.93, 0.04), 0.5),
    })


def _remap_face(uv, poly, rect):
    """Normalise one polygon's own UV bbox onto rect.

    Blender's primitive cube uses a net layout — each face owns only
    a small tile of UV space, NOT the full 0..1 — so a plain affine
    remap leaves every face sampling a sliver of the atlas. Mapping
    each face's own bbox onto the target rect is the correct move
    for box-built kits (and harmless for pane discs, whose cap UV
    circle already spans its bbox)."""
    ls = [uv[li] for li in poly.loop_indices]
    us = [l.uv.x for l in ls]
    vs = [l.uv.y for l in ls]
    u0, u1 = min(us), max(us)
    v0, v1 = min(vs), max(vs)
    du = (u1 - u0) or 1.0
    dv = (v1 - v0) or 1.0
    for l in ls:
        l.uv = (rect[0] + (l.uv.x - u0) / du * (rect[2] - rect[0]),
                rect[1] + (l.uv.y - v0) / dv * (rect[3] - rect[1]))


def uv_rect(obj, rect):
    uv = obj.data.uv_layers.active.data
    for poly in obj.data.polygons:
        _remap_face(uv, poly, rect)


def uv_box(obj, side_rect, top_rect=None):
    """Map a box: vertical faces -> side_rect, +-Z faces -> top_rect."""
    if top_rect is None:
        top_rect = side_rect
    mesh = obj.data
    uv = mesh.uv_layers.active.data
    for poly in mesh.polygons:
        _remap_face(uv, poly, top_rect if abs(poly.normal.z) > 0.5 else side_rect)


def box(name, loc, size, mat, rect=None, top_rect=None, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        o.data.materials.append(mat)
    if rect is not None:
        if top_rect is not None:
            uv_box(o, rect, top_rect)
        else:
            uv_rect(o, rect)
    return o


def cyl(name, loc, radius, depth, mat, rect=None, rot=(0, 0, 0), verts=14):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=loc,
                                        rotation=rot, vertices=verts)
    o = bpy.context.object
    o.name = name
    if mat:
        o.data.materials.append(mat)
    if rect is not None:
        uv_rect(o, rect)
    return o


def ground_band(parts, w, d, sign_rect, awning=False, shutter_side=False):
    """Shared 4.2 m lit storefront band wrapped around a tower footprint."""
    s, g, dk = MATS["KitShade"], MATS["KitGlow"], MATS["KitDark"]
    parts.append(box("Band", (0, 0, 2.1), (w + 0.3, d + 0.3, 4.2), s, STORE, METAL))
    # Corner posts.
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box("Post", (sx * (w / 2 + 0.12), sy * (d / 2 + 0.12), 2.1),
                             (0.34, 0.34, 4.2), dk))
    # Sign boards front + back.
    for sy in (-1, 1):
        parts.append(box("Sign", (0, sy * (d / 2 + 0.3), 3.62),
                         (w * 0.56, 0.2, 1.05), g, sign_rect))
    if awning:
        parts.append(box("Awning", (0, -(d / 2 + 0.75), 3.3), (w * 0.8, 1.5, 0.09),
                         s, AWNING, rot=(math.radians(18), 0, 0)))
    if shutter_side:
        parts.append(box("ShutterDoor", (w / 2 + 0.2, -d * 0.18, 1.5),
                         (0.14, 3.2, 3.0), s, SHUTTER))


def wall_panes(parts, w, d, band, top, cols, rows, pw, ph, lit, rng,
               warm_share=0.7, disc_r=0.0):
    """Glow pane quads (or discs) over the painted window grid, 4 faces."""
    g = MATS["KitGlow"]
    span = top - band
    for face in range(4):
        for c in range(cols):
            for r in range(rows):
                if rng.random() > lit:
                    continue
                along = -w / 2 + (c + 0.5) * (w / cols) if face < 2 else -d / 2 + (c + 0.5) * (d / cols)
                y = band + (r + 0.5) * (span / rows)
                warm = rng.random() < warm_share
                cell = pane_cell(rng.randrange(8), 0 if warm else 1)
                if face == 0:
                    pos, rot = (along, -d / 2 - 0.05, y), (0, 0, 0)
                elif face == 1:
                    pos, rot = (along, d / 2 + 0.05, y), (0, 0, 0)
                elif face == 2:
                    pos, rot = (w / 2 + 0.05, along, y), (0, 0, 0)
                else:
                    pos, rot = (-w / 2 - 0.05, along, y), (0, 0, 0)
                if disc_r > 0:
                    # Cylinder axis is +Z: rot X 90 lays it to +-Y
                    # (front/back faces), rot Y 90 lays it to +-X
                    # (side faces).
                    rrot = (math.radians(90), 0, 0) if face < 2 else (0, math.radians(90), 0)
                    parts.append(cyl("Pane", pos, disc_r, 0.07, g, cell, rot=rrot, verts=12))
                elif face < 2:
                    parts.append(box("Pane", pos, (pw, 0.07, ph), g, cell))
                else:
                    parts.append(box("Pane", pos, (0.07, pw, ph), g, cell))


def tower_ent(rng):
    parts = []
    s, g, dk = MATS["KitShade"], MATS["KitGlow"], MATS["KitDark"]
    W, D, H, BAND = 14.0, 14.0, 22.0, 4.2
    parts.append(box("Mass", (0, 0, BAND + (H - BAND) / 2), (W, D, H - BAND), s, ENT, METAL))
    ground_band(parts, W, D, SIGN_P, shutter_side=True)
    wall_panes(parts, W, D, BAND, H, 6, 8, 1.2, 1.25, 0.42, rng)
    # External pipes on the front corners + wall AC units (grille faces).
    for sx in (-1, 1):
        parts.append(cyl("Pipe", (sx * (W / 2 - 0.8), -D / 2 - 0.16, BAND + (H - BAND) / 2),
                         0.09, H - BAND, dk, verts=8))
    for i in range(6):
        fx = rng.uniform(-W / 2 + 1.5, W / 2 - 1.5)
        fy = rng.uniform(BAND + 2.0, H - 2.0)
        side = rng.choice([-1, 1])
        parts.append(box("AC", (fx, side * (D / 2 + 0.2), fy), (0.95, 0.4, 0.7), s, GRILLE))
    # Parapet + roof clutter: water tank, vent box.
    parts.append(box("Parapet", (0, 0, H + 0.3), (W + 0.5, D + 0.5, 0.6), dk))
    parts.append(cyl("Tank", (W * 0.26, D * 0.2, H + 1.5), 1.15, 2.4, dk, verts=12))
    parts.append(box("Vent", (-W * 0.28, -D * 0.22, H + 0.8), (1.8, 1.5, 1.1), s, METAL))
    return parts


def tower_kit(rng):
    parts = []
    s, g, dk = MATS["KitShade"], MATS["KitGlow"], MATS["KitDark"]
    W, D, H, BAND = 13.0, 13.0, 17.0, 4.2
    parts.append(box("Mass", (0, 0, BAND + (H - BAND) / 2), (W, D, H - BAND), s, KITW, METAL))
    # Rounded plastic corner columns + yellow roof band (the fingerprint).
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(cyl("Corner", (sx * W / 2, sy * D / 2, H / 2), 0.85, H,
                             MATS["KitPlastic"], verts=12))
    parts.append(box("RoofBand", (0, 0, H - 0.25), (W + 0.6, D + 0.6, 0.5), MATS["KitYellow"]))
    ground_band(parts, W, D, SIGN_Y, awning=True)
    wall_panes(parts, W, D, BAND, H, 5, 6, 0, 0, 0.5, rng, warm_share=0.85, disc_r=0.68)
    parts.append(cyl("Antenna", (W * 0.3, -D * 0.3, H + 1.4), 0.05, 2.8, dk, verts=6))
    return parts


def tower_mil(rng):
    parts = []
    s, g, dk = MATS["KitShade"], MATS["KitGlow"], MATS["KitDark"]
    W, D, H, BAND = 16.0, 16.0, 32.0, 4.2
    parts.append(box("Mass", (0, 0, BAND + (H - BAND) / 2), (W, D, H - BAND), s, MIL, METAL))
    parts.append(box("Band", (0, 0, 2.1), (W + 0.3, D + 0.3, BAND), s, STORE, METAL))
    # Vertical fins: corners + mid-edge, clean corporate rhythm.
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(box("Fin", (sx * (W / 2 + 0.18), sy * (D / 2 + 0.18), H / 2),
                             (0.4, 0.4, H), dk))
    for a in (-W * 0.25, 0.0, W * 0.25):
        parts.append(box("FinF", (a, -D / 2 - 0.16, H / 2), (0.35, 0.35, H), dk))
        parts.append(box("FinB", (a, D / 2 + 0.16, H / 2), (0.35, 0.35, H), dk))
    # Sparse cool office panes; a few bright ones.
    span = H - BAND
    for face in range(4):
        for c in range(8):
            for r in range(6):
                roll = rng.random()
                if roll > 0.22:
                    continue
                along = -W / 2 + (c + 0.5) * (W / 8)
                y = BAND + (r + 0.5) * (span / 6)
                cell = pane_cell(4 if roll < 0.05 else rng.randrange(8), 2 if roll < 0.05 else 1)
                if face == 0:
                    parts.append(box("Pane", (along, -D / 2 - 0.05, y), (1.6, 0.07, 3.0), g, cell))
                elif face == 1:
                    parts.append(box("Pane", (along, D / 2 + 0.05, y), (1.6, 0.07, 3.0), g, cell))
                elif face == 2:
                    parts.append(box("Pane", (W / 2 + 0.05, along, y), (0.07, 1.6, 3.0), g, cell))
                else:
                    parts.append(box("Pane", (-W / 2 - 0.05, along, y), (0.07, 1.6, 3.0), g, cell))
    # Entrance canopy + crown light strip.
    parts.append(box("Canopy", (0, -D / 2 - 1.5, 3.9), (9.0, 3.4, 0.3), dk))
    parts.append(box("Crown", (0, 0, H - 0.35), (W + 0.45, D + 0.45, 0.45), g,
                     pane_cell(4, 2)))
    parts.append(box("RoofBox", (W * 0.2, D * 0.18, H + 0.75), (3.4, 2.8, 1.5), dk))
    return parts


def shop(variant, rng):
    parts = []
    s, g, dk = MATS["KitShade"], MATS["KitGlow"], MATS["KitDark"]
    W = 11.0
    parts.append(box("BackWall", (0, 0.8, 2.1), (W, 0.5, 4.2), dk))
    parts.append(box("Glass", (0, 0.02, 1.5), (9.6, 0.14, 2.6), s, STORE))
    for i, mx in enumerate([-4.8, -2.4, 0.0, 2.4, 4.8]):
        parts.append(box("Mull%d" % i, (mx, -0.06, 1.5), (0.16, 0.1, 2.7), dk))
    parts.append(box("Header", (0, 0.1, 3.15), (10.4, 0.34, 0.42), dk))
    parts.append(box("Step", (0, -0.5, 0.1), (10.2, 1.6, 0.2), dk))
    sign_rect = {"a": SIGN_C, "b": SIGN_Y, "c": SIGN_P}[variant]
    if variant == "a":
        parts.append(box("Sign", (0, -0.18, 3.68), (7.6, 0.2, 1.05), g, sign_rect))
        parts.append(box("Awning", (0, -0.8, 3.32), (10.0, 1.5, 0.09), s, AWNING,
                         rot=(math.radians(18), 0, 0)))
    elif variant == "b":  # food stall: counter + pole canopy + hanging sign
        parts.append(box("Counter", (0, -0.95, 0.55), (9.4, 1.0, 1.1), dk))
        for px_ in (-4.9, 4.9):
            parts.append(cyl("Pole", (px_, -1.6, 1.9), 0.06, 3.8, dk, verts=8))
        parts.append(box("Canopy", (0, -0.85, 3.85), (10.6, 2.6, 0.1), s, AWNING,
                         rot=(math.radians(10), 0, 0)))
        parts.append(box("Sign", (-2.6, -0.2, 3.68), (4.6, 0.2, 1.0), g, sign_rect))
        parts.append(box("HangSign", (3.1, -1.55, 2.8), (2.2, 0.14, 0.8), g, SIGN_P))
    else:  # entropism front: shutter + poster + small sign + AC
        parts.append(box("Shutter", (-2.2, -0.1, 1.5), (5.6, 0.16, 2.9), s, SHUTTER))
        parts.append(box("Poster", (3.4, -0.12, 1.6), (1.5, 0.08, 1.9), s, POSTER))
        parts.append(box("Sign", (2.9, -0.18, 3.6), (3.6, 0.2, 0.85), g, sign_rect))
        parts.append(box("AC", (-3.9, 0.1, 3.6), (1.1, 0.5, 0.8), s, GRILLE))
    return parts


def blade(yellow, rng):
    parts = []
    g, dk = MATS["KitGlow"], MATS["KitDark"]
    parts.append(cyl("Arm", (0, -0.55, 1.15), 0.05, 1.1, dk, rot=(math.radians(90), 0, 0), verts=8))
    rect = SIGN_Y if yellow else SIGN_C
    h = 1.8 if yellow else 2.4
    parts.append(box("Sign", (0, -1.15, 0), (0.16, 1.0, h), g, rect))
    return parts


BUILDERS = {
    "tower_ent": lambda r: tower_ent(r),
    "tower_kit": lambda r: tower_kit(r),
    "tower_mil": lambda r: tower_mil(r),
    "shop_a": lambda r: shop("a", r),
    "shop_b": lambda r: shop("b", r),
    "shop_c": lambda r: shop("c", r),
    "blade_sign": lambda r: blade(False, r),
    "blade_sign_y": lambda r: blade(True, r),
}


def render_preview(name, w, h):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 48
    scene.cycles.device = "CPU"
    scene.render.resolution_x = 560
    scene.render.resolution_y = 420
    scene.render.filepath = os.path.join(PREV, name + ".png")
    world = bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.012, 0.014, 0.03, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.5
    bpy.ops.object.light_add(type="SUN", location=(30, -20, 60))
    sun = bpy.context.object
    sun.data.energy = 1.2
    sun.data.color = (0.75, 0.8, 1.0)
    bpy.ops.object.camera_add(location=(w * 1.05, -w * 1.65, h * 0.62))
    cam = bpy.context.object
    direction = Vector((0, 0, h * 0.42)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    # Preview-only: make KitGlow actually glow.
    glow = MATS["KitGlow"]
    bsdf = glow.node_tree.nodes["Principled BSDF"]
    tex = [n for n in glow.node_tree.nodes if n.type == "TEX_IMAGE"][0]
    glow.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 1.5
    bpy.ops.render.render(write_still=True)
    # Strip the preview-only emission before export.
    for link in list(glow.node_tree.links):
        if link.to_socket.name == "Emission Color":
            glow.node_tree.links.remove(link)
    bsdf.inputs["Emission Strength"].default_value = 0.0
    bpy.data.objects.remove(sun, do_unlink=True)
    bpy.data.objects.remove(cam, do_unlink=True)


def main():
    for name, build in BUILDERS.items():
        bpy.ops.wm.read_factory_settings(use_empty=True)
        make_mats()
        rng = random.Random(hash(name) & 0xFFFF)
        parts = build(rng)
        bpy.ops.object.select_all(action="DESELECT")
        for p in parts:
            p.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        bpy.ops.object.join()
        kit = bpy.context.object
        kit.name = name
        dims = {"tower_ent": (14, 22), "tower_kit": (13, 17), "tower_mil": (16, 32),
                "shop_a": (11, 5), "shop_b": (11, 5), "shop_c": (11, 5),
                "blade_sign": (2.5, 3), "blade_sign_y": (2.5, 3)}[name]
        if os.environ.get("SKIP_PREVIEW") != "1":
            render_preview(name, dims[0], dims[1])
        # Export untextured: Godot re-applies the atlas by material name.
        for mname in ("KitShade", "KitGlow"):
            m = MATS[mname]
            for link in list(m.node_tree.links):
                if link.from_node.type == "TEX_IMAGE":
                    m.node_tree.links.remove(link)
        bpy.ops.object.select_all(action="DESELECT")
        kit.select_set(True)
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"),
                                  export_format="GLB", use_selection=True,
                                  export_apply=True)
        print("built", name, "parts:", len(parts))


main()
