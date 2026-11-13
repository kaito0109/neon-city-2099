extends SceneTree
## v2 (people) checks: rigged Quaternius characters for the player and
## the crowd, clip state machine hooks, crowd size, standing NPCs,
## animation distance culling, and the knock-down path.
var frames: int = 0
var main: Node
var player: Node
var failed: bool = false
var phase: int = 0
var settle: int = 0
var far_npc: Node

func _ok(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		failed = true

func _initialize() -> void:
	var ps: PackedScene = load("res://main.tscn")
	main = ps.instantiate()
	root.add_child(main)

func _find_sk(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r: Skeleton3D = _find_sk(c)
		if r != null:
			return r
	return null

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 8 and phase == 0:
		main.call("start_game")
		player = main.get("player")
		# --- Player is the Punk with a full clip set ---
		var sk: Skeleton3D = _find_sk(player)
		_ok(sk != null and sk.get_bone_count() >= 60, "player has a real skeleton (%d bones)" % (sk.get_bone_count() if sk != null else -1))
		var ap: AnimationPlayer = People.find_ap(player)
		_ok(ap != null, "player has AnimationPlayer")
		_ok(People.has_clip(ap, "Idle") and People.has_clip(ap, "Walk") and People.has_clip(ap, "Run"),
			"player clips Idle/Walk/Run present")
		_ok(People.play(ap, "Walk") and ap.current_animation.ends_with("Walk"), "clip switch to Walk works")
		People.play(ap, "Idle")
		# --- Crowd size and composition ---
		var npcs: Array = main.get("_npcs")
		_ok(npcs.size() == 120, "crowd size is 120 (got %d)" % npcs.size())
		var standing_count: int = 0
		var with_ap: int = 0
		var active_or_culled: int = 0
		var near_playing: int = 0
		var near_total: int = 0
		for npc in npcs:
			if bool(npc.get("_standing")):
				standing_count += 1
			var nap: AnimationPlayer = People.find_ap(npc)
			if nap != null:
				with_ap += 1
				if nap.is_playing() or not nap.playback_active:
					active_or_culled += 1
				if (npc as Node3D).global_position.distance_to((player as Node3D).global_position) < 55.0:
					near_total += 1
					if nap.is_playing():
						near_playing += 1
		_ok(standing_count == 40, "standing NPCs = 40 (got %d)" % standing_count)
		_ok(with_ap == 120, "every NPC has an AnimationPlayer (got %d)" % with_ap)
		_ok(active_or_culled == 120, "every NPC animates or is distance-culled (got %d)" % active_or_culled)
		_ok(near_total > 0 and near_playing == near_total, "all near NPCs are animating (%d/%d)" % [near_playing, near_total])
		# Pick an NPC far from the player for the culling check.
		for npc in npcs:
			if (npc as Node3D).global_position.distance_to((player as Node3D).global_position) > 80.0:
				far_npc = npc
				break
		_ok(far_npc != null, "found a far NPC for culling check")
		phase = 1
	elif phase == 1:
		settle += 1
		if settle == 40:
			var fap: AnimationPlayer = People.find_ap(far_npc)
			_ok(fap != null and not fap.playback_active, "far NPC animation is culled (playback_active=false)")
			# --- Knock-down path ---
			far_npc.call("hit_by_car")
			_ok(bool(far_npc.call("is_down")), "hit_by_car downs the NPC")
			print("V13 TEST DONE")
			quit(1 if failed else 0)
			return true
	return false
