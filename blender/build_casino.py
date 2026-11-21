"""NEON PEARL casino - Blender model builder.
Builds 14 casino models, exports individual GLBs into ../assets/models/
and renders Cycles previews into ../shots_blender/.
Run: blender --background --python build_casino.py
Conventions: Blender Z up. Godot +Z (player side) = Blender -Y,
Godot +X = Blender +X (glTF exporter converts). Materials created AFTER
read_factory_settings. Glass alpha is dropped by glTF: material name
"Glass" is the contract for Godot-side re-application.
"""
import bpy, os, math, random
from mathutils import Vector

BASE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.join(BASE, "..", "assets", "models")
TEXTURES = os.path.join(BASE, "..", "assets", "textures")
SHOTS = os.path.join(BASE, "..", "shots_blender")
os.makedirs(MODELS, exist_ok=True)
os.makedirs(SHOTS, exist_ok=True)

WHEEL_ORDER = [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8,
               23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12,
               35, 3, 26]
RED = {1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36}

bpy.ops.wm.read_factory_settings(use_empty=True)

# ---------------------------------------------------------------- materials
def mat(name, color, metallic=0.0, rough=0.6, emission=None, e_strength=0.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    if emission is not None:
        key = "Emission Color" if "Emission Color" in bsdf.inputs else "Emission"
        bsdf.inputs[key].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = e_strength
    return m


def tex_mat(name, filename, emission_strength=0.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.85
    img = bpy.data.images.load(os.path.join(TEXTURES, filename),
                               check_existing=True)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if emission_strength > 0:
        key = "Emission Color" if "Emission Color" in bsdf.inputs else "Emission"
        nt.links.new(tex.outputs["Color"], bsdf.inputs[key])
        bsdf.inputs["Emission Strength"].default_value = emission_strength
    return m


def palette():
    return {
        "Wood":      mat("WoodDark", (0.16, 0.08, 0.045), 0.15, 0.42),
        "WoodLight": mat("WoodLight", (0.32, 0.19, 0.10), 0.1, 0.5),
        "Gold":      mat("GoldTrim", (0.72, 0.53, 0.20), 0.95, 0.28),
        "Chrome":    mat("Chrome", (0.62, 0.66, 0.74), 1.0, 0.16),
        "DarkMetal": mat("DarkMetal", (0.035, 0.035, 0.05), 0.7, 0.45),
        "Black":     mat("BlackGloss", (0.02, 0.02, 0.025), 0.3, 0.3),
        "FeltGreen": mat("FeltGreen", (0.02, 0.20, 0.10), 0.0, 0.95),
        "Leather":   mat("LeatherBrown", (0.13, 0.07, 0.05), 0.05, 0.6),
        "Purple":    mat("DeepPurple", (0.10, 0.03, 0.16), 0.05, 0.62),
        "PurpleLt":  mat("PurpleLight", (0.17, 0.07, 0.26), 0.05, 0.58),
        "Red":       mat("PocketRed", (0.42, 0.03, 0.05), 0.1, 0.5),
        "PBlack":    mat("PocketBlack", (0.015, 0.015, 0.02), 0.1, 0.45),
        "PGreen":    mat("PocketGreen", (0.0, 0.30, 0.12), 0.1, 0.5),
        "Glass":     mat("Glass", (0.05, 0.09, 0.13), 0.9, 0.1),
        "CrystalGlow": mat("CrystalGlow", (0.85, 0.68, 0.38), 0.1, 0.25,
                           (1.0, 0.85, 0.55), 1.1),
        "LedPink":   mat("LedPink", (0.30, 0.0, 0.10), 0.2, 0.3,
                         (1.0, 0.08, 0.55), 2.2),
        "MonitorScreen": mat("MonitorScreen", (0.02, 0.10, 0.12), 0.1, 0.3,
                             (0.35, 0.85, 1.0), 1.0),
        "ChipBody":  mat("ChipBody", (0.92, 0.92, 0.92), 0.05, 0.45),
        "ChipSpot":  mat("ChipSpot", (0.98, 0.98, 0.98), 0.05, 0.45),
        "SignBoard": mat("SignBoard", (0.05, 0.02, 0.08), 0.4, 0.4),
    }

# ---------------------------------------------------------------- helpers
def clean():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)


def assign(obj, material):
    if material:
        obj.data.materials.append(material)


def bevel_apply(obj, width=0.03, segments=2):
    if width <= 0:
        return
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    mod = obj.modifiers.new("bev", "BEVEL")
    mod.width = width
    mod.segments = segments
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)


def box(name, size, loc, material, bevel=0.02, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    assign(o, material)
    bevel_apply(o, bevel)
    return o


def cyl(name, radius, depth, loc, material, vertices=24, rot=(0, 0, 0),
        bevel=0.008, radius2=None):
    bpy.ops.mesh.primitive_cone_add(radius1=radius,
                                    radius2=radius if radius2 is None else radius2,
                                    depth=depth, vertices=vertices, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    assign(o, material)
    bevel_apply(o, bevel)
    return o


def sphere(name, radius, loc, material):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=loc,
                                         segments=14, ring_count=10)
    o = bpy.context.active_object
    o.name = name
    assign(o, material)
    return o


def torus(name, major, minor, loc, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=40, minor_segments=8,
                                     location=loc)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    assign(o, material)
    return o


def flat_ring(name, r_out, r_in, z0, z1, material, seg=48):
    """Closed flat annulus between r_in..r_out, z0..z1."""
    rings = [(r_out, z1), (r_in, z1), (r_in, z0), (r_out, z0)]
    verts, faces = [], []
    for k in range(seg + 1):
        th = 2 * math.pi * k / seg
        for (r, z) in rings:
            verts.append((r * math.cos(th), r * math.sin(th), z))
    for k in range(seg):
        a = 4 * k
        for f in range(3):
            faces.append((a + f, a + f + 4, a + f + 5, a + f + 1))
        faces.append((a + 3, a + 7, a + 4, a))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    assign(o, material)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    o.select_set(False)
    return o


def octahedron(name, size, loc, material):
    s = size
    verts = [(0, 0, s), (0, 0, -s), (s, 0, 0), (-s, 0, 0), (0, s, 0), (0, -s, 0)]
    faces = [(0, 4, 2), (0, 2, 5), (0, 5, 3), (0, 3, 4),
             (1, 2, 4), (1, 5, 2), (1, 3, 5), (1, 4, 3)]
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    o.location = loc
    assign(o, material)
    return o


def prism(name, outline, z0, z1, top_mat, side_mat, uv_box=None):
    """Extrude a convex CCW (from +Z) 2D outline in XY between z0..z1.
    Top face gets material slot 0 with UVs from uv_box=(xmin,ymin,w,h)."""
    n = len(outline)
    cx = sum(p[0] for p in outline) / n
    cy = sum(p[1] for p in outline) / n
    verts = [(x, y, z0) for (x, y) in outline] + \
            [(x, y, z1) for (x, y) in outline] + \
            [(cx, cy, z0), (cx, cy, z1)]
    faces, mat_idx, uvs = [], [], []
    bc, tc = 2 * n, 2 * n + 1
    for i in range(n):  # top fan
        j = (i + 1) % n
        faces.append((tc, n + i, n + j))
        mat_idx.append(0)
    for i in range(n):  # bottom fan
        j = (i + 1) % n
        faces.append((bc, j, i))
        mat_idx.append(1)
    for i in range(n):  # sides
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
        mat_idx.append(1)
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    if uv_box:
        xmin, ymin, w, h = uv_box
        uv = me.uv_layers.new(name="UVMap")
        for li, loop in enumerate(me.loops):
            vx, vy = me.vertices[loop.vertex_index].co.x, \
                     me.vertices[loop.vertex_index].co.y
            uv.data[li].uv = ((vx - xmin) / w, (vy - ymin) / h)
    for poly, mi in zip(me.polygons, mat_idx):
        poly.material_index = mi
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    if top_mat:
        o.data.materials.append(top_mat)
    if side_mat:
        o.data.materials.append(side_mat)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    o.select_set(False)
    return o


def ellipse_outline(rx, ry, seg=40, cy_off=0.0):
    return [(rx * math.cos(t), cy_off + ry * math.sin(t))
            for t in [2 * math.pi * i / seg for i in range(seg)]]


def join_all(new_name):
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = new_name
    return o


def export_glb(filename):
    path = os.path.join(MODELS, filename)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB",
                              export_apply=True, export_image_format="JPEG")
    print("EXPORTED", filename, os.path.getsize(path), "bytes")


def render_views(tag, cam_loc, target, res=512):
    sc = bpy.context.scene
    # lights
    def light(name, loc, color, energy, size=6):
        ld = bpy.data.lights.new(name, "AREA")
        ld.color = color
        ld.energy = energy
        ld.shape = "DISK"
        ld.size = size
        lo = bpy.data.objects.new(name, ld)
        bpy.context.collection.objects.link(lo)
        lo.location = loc
        d = Vector(target) - Vector(loc)
        lo.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    light("Key", (5, -6, 8), (0.9, 0.9, 0.95), 700)
    light("RimPink", (-7, 5, 4), (1.0, 0.3, 0.6), 800)
    light("RimGold", (7, 6, 3), (1.0, 0.75, 0.4), 600)
    cd = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cd)
    bpy.context.collection.objects.link(cam)
    cam.location = cam_loc
    d = Vector(target) - Vector(cam_loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 24
    sc.cycles.device = "CPU"
    sc.render.resolution_x = res
    sc.render.resolution_y = int(res * 0.75)
    sc.world = bpy.data.worlds.new("W")
    sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = \
        (0.01, 0.008, 0.02, 1)
    sc.render.filepath = os.path.join(SHOTS, "casino_%s.png" % tag)
    bpy.ops.render.render(write_still=True)
    # remove camera + lights again
    for o in list(bpy.context.scene.objects):
        if o.type in ("CAMERA", "LIGHT"):
            bpy.data.objects.remove(o, do_unlink=True)
    print("RENDERED", tag)


def finish(name, glb, views):
    """views: list of (tag_suffix, cam_loc, target). Renders, joins, exports."""
    for suffix, cam_loc, target in views:
        render_views(name + suffix, cam_loc, target)
    join_all(name)
    export_glb(glb)
    clean()

# ================================================================ 1. wheel
def build_wheel():
    clean()
    P = palette()
    # base bowl + wooden rim
    cyl("Bowl", 0.40, 0.055, (0, 0, 0.0275), P["Wood"], vertices=48, bevel=0.006)
    flat_ring("RimTop", 0.40, 0.352, 0.105, 0.132, P["WoodLight"])
    # sloped number band (custom frustum, wheel_ring texture)
    seg = 64
    verts, faces, uvs = [], [], []
    for k in range(seg + 1):
        th = 2 * math.pi * k / seg
        u = (-th / (2 * math.pi)) % 1.0
        verts.append((0.40 * math.cos(th), 0.40 * math.sin(th), 0.128))
        verts.append((0.298 * math.cos(th), 0.298 * math.sin(th), 0.086))
        uvs.append((u, 0.0))
        uvs.append((u, 1.0))
    for k in range(seg):
        a, b = 2 * k, 2 * k + 1
        faces.append((a, a + 2, b + 2, b))
    me = bpy.data.meshes.new("RingBand")
    me.from_pydata(verts, [], faces)
    me.update()
    uv = me.uv_layers.new(name="UVMap")
    for li, loop in enumerate(me.loops):
        uv.data[li].uv = uvs[loop.vertex_index]
    band = bpy.data.objects.new("RingBand", me)
    bpy.context.collection.objects.link(band)
    assign(band, tex_mat("WheelRing", "wheel_ring.jpg"))
    # pocket floor
    cyl("Floor", 0.298, 0.012, (0, 0, 0.080), P["DarkMetal"], vertices=48,
        bevel=0.0)
    # 37 pockets + frets (clockwise from +X, european order)
    step = 2 * math.pi / 37
    for i, n in enumerate(WHEEL_ORDER):
        th = -i * step
        r = 0.252
        x, y = r * math.cos(th), r * math.sin(th)
        pm = P["PGreen"] if n == 0 else (P["Red"] if n in RED else P["PBlack"])
        box("Pocket%02d" % i, (0.088, 0.040, 0.016), (x, y, 0.086), pm,
            bevel=0.002, rot=(0, 0, th))
        fa = th - step / 2
        fx, fy = 0.252 * math.cos(fa), 0.252 * math.sin(fa)
        box("Fret%02d" % i, (0.092, 0.005, 0.030), (fx, fy, 0.093),
            P["Chrome"], bevel=0.0, rot=(0, 0, fa))
    # inner cone + cross spindle
    cyl("Cone", 0.105, 0.055, (0, 0, 0.105), P["Wood"], vertices=32,
        bevel=0.004, radius2=0.045)
    cyl("Post", 0.016, 0.10, (0, 0, 0.16), P["Gold"], vertices=12, bevel=0.0)
    box("CrossA", (0.30, 0.035, 0.028), (0, 0, 0.205), P["Gold"], bevel=0.006)
    box("CrossB", (0.035, 0.30, 0.028), (0, 0, 0.205), P["Gold"], bevel=0.006)
    sphere("SpindleBall", 0.032, (0, 0, 0.235), P["Gold"])
    finish("RouletteWheel", "casino_roulette_wheel.glb", [
        ("_top", (0.02, -0.55, 1.05), (0, 0, 0.02)),
        ("_diag", (0.85, -0.85, 0.62), (0, 0, 0.05)),
    ])

# ================================================================ 2. roulette table
def build_roulette_table():
    clean()
    P = palette()
    # D-shape: flat dealer edge at Blender +Y, half-ellipse bulge to (0,-0.8)
    outline = [(-1.5, 0.8), (1.5, 0.8)]
    for k in range(1, 33):
        t = math.pi * k / 32
        outline.append((1.5 * math.cos(t), 0.8 - 1.6 * math.sin(t)))
    layout = tex_mat("RouletteLayout", "roulette_layout.jpg")
    prism("TableTop", outline, 0.78, 0.85, layout, P["Wood"],
          uv_box=(-1.5, -0.8, 3.0, 1.6))
    # apron + pedestal legs
    box("Apron", (2.7, 1.35, 0.10), (0, 0, 0.72), P["Wood"], bevel=0.02)
    for sx in (-1.15, 1.15):
        box("Leg", (0.14, 0.9, 0.68), (sx, 0, 0.34), P["Wood"], bevel=0.02)
    box("FootBar", (2.5, 0.12, 0.06), (0, 0, 0.05), P["Gold"], bevel=0.01)
    # wheel recess: dark disc at Godot (-0.95, 0.85, 0) = Blender (-0.95, 0, top)
    cyl("WheelWell", 0.42, 0.018, (-0.95, 0, 0.845), P["Black"], vertices=40,
        bevel=0.0)
    torus("WellRim", 0.42, 0.012, (-0.95, 0, 0.852), P["Gold"])
    finish("RouletteTable", "casino_roulette_table.glb", [
        ("_top", (0.3, -0.6, 3.4), (0, 0, 0.8)),
        ("_diag", (2.6, -2.4, 1.9), (0, 0, 0.45)),
    ])

# ================================================================ 3. blackjack table
def build_bj_table():
    clean()
    P = palette()
    # semicircle: flat dealer edge at +Y from (-1.2,0.65) to (1.2,0.65),
    # half-ellipse bulge to (0,-0.65)
    outline = [(-1.2, 0.65), (1.2, 0.65)]
    for k in range(1, 33):
        t = math.pi * k / 32
        outline.append((1.2 * math.cos(t), 0.65 - 1.3 * math.sin(t)))
    felt = tex_mat("BJFelt", "bj_felt.jpg")
    prism("BJTop", outline, 0.78, 0.85, felt, P["Wood"],
          uv_box=(-1.2, -0.65, 2.4, 1.3))
    box("Apron", (2.1, 1.05, 0.10), (0, 0, 0.72), P["Wood"], bevel=0.02)
    for sx in (-0.85, 0.85):
        box("Leg", (0.13, 0.8, 0.68), (sx, 0, 0.34), P["Wood"], bevel=0.02)
    # dealer chip tray on the straight edge: shallow box + dividers
    box("TrayBase", (0.62, 0.30, 0.025), (0, 0.44, 0.862), P["Black"],
        bevel=0.005)
    for k in range(6):
        box("TrayDiv", (0.012, 0.28, 0.035), (-0.26 + k * 0.104, 0.44, 0.868),
            P["DarkMetal"], bevel=0.0)
    box("TrayFront", (0.62, 0.02, 0.05), (0, 0.295, 0.87), P["Black"],
        bevel=0.004)
    finish("BJTable", "casino_bj_table.glb", [
        ("_top", (0.2, -0.5, 3.0), (0, 0, 0.8)),
        ("_diag", (2.2, -2.0, 1.7), (0, 0, 0.45)),
    ])

# ================================================================ 4. poker table
def build_poker_table():
    clean()
    P = palette()
    felt = tex_mat("PokerFelt", "poker_felt.jpg")
    prism("PokerTop", ellipse_outline(1.3, 0.6, 44), 0.76, 0.83, felt,
          P["Leather"], uv_box=(-1.3, -0.6, 2.6, 1.2))
    # raised elbow rail: flat elliptical ring
    seg = 44
    verts, faces = [], []
    for k in range(seg + 1):
        t = 2 * math.pi * k / seg
        verts.append((1.38 * math.cos(t), 0.68 * math.sin(t), 0.83))
        verts.append((1.38 * math.cos(t), 0.68 * math.sin(t), 0.90))
        verts.append((1.24 * math.cos(t), 0.54 * math.sin(t), 0.90))
    for k in range(seg):
        a = 3 * k
        faces.append((a, a + 3, a + 4, a + 1))
        faces.append((a + 1, a + 4, a + 5, a + 2))
    me = bpy.data.meshes.new("Rail")
    me.from_pydata(verts, [], faces)
    me.update()
    rail = bpy.data.objects.new("Rail", me)
    bpy.context.collection.objects.link(rail)
    assign(rail, P["Leather"])
    bpy.context.view_layer.objects.active = rail
    rail.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    rail.select_set(False)
    # pedestal
    cyl("Pedestal", 0.30, 0.72, (0, 0, 0.38), P["Wood"], vertices=20,
        bevel=0.01)
    cyl("Base", 0.55, 0.05, (0, 0, 0.025), P["DarkMetal"], vertices=28,
        bevel=0.008)
    finish("PokerTable", "casino_poker_table.glb", [
        ("_top", (0.2, -0.5, 3.0), (0, 0, 0.8)),
        ("_diag", (2.4, -2.0, 1.8), (0, 0, 0.45)),
    ])

# ================================================================ 5. chip
def build_chip():
    clean()
    P = palette()
    cyl("Chip", 0.02, 0.004, (0, 0, 0.002), P["ChipBody"], vertices=28,
        bevel=0.0)
    for k in range(8):
        th = 2 * math.pi * k / 8
        x, y = 0.0175 * math.cos(th), 0.0175 * math.sin(th)
        box("Spot%d" % k, (0.007, 0.005, 0.0042), (x, y, 0.002), P["ChipSpot"],
            bevel=0.0, rot=(0, 0, th))
    finish("Chip", "casino_chip.glb", [
        ("_diag", (0.07, -0.07, 0.06), (0, 0, 0.0)),
    ])

# ================================================================ 6. cashier cage
def build_cage():
    clean()
    P = palette()
    # origin: centre of counter front face, floor. Front at Blender y=0,
    # cage extends toward +Y (Godot -Z, behind the counter).
    box("Counter", (8.0, 0.8, 1.05), (0, 0.4, 0.525), P["Wood"], bevel=0.02)
    box("CounterTop", (8.2, 0.95, 0.05), (0, 0.42, 1.06), P["Black"],
        bevel=0.01)
    box("KickPlate", (8.0, 0.03, 0.18), (0, 0.015, 0.09), P["Gold"],
        bevel=0.0)
    box("BackWall", (8.0, 0.15, 3.2), (0, 0.95, 1.6), P["Purple"], bevel=0.0)
    for sx in (-3.99, 3.99):
        box("SideWall", (0.06, 1.0, 3.2), (sx, 0.5, 1.6), P["Purple"],
            bevel=0.0)
    # vertical iron bars above the counter, 3 window zones with gold frames
    zones = [(-3.9, -1.45), (-1.22, 1.22), (1.45, 3.9)]
    for (za, zb) in zones:
        x = za + 0.09
        while x < zb:
            cyl("Bar", 0.014, 1.10, (x, 0.30, 1.63), P["DarkMetal"],
                vertices=8, bevel=0.0)
            x += 0.115
        box("WinFrameT", (zb - za, 0.05, 0.07), ((za + zb) / 2, 0.30, 2.20),
            P["Gold"], bevel=0.0)
        box("WinFrameB", (zb - za, 0.05, 0.07), ((za + zb) / 2, 0.30, 1.06),
            P["Gold"], bevel=0.0)
        for fx in (za, zb):
            box("WinFrameS", (0.05, 0.05, 1.21), (fx, 0.30, 1.63), P["Gold"],
                bevel=0.0)
    # glass band above the bars + sign board
    box("GlassBand", (8.0, 0.03, 0.62), (0, 0.30, 2.51), P["Glass"], bevel=0.0)
    box("HeaderBeam", (8.0, 0.10, 0.10), (0, 0.30, 2.24), P["Gold"], bevel=0.0)
    box("SignBoard", (6.4, 0.10, 0.55), (0, 0.10, 2.95), P["SignBoard"],
        bevel=0.01)
    box("SignTrim", (6.5, 0.04, 0.06), (0, 0.06, 3.24), P["Gold"], bevel=0.0)
    finish("Cage", "casino_cage.glb", [
        ("_front", (0, -6.5, 2.0), (0, 0.3, 1.5)),
        ("_diag", (5.5, -5.5, 3.2), (0, 0.3, 1.4)),
    ])

# ================================================================ 7. chandelier
def build_chandelier():
    clean()
    P = palette()
    # origin = ceiling mount point; body hangs toward -Z (down)
    cyl("Mount", 0.10, 0.10, (0, 0, -0.05), P["Gold"], vertices=16, bevel=0.0)
    cyl("Stem", 0.03, 0.35, (0, 0, -0.27), P["Gold"], vertices=10, bevel=0.0)
    torus("RingOuter", 2.0, 0.045, (0, 0, -0.85), P["Gold"])
    torus("RingInner", 1.25, 0.04, (0, 0, -0.55), P["Gold"])
    torus("RingTop", 0.6, 0.03, (0, 0, -0.38), P["Gold"])
    rng = random.Random(11)
    # crystals hanging from the outer ring
    for k in range(28):
        th = 2 * math.pi * k / 28
        x, y = 2.0 * math.cos(th), 2.0 * math.sin(th)
        drop = 0.16 + 0.14 * (k % 3) / 2
        octahedron("CrysO%d" % k, 0.085, (x, y, -0.85 - drop), P["CrystalGlow"])
        cyl("Drop%d" % k, 0.006, drop, (x, y, -0.85 - drop / 2), P["Gold"],
            vertices=6, bevel=0.0)
    for k in range(16):
        th = 2 * math.pi * (k + 0.5) / 16
        x, y = 1.25 * math.cos(th), 1.25 * math.sin(th)
        octahedron("CrysI%d" % k, 0.07, (x, y, -0.72), P["CrystalGlow"])
    for k in range(8):
        th = 2 * math.pi * k / 8
        x, y = 0.6 * math.cos(th), 0.6 * math.sin(th)
        octahedron("CrysT%d" % k, 0.055, (x, y, -0.50), P["CrystalGlow"])
    octahedron("CrysCore", 0.20, (0, 0, -1.05), P["CrystalGlow"])
    cyl("CoreDrop", 0.008, 0.18, (0, 0, -0.94), P["Gold"], vertices=6,
        bevel=0.0)
    finish("Chandelier", "casino_chandelier.glb", [
        ("_diag", (3.6, -3.6, -0.4), (0, 0, -0.8)),
        ("_under", (1.4, -1.6, -3.2), (0, 0, -0.7)),
    ])

# ================================================================ 8. detector gate
def build_gate():
    clean()
    P = palette()
    for sx in (-0.41, 0.41):
        box("Post", (0.18, 0.6, 2.2), (sx, 0, 1.1), P["Black"], bevel=0.02)
        box("PostTrim", (0.19, 0.61, 0.05), (sx, 0, 2.19), P["Gold"],
            bevel=0.0)
        # LED strip on the inner face
        box("Led", (0.02, 0.10, 1.9), (sx - math.copysign(0.10, sx), 0, 1.08),
            P["LedPink"], bevel=0.0)
        box("LedFront", (0.02, 0.10, 1.9),
            (sx - math.copysign(0.10, sx), -0.20, 1.08), P["LedPink"],
            bevel=0.0)
    box("Beam", (1.0, 0.6, 0.28), (0, 0, 2.06), P["Black"], bevel=0.02)
    box("BeamTrim", (1.0, 0.62, 0.04), (0, 0, 1.93), P["Gold"], bevel=0.0)
    finish("Gate", "casino_gate.glb", [
        ("_front", (0, -2.6, 1.4), (0, 0, 1.1)),
        ("_diag", (1.8, -1.8, 1.6), (0, 0, 1.1)),
    ])

# ================================================================ 9. slot machine
def build_slot():
    clean()
    P = palette()
    # front faces Blender -Y (Godot +Z)
    box("Body", (0.7, 0.5, 1.55), (0, 0, 0.775), P["Purple"], bevel=0.04)
    box("Base", (0.72, 0.52, 0.10), (0, 0, 0.05), P["Black"], bevel=0.01)
    box("TopBox", (0.66, 0.44, 0.28), (0, 0, 1.68), P["PurpleLt"], bevel=0.03)
    screen = tex_mat("SlotScreen", "slot_screen.jpg", emission_strength=0.55)
    # screen as a dedicated plane (explicit full-frame UV, faces -Y, tilted)
    bpy.ops.mesh.primitive_plane_add(size=2.0, location=(0, -0.272, 1.28))
    scr = bpy.context.active_object
    scr.name = "Screen"
    scr.scale = (0.27, 0.26, 1.0)
    scr.rotation_euler = (math.radians(86), 0, 0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    assign(scr, screen)
    box("ScreenBezel", (0.58, 0.015, 0.56), (0, -0.258, 1.28), P["Black"],
        bevel=0.0, rot=(math.radians(-4), 0, 0))
    # sloped button panel + buttons
    box("Panel", (0.6, 0.16, 0.05), (0, -0.27, 0.88), P["Black"], bevel=0.01,
        rot=(math.radians(-25), 0, 0))
    cyl("BtnA", 0.032, 0.025, (-0.14, -0.335, 0.915), P["Red"], vertices=16,
        rot=(math.radians(65), 0, 0), bevel=0.0)
    cyl("BtnB", 0.032, 0.025, (0.10, -0.335, 0.915),
        mat("BtnGold", (0.8, 0.6, 0.15), 0.6, 0.3), vertices=16,
        rot=(math.radians(65), 0, 0), bevel=0.0)
    # lever on the right side
    cyl("LeverArm", 0.012, 0.34, (0.375, 0, 1.28), P["Chrome"], vertices=8,
        rot=(0, 0, math.radians(-18)), bevel=0.0)
    sphere("LeverBall", 0.045, (0.435, 0, 1.44), P["Red"])
    box("CoinSlot", (0.10, 0.02, 0.16), (0.18, -0.25, 1.02), P["Gold"],
        bevel=0.0)
    finish("Slot", "casino_slot.glb", [
        ("_front", (0.3, -1.9, 1.2), (0, 0, 0.95)),
        ("_diag", (1.4, -1.4, 1.5), (0, 0, 0.9)),
    ])

# ================================================================ 10. bar
def build_bar():
    clean()
    P = palette()
    # origin = L corner. Leg A along +X (front faces -Y), leg B toward -Y
    # (Godot +Z); front faces +X side... leg B front faces +X.
    box("CounterA", (6.0, 0.62, 1.1), (3.0, 0.31, 0.55), P["Wood"], bevel=0.02)
    box("TopA", (6.15, 0.78, 0.06), (3.0, 0.31, 1.12), P["Black"], bevel=0.01)
    box("TrimA", (6.0, 0.03, 0.08), (3.0, -0.005, 0.98), P["Gold"], bevel=0.0)
    box("CounterB", (0.62, 3.0, 1.1), (0.31, -1.5, 0.55), P["Wood"], bevel=0.02)
    box("TopB", (0.78, 3.15, 0.06), (0.31, -1.5, 1.12), P["Black"], bevel=0.01)
    box("TrimB", (0.03, 3.0, 0.08), (-0.005 + 0.62, -1.5, 0.98), P["Gold"],
        bevel=0.0)
    # back bottle shelf behind leg A (at +Y)
    for sx in (0.15, 5.85):
        box("ShelfPost", (0.08, 0.25, 2.3), (sx, 1.15, 1.15), P["DarkMetal"],
            bevel=0.0)
    bottle_cols = [(0.65, 0.15, 0.15), (0.15, 0.55, 0.25), (0.70, 0.45, 0.10),
                   (0.20, 0.30, 0.65), (0.55, 0.10, 0.30), (0.30, 0.60, 0.55)]
    rng = random.Random(4)
    for lvl, sy in enumerate((0.75, 1.35, 1.95)):
        box("Shelf", (6.0, 0.30, 0.04), (3.0, 1.15, sy), P["Wood"], bevel=0.005)
        for k in range(10):
            bx = 0.45 + k * 0.58 + rng.uniform(-0.06, 0.06)
            bc = bottle_cols[(k + lvl * 3) % len(bottle_cols)]
            bm = mat("Bottle%d_%d" % (lvl, k), bc, 0.1, 0.15, bc, 0.35)
            bh = rng.uniform(0.26, 0.36)
            cyl("Bottle", 0.045, bh, (bx, 1.15, sy + 0.02 + bh / 2), bm,
                vertices=10, bevel=0.0)
            cyl("BottleNeck", 0.016, 0.09, (bx, 1.15, sy + 0.02 + bh + 0.045),
                bm, vertices=8, bevel=0.0)
    box("BackPanel", (6.0, 0.06, 2.3), (3.0, 1.32, 1.15), P["Purple"],
        bevel=0.0)
    finish("Bar", "casino_bar.glb", [
        ("_front", (3.0, -4.2, 1.8), (2.6, 0.6, 0.9)),
        ("_diag", (6.8, -4.6, 3.4), (2.4, 0.4, 0.8)),
    ])

# ================================================================ 11. pit boss desk
def build_pitboss():
    clean()
    P = palette()
    box("Desk", (1.4, 0.7, 1.18), (0, 0, 0.59), P["Wood"], bevel=0.02)
    box("DeskTop", (1.5, 0.8, 0.06), (0, 0, 1.21), P["Black"], bevel=0.01)
    box("DeskTrim", (1.4, 0.03, 0.07), (0, -0.355, 1.05), P["Gold"], bevel=0.0)
    box("MonitorArm", (0.06, 0.06, 0.22), (0, 0.12, 1.35), P["DarkMetal"],
        bevel=0.0)
    mon = box("Monitor", (0.72, 0.04, 0.46), (0, 0.10, 1.55), P["Black"],
              bevel=0.01, rot=(math.radians(-10), 0, 0))
    box("ScreenFace", (0.66, 0.015, 0.40), (0, 0.078, 1.552),
        P["MonitorScreen"], bevel=0.0, rot=(math.radians(-10), 0, 0))
    finish("PitBoss", "casino_pitboss.glb", [
        ("_front", (0, -2.4, 1.5), (0, 0, 0.9)),
        ("_diag", (1.7, -1.7, 1.9), (0, 0, 0.9)),
    ])

# ================================================================ 12. shoe set
def build_shoe():
    clean()
    P = palette()
    # card shoe (slanted black box) at x=-0.32
    box("ShoeBody", (0.13, 0.30, 0.10), (-0.32, 0, 0.075), P["Black"],
        bevel=0.008, rot=(math.radians(-14), 0, 0))
    box("ShoeFace", (0.115, 0.02, 0.13), (-0.32, -0.145, 0.062),
        P["DarkMetal"], bevel=0.004, rot=(math.radians(-14), 0, 0))
    box("ShoeCard", (0.105, 0.20, 0.012), (-0.32, 0.01, 0.135),
        mat("CardWhite", (0.93, 0.93, 0.95), 0.0, 0.6), bevel=0.0,
        rot=(math.radians(-14), 0, 0))
    # discard tray at x=0.05: base + 4 low walls
    box("TrayBase", (0.16, 0.24, 0.012), (0.05, 0, 0.006), P["Black"],
        bevel=0.0)
    for (sx, sy, w, dpt) in [(-0.074, 0, 0.012, 0.24), (0.074, 0, 0.012, 0.24),
                             (0, -0.114, 0.16, 0.012), (0, 0.114, 0.16, 0.012)]:
        box("TrayWall", (w, dpt, 0.055), (0.05 + sx, sy, 0.034), P["Black"],
            bevel=0.0)
    # roulette dolly at x=0.34: small truncated cone
    cyl("Dolly", 0.034, 0.085, (0.34, 0, 0.0425), P["Gold"], vertices=16,
        bevel=0.0, radius2=0.020)
    sphere("DollyTop", 0.016, (0.34, 0, 0.093), P["Gold"])
    finish("ShoeSet", "casino_shoe.glb", [
        ("_diag", (0.45, -0.5, 0.35), (0, 0, 0.03)),
        ("_top", (0.0, -0.15, 0.6), (0, 0, 0.0)),
    ])

# ================================================================ 13. stool
def build_stool():
    clean()
    P = palette()
    cyl("Base", 0.17, 0.025, (0, 0, 0.0125), P["DarkMetal"], vertices=28,
        bevel=0.005)
    cyl("Pole", 0.028, 0.55, (0, 0, 0.30), P["Chrome"], vertices=12, bevel=0.0)
    torus("FootRing", 0.16, 0.012, (0, 0, 0.22), P["Gold"])
    cyl("Seat", 0.21, 0.075, (0, 0, 0.6125),
        mat("StoolSeat", (0.35, 0.04, 0.10), 0.05, 0.55), vertices=32,
        bevel=0.012)
    torus("SeatTrim", 0.205, 0.010, (0, 0, 0.578), P["Gold"])
    finish("Stool", "casino_stool.glb", [
        ("_diag", (0.65, -0.65, 0.55), (0, 0, 0.33)),
    ])

# ================================================================ 14. sofa set
def build_sofa():
    clean()
    P = palette()
    # sofa faces Blender -Y (sitting side toward -Y)
    box("SofaBase", (2.4, 0.85, 0.38), (0, 0, 0.28), P["Purple"], bevel=0.04)
    box("SofaBack", (2.4, 0.22, 0.62), (0, 0.36, 0.72), P["Purple"], bevel=0.04)
    for sx in (-1.09, 1.09):
        box("Arm", (0.22, 0.85, 0.30), (sx, 0, 0.62), P["Purple"], bevel=0.04)
    for sx in (-0.56, 0.56):
        box("Cushion", (1.02, 0.72, 0.13), (sx, -0.03, 0.50), P["PurpleLt"],
            bevel=0.035)
        box("BackCushion", (1.02, 0.13, 0.44), (sx, 0.27, 0.74),
            P["PurpleLt"], bevel=0.035, rot=(math.radians(-10), 0, 0))
    box("SofaTrim", (2.4, 0.03, 0.05), (0, -0.435, 0.12), P["Gold"], bevel=0.0)
    # low table in front
    box("TableTop", (1.1, 0.55, 0.04), (0, -1.05, 0.36), P["Black"],
        bevel=0.01)
    for (lx, ly) in [(-0.48, -1.24), (0.48, -1.24), (-0.48, -0.86),
                     (0.48, -0.86)]:
        box("TableLeg", (0.05, 0.05, 0.34), (lx, ly, 0.17), P["Gold"],
            bevel=0.0)
    finish("Sofa", "casino_sofa.glb", [
        ("_front", (0, -3.0, 1.3), (0, -0.3, 0.5)),
        ("_diag", (2.4, -2.4, 1.8), (0, -0.3, 0.45)),
    ])


if __name__ == "__main__":
    build_wheel()
    build_roulette_table()
    build_bj_table()
    build_poker_table()
    build_chip()
    build_cage()
    build_chandelier()
    build_gate()
    build_slot()
    build_bar()
    build_pitboss()
    build_shoe()
    build_stool()
    build_sofa()
    print("ALL DONE")
