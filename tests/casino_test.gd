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
var last_ball_angle := INF

func _ok(cond: bool, label: String) -> void:
	if cond:
		print("PASS ", label)
	else:
		fails += 1
		print("FAIL ", label)

func _shot(name: String) -> void:
	if "--table-shots" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("/workspace/neon-casino-table-preview")
		root.get_texture().get_image().save_png("/workspace/neon-casino-table-preview/" + name + ".png")

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
		var table_view: Node3D = cui.get("_table_view")
		_ok(table_view != null and root.get_camera_3d() == table_view.camera,
			"seated camera shows the occupied blackjack table")
		_ok(table_view.cards.size() >= 4 and table_view.chips.get_child_count() > 0,
			"3D cards and chips are on the blackjack table")
		stage = 4
		stage_t = 0
	elif stage == 4:
		if stage_t < 70:
			return false
		if stage_t == 70:
			_shot("blackjack")
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
		if (bool(cui.get("_bj_settled")) and stage_t > 20) or stage_t > 600:
			_ok(bool(cui.get("_bj_settled")), "BJ hand settled after reveal")
			var expect: int = chips_before - 100
			for r in bj.call("results"):
				expect += int(r["returned"])
			_ok(int(main.get("chips")) == expect, "BJ chips match session results (%d == %d)" % [int(main.get("chips")), expect])
			cui.call("_unseat")
			_ok(bool(player.get("input_enabled")), "input restored after unseat")
			_ok(root.get_camera_3d() == player.get("_camera") and main.get("hud").visible,
				"walking camera and HUD restored")
			stage = 5
			stage_t = 0
	elif stage == 5 and stage_t > 10:
		# --- roulette: seat, place a straight bet, spin ---
		player.global_position = _table("roulette")["seat_pos"]
		main.call("interact")
		_ok(not (cui.get("_seated") as Dictionary).is_empty(), "seated at roulette")
		stage = 51
		stage_t = 0
	elif stage == 51 and stage_t > 8:
		var spin_button := _find_button(cui.get("_root"), "SPIN")
		var leave_button := _find_button(cui.get("_root"), "離席")
		_ok(root.get_visible_rect().encloses(spin_button.get_global_rect())
			and root.get_visible_rect().encloses(leave_button.get_global_rect()),
			"roulette action buttons fully visible")
		_shot("roulette_betting")
		var view: Node3D = cui.get("_table_view")
		var felt := Vector3((650.0 + 2.5 * 1240.0 / 12.0) / 2048.0 * 3.0 - 1.5,
			0.85, (80.0 + 0.5 * 545.0 / 3.0) / 1024.0 * 1.6 - 0.8)
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = true
		button.position = view.camera.unproject_position(view.to_global(felt))
		cui.set("_roul_denom", 100)
		root.push_input(button, true)
		var bets: Array = cui.get("_roul_bets")
		_ok(bets.size() == 1 and bets[0]["numbers"] == [7],
			"tapping printed 7 through the seated camera places its bet")
		_ok((cui.get("_root") as Control).find_child("BetScroll", true, false) == null,
			"occupied roulette has no scrolling bet grid")
		chips_before = int(main.get("chips"))
		cui.call("_roul_spin")
		var table_view: Node3D = cui.get("_table_view")
		var wheel_center: Vector3 = _table("roulette")["wheel"]["center"]
		_ok(root.get_camera_3d() == table_view.camera and table_view.camera.global_position.distance_to(wheel_center) < 1.4,
			"roulette camera moves close to the occupied wheel")
		_ok(not (cui.get("_spin") as Dictionary).is_empty(), "roulette spin started")
		(cui.get("_spin") as Dictionary)["dur"] = 1.0
		stage = 6
		stage_t = 0
	elif stage == 6 and stage_t < 63:
		if stage_t == 44:
			_shot("roulette")
		elif stage_t == 62:
			_shot("roulette_landed")
		if stage_t >= 20:
			var wheel: Node3D = _table("roulette")["wheel"]["pivot"]
			var ball: Node3D = cui.get("_ball")
			var local := wheel.to_local(ball.global_position)
			var angle := atan2(local.z, local.x)
			if last_ball_angle != INF and wrapf(angle - last_ball_angle, -PI, PI) > 0.0001:
				_ok(false, "ball reversed near the pockets")
			last_ball_angle = angle
	elif stage == 6:
		_ok((cui.get("_spin") as Dictionary).is_empty(), "roulette spin finished")
		var after: int = int(main.get("chips"))
		_ok(after == chips_before - 100 or after == chips_before - 100 + 3600,
			"roulette chips consistent (after=%d)" % after)
		var ball: Node3D = cui.get("_ball")
		var wheel: Node3D = _table("roulette")["wheel"]["pivot"]
		var calibration := preload("res://casino/roulette_wheel.gd")
		var local := wheel.to_local(ball.global_position)
		_ok(ball.visible and is_equal_approx(Vector2(local.x, local.z).length(), calibration.POCKET_RADIUS)
			and is_equal_approx(local.y, calibration.POCKET_HEIGHT + calibration.BALL_RADIUS),
			"ball rests on the pocket floor inside the rotor")
		var result: int = calibration.result_at(wheel, ball.global_position)
		_ok(result == int(cui.get("_roulette_landed_pocket")) and
			after == chips_before - 100 + (3600 if result == 7 else 0),
			"landed pocket determines the actual payment")
		var all_labels_match := true
		for label in wheel.get_node("PocketNumbers").get_children():
			if label is Label3D and int(label.text) != calibration.result_at(wheel, label.global_position):
				all_labels_match = false
		_ok(all_labels_match and wheel.get_node("PocketNumbers").get_child_count() == 38,
			"all 37 rotor numbers match their sectors")
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

