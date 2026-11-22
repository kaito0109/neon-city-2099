"""Author the the roulette table with a fully printable rectangular top in Blender and export a text ModelBlob."""
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



# Blender +Y is the far edge of the table in Godot. Only the top
# face receives the existing roulette print at runtime.
felt = material("RouletteFeltTouch", (0.024, 0.20, 0.10), 0.85)
piece("Walnut tabletop", 0, 0.80, 0, 3.04, 0.096, 1.64, frame)
piece("Apron", 0, 0.70, 0, 2.72, 0.13, 1.35, frame)
for x in (-1.17, 1.17):
    piece("Table leg", x, 0.35, 0, 0.16, 0.70, 0.68, metal)
piece("Footrest", 0, 0.10, 0.27, 2.4, 0.08, 0.10, metal)

mesh = bpy.data.meshes.new("Felt print")
mesh.from_pydata([(-1.5, -0.8, 0.85), (1.5, -0.8, 0.85),
                  (1.5, 0.8, 0.85), (-1.5, 0.8, 0.85)], [], [(0, 1, 2, 3)])
mesh.update()
uvs = mesh.uv_layers.new(name="UVMap")
for loop in mesh.loops:
    vertex = mesh.vertices[loop.vertex_index].co
    uvs.data[loop.index].uv = ((vertex.x + 1.5) / 3, (vertex.y + 0.8) / 1.6)
top = bpy.data.objects.new("Felt print", mesh)
bpy.context.collection.objects.link(top)
mesh.materials.append(felt)
export("casino_roulette_table", (frame, metal, felt))
