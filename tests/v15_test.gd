extends SceneTree
## v2.1 checks: prop/kit collision bodies, building variety (10 window
## materials, setback crowns), expressway + skybridges + hills, and the
## NPC soft-separation from the player.
var frames: int = 0
var main: Node
var player: Node
var failed: bool = false
var phase: int = 0
var test_npc: Node3D
var dist_before: float = 0.0

func _ok(cond: bool, label: String) -> void:
	print(("PASS " if cond else "FAIL ") + label)
	if not cond:
		failed = true

func _initialize() -> void:
	var ps: PackedScene = load("res://main.tscn")
	main = ps.instantiate()
	root.add_child(main)

func _has_body(n: Node) -> bool:
	if n is StaticBody3D:
		return true
	for c in n.get_children():
		if _has_body(c):
			return true
	return false

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 8 and phase == 0:
		main.call("start_game")
		player = main.get("player")
		var city: Node = main.get("city")
		# Collision on kits + one prop of each kind.
		var kits: Node = city.get_node_or_null("FacadeKits")
		_ok(kits != null and kits.get_child_count() > 0 and _has_body(kits.get_child(0)),
			"facade kit has a collision body")
		var props: Node = city.get_node_or_null("BlenderProps")
		var vend_found: bool = false
		var totem_found: bool = false
		if props != null:
			for ch in props.get_children():
				if ch.name == "Vending" and _has_body(ch):
					vend_found = true
				if ch.name == "HoloTotem" and _has_body(ch):
					totem_found = true
		_ok(vend_found, "vending machine has a collision body")
		_ok(totem_found, "holo totem has a collision body")
		# Variety.
		_ok((city.get("_window_mats") as Array).size() == 10, "10 window material variants")
		_ok((city.get("_buildings") as Array).size() >= 290,
			"buildings + setback crowns recorded (%d)" % (city.get("_buildings") as Array).size())
		# Elevated structures.
		_ok(city.get_node_or_null("Expressway") != null, "expressway exists")
		_ok(int(city.get("skybridge_count")) >= 3, "skybridges built (%d)" % int(city.get("skybridge_count")))
		_ok(city.get_node_or_null("Hills") != null and city.get_node("Hills").get_child_count() == 18, "18 horizon hills")
		_ok((main.get("_deck_cars") as Array).size() == 6, "6 expressway deck cars")
		_ok(absf(((main.get("_deck_cars") as Array)[0] as Node3D).global_position.y - 10.05) < 0.6,
			"deck car rides at deck height")
		# NPC separation: park an NPC right next to the player.
		var npcs: Array = main.get("_npcs")
		test_npc = npcs[0]
		test_npc.global_position = (player as Node3D).global_position + Vector3(0.25, 0, 0)
		dist_before = 0.25
		phase = 1
	elif phase == 1 and frames > 40:
		var d: float = test_npc.global_position.distance_to((player as Node3D).global_position)
		_ok(d > dist_before + 0.15, "NPC shuffled away from player (%.2f -> %.2f)" % [dist_before, d])
		print("V15 TEST DONE")
		quit(1 if failed else 0)
		return true
	return false
