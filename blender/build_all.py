"""NEON CITY 2099 v1.2 - Blender model builder.
Builds hover car, street props and hero towers; exports GLB into
../assets/models/ and renders Cycles previews into ../shots_blender/.
Run: blender --background --python build_all.py
Conventions: Blender Z up, car/prop FRONT is -Y (Godot side rotates Y by PI
where needed). All parts are joined into ONE mesh per model with multiple
material slots -> few draw calls in Godot.
"""
import bpy, os, math
from mathutils import Vector

BASE = os.path.dirname(os.path.abspath(__file__))
MODELS = os.path.join(BASE, "..", "assets", "models")
SHOTS = os.path.join(BASE, "..", "shots_blender")
os.makedirs(MODELS, exist_ok=True)
os.makedirs(SHOTS, exist_ok=True)

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

def palette():
    return {
        "BodyPaint":  mat("BodyPaint", (0.55, 0.55, 0.6), 0.65, 0.32),
        "Glass":      mat("Glass", (0.015, 0.03, 0.07), 0.9, 0.12),
        "DarkMetal":  mat("DarkMetal", (0.03, 0.03, 0.045), 0.7, 0.45),
        "Chrome":     mat("Chrome", (0.6, 0.65, 0.72), 1.0, 0.18),
        "LightFront": mat("LightFront", (1, 0.95, 0.8), 0.2, 0.3, (1, 0.93, 0.75), 6.0),
        "LightRear":  mat("LightRear", (0.4, 0.01, 0.03), 0.2, 0.3, (1, 0.05, 0.18), 5.0),
        "NeonCyan":   mat("NeonCyan", (0.0, 0.25, 0.3), 0.2, 0.3, (0.05, 0.9, 1.0), 4.0),
        "NeonPink":   mat("NeonPink", (0.3, 0.0, 0.12), 0.2, 0.3, (1.0, 0.12, 0.55), 4.0),
        "NeonAmber":  mat("NeonAmber", (0.3, 0.18, 0.0), 0.2, 0.3, (1.0, 0.62, 0.08), 4.0),
        "VendBody":   mat("VendBody", (0.32, 0.03, 0.07), 0.55, 0.38),
        "DrinkGlow":  mat("DrinkGlow", (0.4, 0.7, 0.9), 0.1, 0.25, (0.45, 0.8, 1.0), 1.6),
        "TowerBody":  mat("TowerBody", (0.045, 0.055, 0.09), 0.45, 0.55),
        "TowerBody2": mat("TowerBody2", (0.08, 0.09, 0.13), 0.4, 0.5),
        "WinWarm":    mat("WinWarm", (0.5, 0.36, 0.16), 0.1, 0.4, (1.0, 0.72, 0.32), 1.5),
        "WinCool":    mat("WinCool", (0.2, 0.34, 0.46), 0.1, 0.4, (0.45, 0.75, 1.0), 1.5),
        "BeaconRed":  mat("BeaconRed", (0.4, 0.0, 0.02), 0.2, 0.3, (1.0, 0.06, 0.12), 5.0),
        "TrafficRed": mat("TrafficRed", (0.35, 0.0, 0.01), 0.2, 0.3, (1.0, 0.05, 0.1), 3.5),
        "TrafficYel": mat("TrafficYel", (0.35, 0.25, 0.0), 0.2, 0.3, (1.0, 0.8, 0.1), 3.5),
        "TrafficGrn": mat("TrafficGrn", (0.0, 0.3, 0.2), 0.2, 0.3, (0.1, 1.0, 0.65), 3.5),
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

def bevel_apply(obj, width=0.04, segments=2):
    if width <= 0:
        return
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    mod = obj.modifiers.new("bev", "BEVEL")
    mod.width = width
    mod.segments = segments
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.select_set(False)

def box(name, size, loc, material, bevel=0.04, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=2.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    assign(o, material)
    bevel_apply(o, bevel)
    return o

def cyl(name, radius, depth, loc, material, vertices=18, rot=(0, 0, 0), bevel=0.015):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, vertices=vertices, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    assign(o, material)
    bevel_apply(o, bevel)
    return o

def sphere(name, radius, loc, material):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=radius, location=loc, segments=14, ring_count=10)
    o = bpy.context.active_object
    o.name = name
    assign(o, material)
    return o

def profile(name, pts, width, material, bevel=0.03):
    """Extrude a (y,z) side profile across X. pts must form a closed loop."""
    n = len(pts)
    verts = [(-width / 2, y, z) for (y, z) in pts] + [(width / 2, y, z) for (y, z) in pts]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
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
    bevel_apply(o, bevel)
    return o

def torus(name, major, minor, loc, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=36, minor_segments=8, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    assign(o, material)
    return o

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
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True)
    print("EXPORTED", path, os.path.getsize(path), "bytes")

def preview(filename, cam_loc, target, model_top=2.0):
    # ground
    gm = mat("PreviewGround", (0.02, 0.02, 0.035), 0.3, 0.28)
    bpy.ops.mesh.primitive_plane_add(size=300, location=(0, 0, 0))
    g = bpy.context.active_object
    g.data.materials.append(gm)
    # lights: cool key + pink/cyan rims (night street mood)
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
    light("Key", (6, -7, 9), (0.75, 0.85, 1.0), 900)
    light("RimPink", (-8, 6, 4), (1.0, 0.15, 0.5), 1100)
    light("RimCyan", (8, 7, 3), (0.1, 0.8, 1.0), 800)
    # camera
    cd = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cd)
    bpy.context.collection.objects.link(cam)
    cam.location = cam_loc
    d = Vector(target) - Vector(cam_loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 40
    sc.cycles.device = "CPU"
    sc.render.resolution_x = 768
    sc.render.resolution_y = 512
    sc.world = bpy.data.worlds.new("W")
    sc.world.use_nodes = True
    sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.004, 0.005, 0.016, 1)
    sc.world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    sc.render.filepath = os.path.join(SHOTS, filename)
    bpy.ops.render.render(write_still=True)
    print("RENDERED", filename)

# ---------------------------------------------------------------- hover car
def build_car():
    clean()
    P = palette()
    # Main hull: wedge profile (nose -Y low, high rear deck).
    profile("BodyMain", [(-2.2, 0.30), (-2.2, 0.60), (-1.35, 0.86), (1.65, 0.92),
                         (2.2, 0.74), (2.2, 0.30)], 1.86, P["BodyPaint"], 0.055)
    # Cabin canopy: slanted windshield + rear slope, dark glass.
    profile("Cabin", [(-0.95, 0.84), (0.55, 0.84), (0.95, 1.38), (-0.45, 1.40)],
            1.52, P["Glass"], 0.07)
    # Beltline / cabin base trim.
    box("Belt", (1.66, 1.75, 0.10), (0, 0.28, 0.86), P["DarkMetal"], 0.03)
    # Hood vent panel.
    box("HoodVent", (1.15, 0.95, 0.05), (0, -1.55, 0.80), P["DarkMetal"], 0.02,
        rot=(math.radians(-13), 0, 0))
    # Nose splitter + rear diffuser.
    box("Splitter", (1.84, 0.42, 0.16), (0, -2.18, 0.30), P["DarkMetal"], 0.03)
    box("Diffuser", (1.84, 0.34, 0.30), (0, 2.16, 0.34), P["DarkMetal"], 0.03)
    for fx in (-0.55, 0.0, 0.55):
        box("Fin", (0.05, 0.30, 0.26), (fx, 2.18, 0.32), P["DarkMetal"], 0.01)
    # Side skirts + rear side intakes.
    for sx in (-0.96, 0.96):
        box("Skirt", (0.12, 3.1, 0.20), (sx, 0.1, 0.36), P["DarkMetal"], 0.03)
        box("Intake", (0.08, 0.85, 0.30), (sx * 1.0, 1.55, 0.62), P["DarkMetal"], 0.02)
        box("Mirror", (0.22, 0.10, 0.08), (sx * 1.02, -0.72, 1.02), P["DarkMetal"], 0.02)
    # Light bars: full-width front (warm white) and rear (red).
    box("LightFrontBar", (1.52, 0.09, 0.13), (0, -2.21, 0.55), P["LightFront"], 0.03)
    box("LightRearBar", (1.62, 0.09, 0.13), (0, 2.21, 0.60), P["LightRear"], 0.03)
    # Under-glow slab (cyan) - reads as hover light on the road.
    box("UnderGlow", (1.45, 3.5, 0.06), (0, 0, 0.17), P["NeonCyan"], 0.02)
    # Hover thruster pods + glowing discs.
    for sx in (-0.82, 0.82):
        for sy in (-1.42, 1.42):
            cyl("Pod", 0.30, 0.20, (sx, sy, 0.27), P["DarkMetal"], 18)
            cyl("PodGlow", 0.19, 0.22, (sx, sy, 0.25), P["NeonCyan"], 18)
    # Rear wing on struts.
    for sx in (-0.62, 0.62):
        box("WingStrut", (0.07, 0.10, 0.30), (sx, 1.95, 1.02), P["DarkMetal"], 0.02)
    box("Wing", (1.78, 0.44, 0.06), (0, 2.02, 1.20), P["BodyPaint"], 0.02,
        rot=(math.radians(10), 0, 0))
    box("WingStripe", (1.78, 0.10, 0.065), (0, 2.13, 1.225), P["NeonPink"], 0.01,
        rot=(math.radians(10), 0, 0))
    # Roof shark fin.
    box("RoofFin", (0.05, 0.42, 0.20), (0, 0.62, 1.44), P["DarkMetal"], 0.02)
    join_all("HoverCar")
    export_glb("hover_car.glb")
    preview("car_front.png", (4.6, -6.4, 2.0), (0, 0, 0.7))
    preview("car_rear.png", (-4.8, 6.2, 2.2), (0, 0, 0.7))

# ---------------------------------------------------------------- props
def build_vending():
    clean()
    P = palette()
    # Transparent display glass (alpha < 1 -> glTF BLEND -> Godot alpha).
    vg = bpy.data.materials.new("VendGlass")
    vg.use_nodes = True
    vb = vg.node_tree.nodes["Principled BSDF"]
    vb.inputs["Base Color"].default_value = (0.02, 0.05, 0.09, 0.30)
    vb.inputs["Metallic"].default_value = 0.1
    vb.inputs["Roughness"].default_value = 0.08
    for attr, val in (("blend_method", "BLEND"), ("surface_render_method", "BLENDED")):
        try:
            setattr(vg, attr, val)
        except Exception:
            pass
    box("Body", (1.15, 0.72, 1.95), (0, 0, 0.98), P["VendBody"], 0.05)
    box("Base", (1.2, 0.78, 0.16), (0, 0, 0.08), P["DarkMetal"], 0.03)
    # Dark interior backing so the glowing cans read against black.
    box("Interior", (0.8, 0.04, 1.3), (0, -0.24, 1.12), P["DarkMetal"], 0.01)
    # Glass front (faces -Y).
    box("GlassFront", (0.78, 0.03, 1.25), (0, -0.365, 1.12), vg, 0.01)
    # Drink rows glowing behind the glass (one accent color per row).
    row_mats = [P["NeonCyan"], P["NeonPink"], P["NeonAmber"]]
    for r in range(3):
        for cix in range(4):
            cyl("Can", 0.07, 0.24, (-0.27 + cix * 0.18, -0.315, 0.74 + r * 0.42),
                row_mats[r], 12)
        box("Shelf", (0.8, 0.04, 0.03), (0, -0.3, 0.60 + r * 0.42), P["Chrome"], 0.005)
    # Dispensing slot + keypad (on the frame right of the glass).
    box("Slot", (0.62, 0.05, 0.28), (0, -0.365, 0.36), P["DarkMetal"], 0.02)
    box("Keypad", (0.13, 0.04, 0.3), (0.48, -0.365, 0.95), P["NeonCyan"], 0.01)
    # Top sign + slim neon strip on the side's front edge.
    box("TopSign", (1.05, 0.6, 0.34), (0, -0.05, 2.12), P["NeonCyan"], 0.03)
    box("SideStrip", (0.04, 0.16, 1.5), (0.585, -0.2, 1.05), P["NeonPink"], 0.01)
    join_all("VendingMachine")
    export_glb("vending_machine.glb")
    preview("vending.png", (2.4, -3.4, 1.8), (0, 0, 1.0))

def build_traffic():
    clean()
    P = palette()
    cyl("Pole", 0.09, 4.8, (0, 0, 2.4), P["DarkMetal"], 12)
    box("BaseBox", (0.5, 0.5, 0.5), (0, 0, 0.25), P["DarkMetal"], 0.04)
    # Arm reaching over the road (toward -Y).
    box("Arm", (0.12, 2.9, 0.12), (0, -1.35, 4.72), P["DarkMetal"], 0.03)
    box("ArmTip", (0.1, 0.1, 0.5), (0, -2.7, 4.5), P["DarkMetal"], 0.02)
    # Signal head hanging at the arm tip; lamps face +Y (approaching drivers).
    box("Head", (0.42, 0.30, 1.15), (0, -2.7, 3.85), P["DarkMetal"], 0.05)
    for i, mkey in enumerate(("TrafficRed", "TrafficYel", "TrafficGrn")):
        cyl("Lamp", 0.115, 0.06, (0, -2.53, 4.22 - i * 0.36), P[mkey], 16,
            rot=(math.radians(90), 0, 0))
        torus("LampRing", 0.125, 0.018, (0, -2.54, 4.22 - i * 0.36), P["Chrome"],
              rot=(math.radians(90), 0, 0))
    # Small holo chevron sign on the pole.
    box("Chevron", (0.55, 0.05, 0.55), (0, -0.16, 3.1), P["NeonAmber"], 0.02,
        rot=(0, 0, math.radians(45)))
    join_all("TrafficLight")
    export_glb("traffic_light.glb")
    preview("traffic.png", (3.4, 4.2, 2.6), (0, -1.2, 2.6))

def build_totem():
    clean()
    P = palette()
    # Freestanding holo advertising totem (double-sided).
    cyl("Base", 0.55, 0.22, (0, 0, 0.11), P["DarkMetal"], 20)
    box("Slab", (0.95, 0.20, 3.3), (0, 0, 1.85), P["DarkMetal"], 0.05)
    for s in (-1, 1):
        box("PanelTop", (0.74, 0.06, 1.7), (0, s * 0.12, 2.45), P["NeonPink"], 0.02)
        box("PanelMid", (0.74, 0.06, 0.55), (0, s * 0.12, 1.28), P["NeonCyan"], 0.02)
        box("PanelBar", (0.5, 0.06, 0.16), (0, s * 0.12, 0.82), P["NeonAmber"], 0.01)
    box("CapStrip", (0.99, 0.24, 0.10), (0, 0, 3.56), P["NeonCyan"], 0.02)
    join_all("HoloTotem")
    export_glb("holo_totem.glb")
    preview("totem.png", (3.0, -3.8, 2.2), (0, 0, 1.8))

# ---------------------------------------------------------------- towers
def _win_bands(P, cx, cz, w, d, heights, matkey):
    for h in heights:
        box("Band", (w + 0.25, d + 0.25, 0.85), (cx, cz, h), P[matkey], 0.02)

def build_tower_a():
    clean()
    P = palette()
    # Stepped mega-spire: podium -> shaft -> offset mid -> top -> spire.
    box("Podium", (40, 40, 9), (0, 0, 4.5), P["TowerBody2"], 0.4)
    box("Shaft", (27, 27, 62), (0, 0, 40), P["TowerBody"], 0.5)
    _win_bands(P, 0, 0, 27, 27, [22, 34, 46, 58], "WinWarm")
    box("Mid", (21, 21, 34), (2.5, -2.5, 88), P["TowerBody2"], 0.4)
    _win_bands(P, 2.5, -2.5, 21, 21, [80, 94], "WinCool")
    box("Top", (14, 14, 26), (2.5, -2.5, 118), P["TowerBody"], 0.3)
    box("Crown", (15.5, 15.5, 1.4), (2.5, -2.5, 132), P["NeonCyan"], 0.1)
    cyl("Spire", 0.5, 30, (2.5, -2.5, 147), P["DarkMetal"], 10)
    sphere("Beacon", 1.1, (2.5, -2.5, 163), P["BeaconRed"])
    box("PodiumSign", (30, 1.2, 3.2), (0, -20.4, 7.5), P["NeonPink"], 0.1)
    join_all("HeroTowerA")
    export_glb("hero_tower_a.glb")
    preview("tower_a.png", (95, -120, 55), (0, 0, 60))

def build_tower_b():
    clean()
    P = palette()
    # Twin slabs joined by a skybridge.
    box("SlabL", (13, 22, 98), (-11.5, 0, 49), P["TowerBody"], 0.4)
    box("SlabR", (13, 22, 80), (11.5, 0, 40), P["TowerBody2"], 0.4)
    _win_bands(P, -11.5, 0, 13, 22, [26, 44, 70, 88], "WinCool")
    _win_bands(P, 11.5, 0, 13, 22, [22, 40, 62], "WinWarm")
    box("Bridge", (12, 10, 6), (0, 0, 58), P["TowerBody2"], 0.3)
    box("BridgeGlow", (12.3, 10.3, 1.1), (0, 0, 55.4), P["NeonPink"], 0.05)
    for sx in (-18.2, 18.2):
        box("EdgeStrip", (0.7, 0.7, 92), (sx, -11.2, 46), P["NeonCyan"], 0.05)
    sphere("BeaconL", 0.9, (-11.5, 0, 99.5), P["BeaconRed"])
    sphere("BeaconR", 0.9, (11.5, 0, 81.5), P["BeaconRed"])
    join_all("HeroTowerB")
    export_glb("hero_tower_b.glb")
    preview("tower_b.png", (80, -105, 48), (0, 0, 46))

def build_tower_c():
    clean()
    P = palette()
    # Cylindrical halo tower.
    cyl("Core", 14, 92, (0, 0, 46), P["TowerBody"], 24, bevel=0.0)
    for i, h in enumerate((18, 36, 54, 72)):
        cyl("WinBand", 14.35, 1.6, (0, 0, h), P["WinWarm" if i % 2 == 0 else "WinCool"], 24, bevel=0.0)
    cyl("TopDisc", 16.5, 3.5, (0, 0, 94), P["TowerBody2"], 24, bevel=0.0)
    torus("Halo", 19.5, 0.85, (0, 0, 103), P["NeonPink"])
    cyl("Mast", 0.45, 22, (0, 0, 108), P["DarkMetal"], 10)
    sphere("Beacon", 1.0, (0, 0, 120), P["BeaconRed"])
    join_all("HeroTowerC")
    export_glb("hero_tower_c.glb")
    preview("tower_c.png", (85, -110, 52), (0, 0, 52))

if __name__ == "__main__":
    import sys
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    jobs = [("car", build_car), ("vending", build_vending), ("traffic", build_traffic),
            ("totem", build_totem), ("tower_a", build_tower_a), ("tower_b", build_tower_b),
            ("tower_c", build_tower_c)]
    for name, fn in jobs:
        if not only or name in only:
            fn()
    print("ALL DONE")
