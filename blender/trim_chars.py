import bpy, os, sys

KEEP_MAIN = {"Idle", "Idle_Neutral", "Walk", "Run", "Wave", "Interact", "Death", "HitRecieve", "Roll"}
KEEP_FEM = {"Female_Idle", "Female_Walk", "Female_Run", "Female_Clapping", "Female_Sitting", "Female_Death", "Female_Standing"}
SRC = "/home/hatch/workspace/godot_neon/assets/people_q/"
DST = SRC + "opt/"
names = ["Punk", "Casual", "CasualCharacter", "Suit", "AnimatedWoman", "Worker", "SciFi", "WomanCasual"]
for name in names:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=SRC + name + ".glb")
    keep = KEEP_FEM if name == "WomanCasual" else KEEP_MAIN
    removed = []
    for act in list(bpy.data.actions):
        short = act.name.split("|")[-1]
        if short not in keep:
            removed.append(act.name)
            bpy.data.actions.remove(act)
    kept = [a.name for a in bpy.data.actions]
    bpy.ops.export_scene.gltf(filepath=DST + name + ".glb", export_format='GLB',
        export_animations=True, export_animation_mode='ACTIONS', export_apply=False, export_frame_step=2, export_optimize_animation_size=True)
    print(f"{name}: kept {len(kept)} removed {len(removed)} -> {os.path.getsize(DST + name + '.glb')//1024}KB")
print("ALL DONE")
