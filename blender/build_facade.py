import bpy
import math
import os
from mathutils import Vector

OUT = "/home/hatch/workspace/godot_neon/assets/models"
os.makedirs(OUT, exist_ok=True)

def mat(name, color, rough=0.8, metal=0.0, emission=None, estr=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = estr
    return m

def box(name, loc, scale, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = (scale[0] / 2, scale[1] / 2, scale[2] / 2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if material:
        o.data.materials.append(material)
    return o

def cyl(name, loc, radius, depth, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=loc, rotation=rot, vertices=12)
    o = bpy.context.object
    o.name = name
    if material:
        o.data.materials.append(material)
    return o

def build_kit():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    M_DARK = mat("DarkMetal", (0.13, 0.13, 0.16), 0.6, 0.4)
    M_GLASS = mat("ShopGlass", (0.04, 0.07, 0.11), 0.18, 0.5)
    M_SIGN = mat("SignPanel", (0.25, 0.02, 0.1), 0.5, 0.0, emission=(1.0, 0.15, 0.5), estr=2.5)
    M_STRIP = mat("NeonStrip", (0.0, 0.2, 0.25), 0.5, 0.0, emission=(0.15, 0.9, 1.0), estr=2.5)
    M_AWN = mat("AwningMat", (0.22, 0.08, 0.1), 0.85, 0.0)
    parts = []
    # Back wall (building face the shopfront mounts on).
    parts.append(box("BackWall", (0, 0.28, 2.1), (10.4, 0.56, 4.2), M_DARK))
    # Entrance step.
    parts.append(box("Step", (0, -0.75, 0.09), (10.0, 1.5, 0.18), M_DARK))
    # Shopfront glass band.
    parts.append(box("Glass", (0, -0.05, 1.55), (8.4, 0.1, 2.5), M_GLASS))
    # Mullions in front of the glass.
    for i, x in enumerate([-4.2, -2.1, 0.0, 2.1, 4.2]):
        parts.append(box("Mull%d" % i, (x, -0.12, 1.55), (0.14, 0.08, 2.6), M_DARK))
    # Sill + header beams.
    parts.append(box("Sill", (0, -0.1, 0.28), (8.8, 0.16, 0.14), M_DARK))
    parts.append(box("Header", (0, -0.1, 2.95), (8.8, 0.16, 0.3), M_DARK))
    # Awning angled over the shopfront + neon strip under it.
    parts.append(box("Awning", (0, -0.62, 3.28), (9.6, 1.35, 0.1), M_AWN, rot=(math.radians(18), 0, 0)))
    parts.append(box("Strip", (0, -1.18, 3.02), (9.6, 0.07, 0.07), M_STRIP))
    # Sign board on top, set forward.
    parts.append(box("Sign", (0, -0.32, 3.95), (8.8, 0.55, 0.85), M_SIGN))
    parts.append(box("SignBack", (0, -0.05, 3.95), (9.2, 0.2, 1.0), M_DARK))
    # AC unit on the left end + fan disc.
    parts.append(box("AC", (-4.55, 0.1, 3.3), (0.85, 0.75, 0.8), M_DARK))
    parts.append(cyl("ACFan", (-4.55, -0.3, 3.3), 0.26, 0.06, M_GLASS, rot=(math.radians(90), 0, 0)))
    # Drain pipe on the right end.
    parts.append(cyl("Pipe", (4.95, 0.1, 2.1), 0.07, 4.2, M_DARK))
    # Join into one object.
    bpy.ops.object.select_all(action='DESELECT')
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    kit = bpy.context.object
    kit.name = "FacadeKit"
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "facade_kit.glb"),
        export_format='GLB', export_apply=True, export_yup=True)
    print("KIT exported, dims:", tuple(round(d, 2) for d in kit.dimensions))

build_kit()

# --- Preview render ---
scene = bpy.context.scene
for o in list(bpy.data.objects):
    if o.name != "FacadeKit":
        bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
bpy.ops.object.light_add(type='AREA', location=(3, -5, 6))
bpy.context.object.data.energy = 700
bpy.ops.object.light_add(type='POINT', location=(-4, -3, 2.5))
bpy.context.object.data.energy = 120
cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
cam.location = (4.5, -8.5, 2.6)
def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()
look_at(cam, (0, 0, 1.6))
scene.camera = cam
scene.render.engine = 'CYCLES'
scene.cycles.samples = 24
scene.render.resolution_x = 900
scene.render.resolution_y = 550
scene.render.filepath = "/home/hatch/workspace/godot_neon/shots_blender/facade_kit.png"
bpy.ops.render.render(write_still=True)
print("preview rendered")
