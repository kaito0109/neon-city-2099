"""Build the NEON PEARL cast-metal drain and embed it as a ModelBlob."""
import base64
from pathlib import Path
import tempfile
import bpy

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
metal = bpy.data.materials.new("Dark cast steel")
metal.diffuse_color = (0.075, 0.105, 0.12, 1.0)

def bar(center, dimensions):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    mesh = bpy.context.object
    mesh.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mesh.data.materials.append(metal)

for x in (-0.22, 0.22):
    bar((x, 0, 0), (0.06, 2.4, 0.035))
for index in range(24):
    bar((0, (index - 11.5) * 0.1, 0), (0.48, 0.045, 0.035))

with tempfile.TemporaryDirectory() as directory:
    model = Path(directory) / "neon_drain.glb"
    bpy.ops.export_scene.gltf(filepath=str(model), export_format="GLB")
    data = base64.b64encode(model.read_bytes()).decode("ascii")
    out = Path(__file__).resolve().parents[1] / "assets/model_data/neon_drain.tres"
    out.write_text('[gd_resource type="Resource" script_class="ModelBlob" load_steps=2 format=3]\n\n'
                   '[ext_resource type="Script" path="res://model_blob.gd" id="1"]\n\n'
                   '[resource]\nscript = ExtResource("1")\ndata = PackedByteArray("' + data + '")\n')
