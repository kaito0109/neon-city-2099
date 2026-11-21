extends SceneTree
## Casino integration (headless): enter, cage buy/sell, a full BJ
## hand through the real UI flow, a roulette spin, poker buy-in and
## leave, the VIP gate for non-GOLD and GOLD players.
const ROL := preload("res://casino/roulette_logic.gd")

var frames: int = 0
var main: Node
var player: Node3D
var cui: Node
var stage: int = 0
var stage_t: int = 0
var fails: int = 0
var casino_i: int = -1
var site: Dictionary = {}
var cz: Dictionary = {}
var chips_before: int = 0

func _ok(cond: bool, label: String) -> void:
	if cond:
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)

func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _find_button(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text == text:
		return n as Button
	for c in n.get_children():
		var r: Button = _find_button(c, text)
		if r != null:
			return r
	return null

func _table(kind: String, vip: bool = false) -> Dictionary:
	for t in cz["tables"]:
		if String(t["kind"]) == kind and bool(t["vip"]) == vip:
			return t
	return {}

func _process(_delta: float) -> bool:
	frames += 1
	stage_t += 1
	if frames == 20 and stage == 0:
		main.call("start_game")
		player = main.get("player")
		cui = main.get("casino_ui")
		var sites: Array = main.get("city").get("shop_sites")
		for i in range(sites.size()):
			if String(sites[i]["kind"]) == "casino":
				casino_i = i
				site = sites[i]
				cz = site["casino"]
		_ok(casino_i >= 0, "casino site found")
		var circle_faces_room := false
		for child in main.get("city").get_children():
			if child is Label3D and child.text == "NEON CIRCLE":
				circle_faces_room = child.global_basis.z.dot(Vector3.RIGHT) > 0.99
		_ok(circle_faces_room, "NEON CIRCLE front faces room (+X)")
		main.set("money", 5000)
		player.global_position = site["door_pos"]
		stage = 1
		stage_t = 0
	elif stage == 1 and stage_t > 10:
		main.call("interact")
		_ok(int(main.get("in_shop")) == casino_i, "entered casino")
		player.global_position = (cz["cage_pos"] as Array)[1]
		stage = 2
		stage_t = 0
	elif stage == 2 and stage_t > 10:
		main.call("interact")
		_ok(_find_button(cui.get("_root"), "チップを買う") != null, "cage panel opened")
		cui.set("_cage_amount", 1000)
		_find_button(cui.get("_root"), "チップを買う").emit_signal("pressed")
		_ok(int(main.get("chips")) == 1000 and int(main.get("money")) == 4000, "bought 1000 chips")
		cui.set("_cage_amount", 400)
		_find_button(cui.get("_root"), "換金する").emit_signal("pressed")
		_ok(int(main.get("chips")) == 600 and int(main.get("money")) == 4400, "sold 400 chips back")
		cui.call("_close_panel")
		main.set("chips", 100000)
		# --- blackjack: seat and play one hand to settlement ---
		player.global_position = _table("bj")["seat_pos"]
		stage = 3
		stage_t = 0
	elif stage == 3 and stage_t > 10:
		_ok("CHIP 100000" in String(main.get("hud").get("money_label").text), "HUD receives live chip balance")
		main.call("interact")
		_ok(not (cui.get("_seated") as Dictionary).is_empty(), "seated at BJ")
		_ok(not bool(player.get("input_enabled")), "player input locked while seated")
		cui.set("_bj_bet", 100)
		chips_before = int(main.get("chips"))
		cui.call("_bj_deal")
		_ok(cui.get("_bj") != null, "BJ hand dealt")
		stage = 4
		stage_t = 0
	elif stage == 4:
		var bj: RefCounted = cui.get("_bj")
		if bj != null:
			var guard: int = 0
			while String(bj.get("phase")) == "insurance" and guard < 4:
				bj.call("decline_insurance")
				cui.call("_bj_after_action")
				guard += 1
			guard = 0
			while String(bj.get("phase")) == "player" and guard < 40:
				bj.call("stand")
				cui.call("_bj_after_action")
				guard += 1
		if stage_t > 200:
			_ok(bool(cui.get("_bj_settled")), "BJ hand settled after reveal")
			var expect: int = chips_before - 100
			for r in bj.call("results"):
				expect += int(r["returned"])
			_ok(int(main.get("chips")) == expect, "BJ chips match session results (%d == %d)" % [int(main.get("chips")), expect])
			cui.call("_unseat")
			_ok(bool(player.get("input_enabled")), "input restored after unseat")
			stage = 5
			stage_t = 0
	elif stage == 5 and stage_t > 10:
		# --- roulette: seat, place a straight bet, spin ---
		player.global_position = _table("roulette")["seat_pos"]
		main.call("interact")
		_ok(not (cui.get("_seated") as Dictionary).is_empty(), "seated at roulette")
		cui.set("_roul_denom", 100)
		cui.call("_roul_add", ROL.straight(7))
		chips_before = int(main.get("chips"))
		cui.call("_roul_spin")
		_ok(not (cui.get("_spin") as Dictionary).is_empty(), "roulette spin started")
		(cui.get("_spin") as Dictionary)["dur"] = 0.3
		stage = 6
		stage_t = 0
	elif stage == 6 and stage_t > 40:
		_ok((cui.get("_spin") as Dictionary).is_empty(), "roulette spin finished")
		var after: int = int(main.get("chips"))
		_ok(after == chips_before - 100 or after == chips_before - 100 + 3600,
			"roulette chips consistent (after=%d)" % after)
		_ok(bool(cui.get("_ball").visible), "ball rests in the wheel")
		cui.call("_unseat")
		stage = 7
		stage_t = 0
	elif stage == 7 and stage_t > 10:
		# --- poker: buy-in, a few CPU steps, leave with the stack ---
		player.global_position = _table("poker")["seat_pos"]
		chips_before = int(main.get("chips"))
		main.call("interact")
		_ok(cui.get("_pk") != null, "poker game created")
		_ok(int(main.get("chips")) == chips_before - 2500, "poker buy-in deducted")
		stage = 8
		stage_t = 0
	elif stage == 8 and stage_t > 120:
		var leave: Button = _find_button(cui.get("_root"), "離席")
		_ok(leave != null, "poker leave button present")
		if leave != null:
			leave.emit_signal("pressed")
		_ok((cui.get("_seated") as Dictionary).is_empty(), "left poker table")
		_ok(int(main.get("chips")) > chips_before - 2500 - 100, "stack returned on leave")
		stage = 9
		stage_t = 0
	elif stage == 9 and stage_t > 10:
		# --- VIP gate: non-GOLD is pushed out, GOLD may stay ---
		main.set("casino_stats", {"total_bet": 0, "total_returned": 0})
		var c: Vector3 = cz["center"]
		player.global_position = c + Vector3(30, 0.2, -20)
		stage = 10
		stage_t = 0
	elif stage == 10 and stage_t > 15:
		var out: Vector3 = cz["vip_door_out"]
		_ok(player.global_position.distance_to(out) < 1.5, "non-GOLD pushed out of VIP")
		main.set("casino_stats", {"total_bet": 100000000, "total_returned": 0})
		var c2: Vector3 = cz["center"]
		player.global_position = c2 + Vector3(30, 0.2, -20)
		stage = 11
		stage_t = 0
	elif stage == 11 and stage_t > 15:
		_ok(player.global_position.x > cz["center"].x + 25.0, "GOLD may stay in VIP")
		player.global_position = site["exit_pos"]
		stage = 12
		stage_t = 0
	elif stage == 12 and stage_t > 10:
		main.call("interact")
		_ok(int(main.get("in_shop")) == -1, "exited casino")
		print("CASINO_TEST_DONE fails=", fails)
		quit(1 if fails > 0 else 0)
	return false

