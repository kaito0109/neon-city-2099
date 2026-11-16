## Clean a downloaded Sketchfab model for NEON CITY: join meshes,
## decimate, downscale textures, normalise scale, base at origin,
## export GLB. Args after --:
##   input output tex_cap decimate_ratio mode value [texdir]
## mode: height | length | none   (value in metres, ignored for none)
import bpy, sys, os, mathutils

argv = sys.argv[sys.argv.index('--') + 1:]
inp, outp = argv[0], argv[1]
tex_cap = int(argv[2]); dec_ratio = float(argv[3])
mode = argv[4]; value = float(argv[5])
texdir = argv[6] if len(argv) > 6 else ""

bpy.ops.wm.read_factory_settings(use_empty=True)
if inp.lower().endswith('.blend'):
    # Link meshes out of the .blend instead of open_mainfile: opening
    # a foreign scene breaks operator context in --background mode.
    with bpy.data.libraries.load(inp) as (src, dst):
        dst.objects = list(src.objects)
    for ob in dst.objects:
        if ob is not None and ob.type == 'MESH':
            bpy.context.collection.objects.link(ob)
else:
    bpy.ops.import_scene.gltf(filepath=inp)

# Repoint images into texdir by basename (for .blend originals whose
# textures live outside the file), then pack everything.
if texdir:
    for im in bpy.data.images:
        base = os.path.basename(im.filepath) if im.filepath else im.name
        cand = os.path.join(texdir, base)
        if os.path.exists(cand):
            im.filepath = cand
            im.reload()
try:
    bpy.ops.file.pack_all()
except Exception as e:
    print("pack warn:", e)

# Bake each mesh's FULL world transform (incl. parent rotation/scale
# — Sketchfab GLBs nest Y-up geometry under converted parents) into
# its geometry, then drop the empties.
meshes = [ob for ob in bpy.context.scene.objects if ob.type == 'MESH']
if not meshes:
    print("CLEAN_FAIL no meshes"); sys.exit(1)
kept = []
for ob in meshes:
    if len(ob.data.materials) == 0:
        # Material-less meshes (shadow-catcher planes etc.) render
        # default-white in Godot — never wanted.
        bpy.data.objects.remove(ob, do_unlink=True)
    else:
        kept.append(ob)
meshes = kept
if not meshes:
    print("CLEAN_FAIL all dropped"); sys.exit(1)
for ob in meshes:
    ob.data.transform(ob.matrix_world)
    ob.parent = None
    ob.location = (0.0, 0.0, 0.0)
    ob.rotation_euler = (0.0, 0.0, 0.0)
    ob.scale = (1.0, 1.0, 1.0)
for ob in list(bpy.context.scene.objects):
    if ob.type != 'MESH':
        bpy.data.objects.remove(ob, do_unlink=True)

bpy.ops.object.select_all(action='DESELECT')
for ob in meshes:
    ob.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active

if dec_ratio > 0.0:
    if ob.data.shape_keys:
        ob.shape_key_clear()
    mod = ob.modifiers.new(name="dec", type='DECIMATE')
    mod.ratio = dec_ratio
    bpy.ops.object.modifier_apply(modifier=mod.name)

def world_bbox(o):
    lo = mathutils.Vector((1e9, 1e9, 1e9)); hi = mathutils.Vector((-1e9, -1e9, -1e9))
    for c in o.bound_box:
        w = o.matrix_world @ mathutils.Vector(c)
        for i in range(3):
            lo[i] = min(lo[i], w[i]); hi[i] = max(hi[i], w[i])
    return lo, hi

lo, hi = world_bbox(ob)
size = hi - lo
if mode == 'height' and size.z > 0:
    s = value / size.z
elif mode == 'length' and max(size.x, size.y) > 0:
    s = value / max(size.x, size.y)
else:
    s = 1.0
ob.scale = (s, s, s)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
lo, hi = world_bbox(ob)
ctr = (lo + hi) * 0.5
ob.location = ob.location - mathutils.Vector((ctr.x, ctr.y, lo.z))
bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

for im in bpy.data.images:
    if im.size[0] > 0:
        m = max(im.size[0], im.size[1])
        if m > tex_cap:
            f = tex_cap / float(m)
            im.scale(max(1, int(im.size[0] * f)), max(1, int(im.size[1] * f)))

ob.data.calc_loop_triangles()
lo, hi = world_bbox(ob)
print(f"CLEAN_OK {os.path.basename(outp)} tris={len(ob.data.loop_triangles)} "
      f"dims={(hi.x-lo.x):.1f}x{(hi.y-lo.y):.1f}x{(hi.z-lo.z):.1f}")
os.makedirs(os.path.dirname(outp), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=outp, export_format='GLB', export_apply=True)
print("EXPORTED", outp, os.path.getsize(outp))
