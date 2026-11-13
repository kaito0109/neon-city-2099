class_name People
extends RefCounted
## Registry for the Quaternius CC0 animated characters (see
## assets/people_q/SOURCE.md). Every character shares the same rig and
## clip set (Idle / Walk / Run / Wave / Interact / ...), addressed by
## suffix so the one differently-rigged character (WomanCasual,
## HumanArmature with Female_* clips) works through the same calls.

const CAST: Dictionary = {
	"Punk": {"path": "res://assets/people_q/opt/Punk.glb", "tres": "res://assets/people_data/Punk.tres", "scale": 1.0},
	"Casual": {"path": "res://assets/people_q/opt/Casual.glb", "tres": "res://assets/people_data/Casual.tres", "scale": 1.0},
	"CasualCharacter": {"path": "res://assets/people_q/opt/CasualCharacter.glb", "tres": "res://assets/people_data/CasualCharacter.tres", "scale": 1.0},
	"Suit": {"path": "res://assets/people_q/opt/Suit.glb", "tres": "res://assets/people_data/Suit.tres", "scale": 1.0},
	"AnimatedWoman": {"path": "res://assets/people_q/opt/AnimatedWoman.glb", "tres": "res://assets/people_data/AnimatedWoman.tres", "scale": 1.0},
	"Worker": {"path": "res://assets/people_q/opt/Worker.glb", "tres": "res://assets/people_data/Worker.tres", "scale": 1.0},
	"SciFi": {"path": "res://assets/people_q/opt/SciFi.glb", "tres": "res://assets/people_data/SciFi.tres", "scale": 1.0},
	"WomanCasual": {"path": "res://assets/people_q/opt/WomanCasual.glb", "tres": "res://assets/people_data/WomanCasual.tres", "scale": 0.37},
}

const PEDESTRIANS: Array = ["Casual", "CasualCharacter", "Suit", "AnimatedWoman", "Worker", "SciFi", "WomanCasual"]

static func spawn(cast_name: String) -> Node3D:
	var info: Dictionary = CAST.get(cast_name, {})
	if info.is_empty():
		return null
	var inst: Node3D = ModelLoader.load_model(info["path"], info["tres"])
	if inst != null:
		var s: float = float(info["scale"])
		if not is_equal_approx(s, 1.0):
			inst.scale = Vector3.ONE * s
	return inst

static func find_ap(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for c in node.get_children():
		var r: AnimationPlayer = find_ap(c)
		if r != null:
			return r
	return null

## Play the clip whose name ends with the given suffix ("Walk",
## "Idle_Neutral", ...). Returns false when no such clip exists.
static func play(ap: AnimationPlayer, suffix: String) -> bool:
	if ap == null:
		return false
	for c in ap.get_animation_list():
		if c.ends_with(suffix):
			# Locomotion / idle clips must loop; not every source GLB
			# flags that, so enforce it on the shared Animation.
			var anim: Animation = ap.get_animation(c)
			if anim != null and anim.loop_mode != Animation.LOOP_LINEAR:
				anim.loop_mode = Animation.LOOP_LINEAR
			if ap.current_animation != c:
				ap.play(c)
			return true
	return false

static func has_clip(ap: AnimationPlayer, suffix: String) -> bool:
	if ap == null:
		return false
	for c in ap.get_animation_list():
		if c.ends_with(suffix):
			return true
	return false
