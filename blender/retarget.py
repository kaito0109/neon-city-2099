## Retarget Punk's Idle/Walk/Run/Roll onto the Sketchfab cyberpunk
## character's FBX rig, using world-space rotation deltas (axis
## conventions of the two rigs cancel out). Positions follow the
## target's own skeleton; only the hips take a (scaled) translation
## delta. Glasses/eye meshes are bound 100% to the head bone.
## Args: src_glb tgt_glb out_glb
import bpy, sys
from mathutils import Matrix, Vector, Quaternion

argv = sys.argv[sys.argv.index('--') + 1:]
SRC, TGT, OUT = argv[0], argv[1], argv[2]

MAP = {
    "hips_00": "Hips",
    "spine1_01": "Abdomen",
    "spine2_02": "Torso",
    "spine3_03": "Chest",
    "neck_04": "Neck",
    "head_05": "Head",
    "l shoulder_027": "Shoulder.L",
    "l arm_028": "UpperArm.L",
    "l forearm_029": "LowerArm.L",
    "l hand_030": "Wrist.L",
    "r shoulder_08": "Shoulder.R",
    "r arm_09": "UpperArm.R",
    "r forearm_010": "LowerArm.R",
    "r hand_011": "Wrist.R",
    "l leg_047": "UpperLeg.L",
    "l knee_048": "LowerLeg.L",
    "l foot_049": "Foot.L",
    "r leg_051": "UpperLeg.R",
    "r knee_052": "LowerLeg.R",
    "r foot_053": "Foot.R",
}
CLIPS = ["Idle", "Walk", "Run", "Roll"]
HIPS_T = "hips_00"

def find_armature():
    for ob in bpy.context.scene.objects:
        if ob.type == 'ARMATURE':
            return ob
    return None

def rest_matrices(arm):
    if arm.animation_data:
        arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    return {pb.name: pb.matrix.copy() for pb in arm.pose.bones}

# ---------- source ----------
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
src_arm = find_armature()
if src_arm.animation_data:
    for _t in list(src_arm.animation_data.nla_tracks):
        src_arm.animation_data.nla_tracks.remove(_t)
src_actions = {}
for a in bpy.data.actions:
    for c in CLIPS:
        if a.name.endswith("|" + c) or a.name == c:
            src_actions[c] = a
print("SRC actions:", {k: v.name for k, v in src_actions.items()})
src_rest = rest_matrices(src_arm)
src_hips_z = src_rest[MAP[HIPS_T]].translation.z

# ---------- target ----------
before = set(bpy.context.scene.objects)
bpy.ops.import_scene.gltf(filepath=TGT)
tgt_arm = None
for ob in bpy.context.scene.objects:
    if ob.type == 'ARMATURE' and ob not in before:
        tgt_arm = ob

# The FBX ships an "A-pose" NLA track (legs spread in an A). It
# blends over every baked clip in pose evaluation AND in the
# exporter's action sampling, so remove all pre-existing tracks.
if tgt_arm.animation_data:
    for _t in list(tgt_arm.animation_data.nla_tracks):
        tgt_arm.animation_data.nla_tracks.remove(_t)
    tgt_arm.animation_data.action = None

# ---------- flatten + normalize the target hierarchy ----------
# The FBX empty chain (Sketchfab_model -> ... -> Armature) makes the
# exporter emit a character that lies along +Z in Godot at a compound
# scale (~0.0168). Fold every ancestor transform into the objects,
# drop the plain empties, then correct the armature's world matrix
# so the character stands at the origin, feet on z=0, ~1.77 m tall.
# Bone-parented empties (glasses/eyes on head_05) and their children
# are left untouched so they keep following the head.
def _bone_parented(ob):
    p = ob
    while p is not None:
        if p.parent_type == 'BONE':
            return True
        p = p.parent
    return False

bpy.context.view_layer.update()
for ob in list(bpy.context.scene.objects):
    if ob in before or _bone_parented(ob):
        continue
    if ob.parent is not None:
        mw = ob.matrix_world.copy()
        ob.parent = None
        ob.matrix_parent_inverse = Matrix.Identity(4)
        ob.matrix_basis = mw
        bpy.context.view_layer.update()
for ob in list(bpy.context.scene.objects):
    if ob in before or _bone_parented(ob):
        continue
    if ob.type == 'EMPTY':
        bpy.data.objects.remove(ob, do_unlink=True)
bpy.context.view_layer.update()
# Normalize in ARMATURE space, not Blender world space: this FBX rig
# is Y-up in its own frame (hips at y=103.6, feet at y=0), and the
# glTF node transform is interpreted in Godot's Y-up world as-is.
# So the armature's world matrix must become a pure uniform scale
# (no rotation, no translation), and every skinned mesh root gets
# the same rigid correction so the bind pose stays coherent.
# Measure from POSE-bone rest translations: this importer's edit
# bones sit at half scale, but the pose rest is the true joint space
# (hips y=103.6, head joint y~161.7 of a ~168.8-tall rig). Put the
# head joint at 1.70 m, which lands total height at ~1.77 m.
_rest_probe = rest_matrices(tgt_arm)
_top = max(m.translation.z for m in _rest_probe.values())
_h = _top
_s = 1.70 / _top if _top > 0 else 1.0
_old = tgt_arm.matrix_world.copy()
_new = Matrix.Diagonal((_s, _s, _s, 1.0))
_corr = _new @ _old.inverted()
tgt_arm.matrix_basis = _new
bpy.context.view_layer.update()
for ob in bpy.context.scene.objects:
    if ob in before or ob.type != 'MESH':
        continue
    if any(m.type == 'ARMATURE' and m.object == tgt_arm for m in ob.modifiers):
        ob.matrix_basis = _corr @ ob.matrix_world
        bpy.context.view_layer.update()
print(f"FLATTEN armature height={_h:.3f} corr scale={_s:.5f}")

tgt_rest = rest_matrices(tgt_arm)
tgt_hips_z = tgt_rest[HIPS_T].translation.z
# Punk's GLB keeps bone offsets out of pb.matrix translations (its
# Hips rest sits at ~0), so detect units from the target instead:
# hips height > 50 means a cm rig (x100 vs the metre-scale source).
ratio = 100.0 if tgt_hips_z > 50.0 else 1.0
print(f"hips z src={src_hips_z:.3f} tgt={tgt_hips_z:.3f} ratio={ratio:.3f}")

# target hierarchy order (parents before children), mapped bones only
order = []
def visit(pb):
    if pb.name in MAP:
        order.append(pb.name)
    for ch in pb.children:
        visit(ch)
for pb in tgt_arm.pose.bones:
    if pb.parent is None:
        visit(pb)
# rest_local per mapped bone (relative to its mapped-or-real parent)
def rest_local_of(pb_name):
    pb = tgt_arm.pose.bones[pb_name]
    if pb.parent is None:
        return tgt_rest[pb_name]
    return tgt_rest[pb.parent.name].inverted() @ tgt_rest[pb_name]

# ---------- armature-frame alignment ----------
# The two rigs' armature spaces are related by a rotation (Punk's
# pose space is pre-Root-rotation: body-up is +Y there, +Z in the
# target's). World deltas must be conjugated by that frame rotation
# F, or rotations about the swapped axes land wrong (the legs
# splayed ~27 deg while the X-axis arm swings looked fine).
def _frame(rest, hips, head, leg_l, leg_r):
    up = (rest[head].translation - rest[hips].translation).normalized()
    side = (rest[leg_l].translation - rest[leg_r].translation).normalized()
    fwd = side.cross(up)
    side = up.cross(fwd).normalized()
    up = fwd.cross(side).normalized()
    m = Matrix.Identity(3)
    m.col[0] = side
    m.col[1] = up
    m.col[2] = fwd
    return m

_F_s = _frame(src_rest, "Hips", "Head", "UpperLeg.L", "UpperLeg.R")
_F_t = _frame(tgt_rest, HIPS_T, "head_05", "l leg_047", "r leg_051")
_F = _F_t @ _F_s.transposed()
_F_q = _F.to_quaternion()
_F_qi = _F_q.inverted()
print("FRAME F: src up/side -> tgt, angle=", round(_F_q.angle * 57.2958, 1))

# ---------- match the source rest pose to the target's ----------
# World-delta transfer assumes both rigs share a rest pose. The
# legs/spine already match, but Punk rests in a T-pose (arms
# horizontal) while the target is authored in an A-pose (arms ~53
# deg down): transferring the raw delta over-rotates the target's
# arms past vertical. Pose Punk's upper arms into the target's arm
# direction first and re-sample the source rest, so every clip's
# delta is measured from the A-pose.
def _sample_pose(arm):
    bpy.context.view_layer.update()
    return {pb.name: pb.matrix.copy() for pb in arm.pose.bones}

for _sb, _tb_a, _tb_c in [("UpperArm.L", "l arm_028", "l forearm_029"),
                          ("UpperArm.R", "r arm_09", "r forearm_010")]:
    _child = "LowerArm.L" if _sb.endswith(".L") else "LowerArm.R"
    _d_t = (tgt_rest[_tb_c].translation - tgt_rest[_tb_a].translation).normalized()
    _d_want = (_F.transposed() @ _d_t).normalized()
    _d_cur = (src_rest[_child].translation - src_rest[_sb].translation).normalized()
    _R = _d_cur.rotation_difference(_d_want)
    _pb = src_arm.pose.bones[_sb]
    _parent_rest = src_rest[_pb.parent.name]
    _rest_local = _parent_rest.inverted() @ src_rest[_sb]
    _des = Matrix.Translation(src_rest[_sb].translation) @ \
        (_R @ src_rest[_sb].to_quaternion()).to_matrix().to_4x4()
    _pb.rotation_mode = 'QUATERNION'
    _pb.matrix_basis = _rest_local.inverted() @ _parent_rest.inverted() @ _des
    bpy.context.view_layer.update()
    print(f"A-MATCH {_sb}: {round(_d_cur.angle(_d_want) * 57.2958, 1)} deg")
src_rest = _sample_pose(src_arm)

# ---------- bake clips ----------
scene = bpy.context.scene
for clip in CLIPS:
    act = src_actions.get(clip)
    if act is None:
        print("MISSING SRC CLIP", clip)
        continue
    src_arm.animation_data_create()
    src_arm.animation_data.action = act
    f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
    new_act = bpy.data.actions.new(name=clip)
    tgt_arm.animation_data_create()
    tgt_arm.animation_data.action = new_act
    for pb in tgt_arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    for f in range(f0, f1 + 1):
        scene.frame_set(f)
        bpy.context.view_layer.update()
        desired = {}
        for tb in order:
            sb = MAP[tb]
            Ws = src_arm.pose.bones[sb].matrix
            Wd = Ws @ src_rest[sb].inverted()
            Wt0 = tgt_rest[tb]
            d_rot = _F_q @ Wd.to_quaternion() @ _F_qi
            want_rot = (d_rot @ Wt0.to_quaternion()).to_matrix().to_4x4()
            pb = tgt_arm.pose.bones[tb]
            if pb.parent is not None and pb.parent.name in desired:
                parent_des = desired[pb.parent.name]
            elif pb.parent is not None:
                parent_des = tgt_rest[pb.parent.name]
            else:
                parent_des = Matrix.Identity(4)
            base = parent_des @ rest_local_of(tb)
            if tb == HIPS_T:
                pos = Wt0.translation + (_F @ Wd.translation) * ratio
            else:
                pos = base.translation
            des = Matrix.Translation(pos) @ want_rot
            desired[tb] = des
            basis = rest_local_of(tb).inverted() @ parent_des.inverted() @ des
            pb.matrix_basis = basis
        bpy.context.view_layer.update()
        for tb in order:
            pb = tgt_arm.pose.bones[tb]
            pb.keyframe_insert("rotation_quaternion", frame=f)
            if tb == HIPS_T:
                pb.keyframe_insert("location", frame=f)
    print(f"BAKED {clip} frames {f0}..{f1}")

# Push every baked clip onto its own NLA track: the glTF ACTIONS
# exporter only exports the active action plus NLA-strip actions;
# unassigned actions sitting in bpy.data.actions are skipped.
ad = tgt_arm.animation_data
ad.action = None
for clip in CLIPS:
    act = bpy.data.actions.get(clip)
    if act is None:
        continue
    track = ad.nla_tracks.new()
    track.name = clip
    track.strips.new(clip, int(act.frame_range[0]), act)
print("NLA tracks:", [t.name for t in ad.nla_tracks])

# ---------- prep target for export ----------
# delete source objects
for ob in list(bpy.context.scene.objects):
    if ob in before:
        bpy.data.objects.remove(ob, do_unlink=True)
# drop leftover source actions
for a in list(bpy.data.actions):
    if a not in [tgt_arm.animation_data.action] and a.name not in CLIPS:
        bpy.data.actions.remove(a)
# The glasses/eye meshes already follow the head: their empties are
# BONE-parented to head_05 in the source FBX. Skinning them as well
# makes the glTF exporter recurse forever (skinned mesh inside its
# own armature's bone subtree), so only bind meshes with NO
# bone-parented ancestor. A parentless unskinned "Icosphere" at the
# origin is a modelling leftover in this file: delete it.
def _has_bone_parent(ob):
    p = ob
    while p is not None:
        if p.parent_type == 'BONE':
            return True
        p = p.parent
    return False

for ob in list(bpy.context.scene.objects):
    if ob.type != 'MESH':
        continue
    has_arm = any(m.type == 'ARMATURE' for m in ob.modifiers)
    if has_arm or _has_bone_parent(ob):
        continue
    if ob.parent is None and ob.name.startswith("Icosphere"):
        nm = ob.name
        bpy.data.objects.remove(ob, do_unlink=True)
        print("DROPPED stray", nm)
        continue
    ob.data.transform(ob.matrix_world)
    ob.location = (0, 0, 0); ob.rotation_euler = (0, 0, 0); ob.scale = (1, 1, 1)
    vg = ob.vertex_groups.new(name="head_05")
    vg.add(list(range(len(ob.data.vertices))), 1.0, 'REPLACE')
    mod = ob.modifiers.new(name="arm", type='ARMATURE')
    mod.object = tgt_arm
# downscale textures to 1024 (in-process: scaling a packed image
# and then saving a staged .blend silently kept the original bytes)
for im in bpy.data.images:
    if im.size[0] > 0:
        m = max(im.size[0], im.size[1])
        if m > 1024:
            f = 1024 / float(m)
            im.scale(max(1, int(im.size[0] * f)), max(1, int(im.size[1] * f)))
            print("SCALED", im.name, tuple(im.size))
# report world height
lo = Vector((1e9, 1e9, 1e9)); hi = Vector((-1e9, -1e9, -1e9))
for ob in bpy.context.scene.objects:
    if ob.type == 'MESH':
        for c in ob.bound_box:
            w = ob.matrix_world @ Vector(c)
            for i in range(3):
                lo[i] = min(lo[i], w[i]); hi[i] = max(hi[i], w[i])
print(f"WORLD dims={(hi.x-lo.x):.2f}x{(hi.y-lo.y):.2f}x{(hi.z-lo.z):.2f}")
for ob in bpy.context.scene.objects:
    chain = []
    p = ob
    while p is not None and len(chain) < 30:
        chain.append(p.name)
        p = p.parent
    if len(chain) >= 30:
        print("PARENT CYCLE?", ob.name, chain)
# Only the armature may carry animation data into the export: the
# FBX left object-level actions on empties/meshes, and the glTF
# ACTIONS exporter recurses forever on some of them.
for ob in bpy.context.scene.objects:
    if ob != tgt_arm and ob.animation_data:
        ob.animation_data_clear()
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_apply=True,
                          export_animations=True, export_animation_mode='NLA_TRACKS')
print("EXPORTED", OUT)
import os