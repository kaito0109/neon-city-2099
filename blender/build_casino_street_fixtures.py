"""Author the casino district street fixtures in Blender and export a text ModelBlob."""
import base64
from pathlib import Path
from tempfile import TemporaryDirectory

import bpy

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

def material(name, rgb, roughness, metallic=0.0, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Emission Color"].default_value = (*rgb, 1)
    shader.inputs["Emission Strength"].default_value = emission
    return mat

stone = material("Cast concrete", (0.20, 0.22, 0.23), 0.85)
metal = material("Petrol enamel", (0.08, 0.23, 0.26), 0.4, 0.45)
frame = material("Anodized frames", (0.08, 0.09, 0.10), 0.34, 0.65)
glass = material("Smoked display glass", (0.07, 0.16, 0.21), 0.19, 0.55, 0.12)
amber = material("Diffused work lights", (1.0, 0.62, 0.30), 0.55, emission=2)
teal = material("Diagnostic displays", (0.10, 0.62, 0.56), 0.55, emission=1.1)

def piece(name, x, height, depth, width, tall, thick, mat):
    # Blender -Y becomes the storefront's +Z in Godot.
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, -depth, height))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = (width, thick, tall)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new("Fabricated edges", "BEVEL")
    bevel.width = min(0.022, min(width, tall, thick) * 0.22)
    bevel.segments = 2
    obj.data.materials.append(mat)

def export(name, materials):
    # Consolidate parts by material for browser/mobile rendering.
    for mat in materials:
        objects = [obj for obj in bpy.context.scene.objects if obj.data.materials[0] == mat]
        if not objects:
            continue
        for obj in objects:
            bpy.ops.object.select_all(action="DESELECT")
            obj.select_set(True)
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.convert(target="MESH")
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        if len(objects) > 1:
            bpy.ops.object.join()
        bpy.context.object.name = mat.name

    with TemporaryDirectory() as directory:
        model = Path(directory) / (name + ".glb")
        bpy.ops.export_scene.gltf(filepath=str(model), export_format="GLB")
        payload = base64.b64encode(model.read_bytes()).decode("ascii")
        output = Path(__file__).resolve().parents[1] / "assets/model_data" / (name + ".tres")
        output.write_text('[gd_resource type="Resource" script_class="ModelBlob" load_steps=2 format=3]\n\n'
                          '[ext_resource type="Script" path="res://model_blob.gd" id="1"]\n\n'
                          '[resource]\nscript = ExtResource("1")\ndata = PackedByteArray("' + payload + '")\n')


# The clinic kit is mounted on the west wall with +Z toward the plaza.
piece("Service canopy", 0, 3.0, 0.43, 5.8, 0.21, 0.9, stone)
piece("Wayfinding strip", 0, 2.86, 0.75, 5.4, 0.075, 0.08, teal)
piece("Double door surround", 0, 1.37, 0.08, 2.7, 2.74, 0.19, frame)
for x in (-0.63, 0.63):
    piece("Frosted door panel", x, 1.39, 0.20, 1.15, 2.47, 0.07, glass)
    piece("Push rail", x, 1.1, 0.26, 0.84, 0.08, 0.08, stone)
for x in (-2.1, 2.1):
    piece("Wall panel", x, 1.55, 0.06, 1.02, 2.61, 0.13, metal)
    piece("Call panel", x, 1.38, 0.17, 0.24, 0.42, 0.09, teal)
export("clinic_front", (stone, frame, glass, metal, teal))

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
rust = material("Oxblood powder coat", (0.32, 0.075, 0.04), 0.65)
piece("Vendor canopy", 0, 2.8, 0, 2.9, 0.19, 2.05, rust)
piece("Warm task strip", 0, 2.67, 0.78, 2.62, 0.08, 0.12, amber)
piece("Counter skin", 0, 0.48, 0, 2.49, 0.95, 1.18, rust)
piece("Steel worktop", 0, 0.99, 0.03, 2.58, 0.10, 1.18, frame)
piece("Menu lightbox", -0.7, 1.85, -0.4, 0.92, 0.56, 0.08, amber)
for x in (-1.1, 1.1):
    piece("Canopy post", x, 1.84, -0.55, 0.09, 1.79, 0.09, frame)
for x in (0.33, 0.59, 0.85):
    piece("Ingredient tray", x, 1.1, 0.1, 0.21, 0.12, 0.31, stone)
export("night_bites", (rust, amber, frame, stone))
