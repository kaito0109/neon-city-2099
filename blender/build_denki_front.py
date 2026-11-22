"""Author the Denki service frontage in Blender and export a text ModelBlob."""
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

piece("Concrete backing", 0, 2.3, 0, 7.5, 4.6, 0.5, stone)
piece("Cantilever awning", 0, 3.65, 0.83, 7.65, 0.23, 1.15, metal)
piece("Fascia", 0, 4.14, 0.31, 6.8, 0.64, 0.16, frame)
piece("Entry frame", 0, 1.55, 0.32, 2.05, 3.04, 0.18, frame)
piece("Entry glass", 0, 1.57, 0.42, 1.8, 2.8, 0.045, glass)
piece("Entry pull", 0.52, 1.42, 0.47, 0.06, 0.56, 0.08, metal)
for side in (-1, 1):
    x = side * 2.35
    piece("Window casing", x, 1.82, 0.33, 2.26, 2.32, 0.19, metal)
    piece("Display window", x, 1.85, 0.45, 2.05, 2.02, 0.045, glass)
    piece("Counter sill", x, 0.77, 0.51, 2.24, 0.14, 0.32, stone)
    piece("Overhead task light", x, 3.51, 0.77, 1.75, 0.06, 0.14, amber)
    for i in range(3):
        piece("Diagnostic module", x + (i-1)*0.55, 1.56 + i*0.18, 0.49, 0.38, 0.26, 0.05, teal)
    for i in range(6):
        piece("Service grille louver", x, 0.25 + i*0.07, 0.36, 1.82, 0.028, 0.10, frame)
    piece("Vertical conduit", side*3.56, 2.1, 0.36, 0.075, 3.95, 0.075, frame)

# Consolidate parts by material for browser/mobile rendering.
for mat in (stone, metal, frame, glass, amber, teal):
    objects = [obj for obj in bpy.context.scene.objects if obj.data.materials[0] == mat]
    for obj in objects:
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.convert(target="MESH")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    bpy.context.object.name = mat.name

with TemporaryDirectory() as directory:
    model = Path(directory) / "denki_front.glb"
    bpy.ops.export_scene.gltf(filepath=str(model), export_format="GLB")
    payload = base64.b64encode(model.read_bytes()).decode("ascii")
    output = Path(__file__).resolve().parents[1] / "assets/model_data/denki_front.tres"
    output.write_text('[gd_resource type="Resource" script_class="ModelBlob" load_steps=2 format=3]\n\n'
                      '[ext_resource type="Script" path="res://model_blob.gd" id="1"]\n\n'
                      '[resource]\nscript = ExtResource("1")\ndata = PackedByteArray("' + payload + '")\n')
