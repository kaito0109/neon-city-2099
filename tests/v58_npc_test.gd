extends SceneTree
## v5.8 NPC ground test: pedestrians on the NE terrace block
## (150,-136, flat y=12) must follow the real terrain — near the
## switch-road corridor the ground rises to ~14.2 m, and NPCs used
## to sink up to ~2 m into it (his iPhone photo). Spawn walkers +
## standers on that block (and the 6 m block), let them walk for
## 60 sim-seconds, and check every sampled NPC height against the
## terrain height function.
const NpcScript := preload("res://npc.gd")
var frames: int = 0
var main: Node
var city: Node
var test_npcs: Array = []
var worst: float = 0.0
var worst_at: Vector3 = Vector3.ZERO
var samples: int = 0
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	rng.seed = 1234567
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _spawn_on_block(cx: float, cz: float) -> void:
	var blocks: Array = city.get("sidewalk_blocks")
	for blk in blocks:
		var c: Vector3 = blk["center"]
		if absf(c.x - cx) < 1.0 and absf(c.z - cz) < 1.0:
			for i in range(4):
				var npc: Node3D = NpcScript.new()
				npc.add_to_group("npcs")
				main.add_child(npc)
				npc.call("setup", c, float(blk["half"]), "Casual", rng, false)
				test_npcs.append(npc)
			for i in range(2):
				var npc2: Node3D = NpcScript.new()
				npc2.add_to_group("npcs")
				main.add_child(npc2)
				npc2.call("setup", c, float(blk["half"]), "Suit", rng, true)
				test_npcs.append(npc2)
			return
	print("V58NPC FAIL block not found ", cx, ",", cz)

func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 20:
		main.call("start_game")
		city = main.get("city")
		_spawn_on_block(150.0, -136.0)
		_spawn_on_block(90.0, -95.0)
	if frames > 120 and frames % 30 == 0:
		for npc in test_npcs:
			var gp: Vector3 = (npc as Node3D).global_position
			var th: float = float(city.call("_terrain_height", gp.x, gp.z))
			var err: float = absf(gp.y - th)
			samples += 1
			if err > worst:
				worst = err
				worst_at = gp
	if frames >= 3620:
		print("V58NPC samples=", samples, " worst |npc_y - terrain| = ",
				snappedf(worst, 0.001), " at ", worst_at)
		if test_npcs.size() < 12:
			print("V58NPC FAIL test NPCs missing: ", test_npcs.size())
		elif worst > 0.06:
			print("V58NPC FAIL NPCs off the ground")
		else:
			print("V58NPC PASS")
		quit()
	return false
