extends Node3D
## NEON CITY 2099 — orchestration: city, actors, missions, wanted, economy.

const CityScript := preload("res://world_v4.gd")
const PlayerScript := preload("res://player.gd")
const CarScript := preload("res://car.gd")
const NpcScript := preload("res://npc.gd")
const DroneScript := preload("res://drone.gd")
const HudScript := preload("res://hud.gd")
const CasinoUiScript := preload("res://casino/casino_ui.gd")

var city: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var game_font: Font

var started: bool = false
var panel_mode: String = "start"
var money: int = 150
var wanted: int = 0
var touch_drive: Vector2 = Vector2.ZERO
var touch_vertical: float = 0.0

var _rng := RandomNumberGenerator.new()
var _clock_min: float = 21.0 * 60.0
var _drones: Array = []
var _drone_was: Array[bool] = [false, false, false, false]
var _drone_cd: Array[float] = [0, 0, 0, 0]
var _escape_t: float = 0.0
var _hit_cd: float = 0.0
var _cars: Array = []
var _deck_cars: Array = []
var _npcs: Array = []

# Mission state.
var mission: String = ""           # "" | pickup | hack | race | courier | errand | rooftop
var in_shop: int = -1              # index into city.shop_sites; -1 = on the street
var items: Dictionary = {}         # consumable id -> count
var item_defs: Dictionary = {}     # consumable id -> {label, price, heal}
var _shop_target: int = -1         # shop index used by courier / errand
# Casino (v6.0): chips are a separate balance from cash; NEON CIRCLE
# points derive from the lifetime total bet (100 bet = 1 pt).
var chips: int = 0
var casino_stats: Dictionary = {"total_bet": 0, "total_returned": 0}
var casino_ui: CanvasLayer = null
var mission_stage: String = ""     # pickup: go|deliver ; race uses gate idx
var mission_target_pos: Variant = null
var _race_gates: Array[Vector3] = []
var _race_idx: int = 0
var _race_t: float = 0.0
var _hack_channel: float = -1.0
var _marker: Node3D
var _marker_mat: StandardMaterial3D
var _chip: Node3D
var _gate_ring: MeshInstance3D

const CLINIC_POS := Vector3(38, 0.6, 20)  # v4: clinic east of the plaza
const SPAWN_POS := Vector3(0, 0.6, 48)    # v4: plaza south, facing the megabuilding

func _ready() -> void:
	add_to_group("main")
	_rng.seed = 777
	_build_environment()
	game_font = _load_font()
	city = CityScript.new()
	add_child(city)
	city.call("build", game_font)
	player = PlayerScript.new()
	player.position = SPAWN_POS
	add_child(player)
	player.call("make_camera_current")
	_spawn_cars()
	_spawn_npcs()
	_spawn_drones()
	_build_marker()
	hud = HudScript.new()
	add_child(hud)
	hud.set("main", self)
	hud.set("player", player)
	var latin_font: Font = FontLoader.load_font(
		"res://assets/fonts/Rajdhani-Bold.ttf",
		"res://assets/font_data/rajdhani_bold.tres")
	hud.call("build", game_font, latin_font)
	casino_ui = CasinoUiScript.new()
	add_child(casino_ui)
	casino_ui.call("setup", self, game_font)
	hud.call("show_panel", "NEON CITY 2099",
		"2099年、ネオンの街ネオ・キバラ。運び屋として街を駆け、仕事をこなしてエディ（€$）を稼げ。\n\n移動: WASD / 左スティック　視点: マウス / 右ドラッグ\nダッシュ: Shift　ジャンプ: Space　調べる・乗る: F / ACT\n車の運転: 乗って W/S・A/D　全体マップ: M\n飛行: 車で R / FLYボタン切替、GAS/BRK（W/S）で前後、左スティック上下（Space/Shift）で昇降\nパルクール: 空中で壁に向かってジャンプで壁登り、空中でもう一度ジャンプで二段ジャンプ\n\nJOBキオスクで仕事を受けよう。ハッキングと事故は警察ドローンを呼ぶ。\n\n3Dモデル: SKY T 021 by AL3K / Apartment by Jungle Jim / Milk&Peach by Malilynn / Hotel by IQINSO / Tower by Ayman.Ibrahim / Hovercar by Lionsharp Studios (CC BY-SA) / Sci-fi car by Boberemn / Flying car by Mitya Petrov / Vending by samborn & thekillinggmoon / 主人公 Cyberpunk character by 4d_Bob（いずれも CC BY、Sketchfab）",
		"スタート")

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	# Graded night sky with a city-glow horizon (a flat BG colour read
	# as a black void above the rooftops).
	var sky_mat := ProceduralSkyMaterial.new()
	# v3 (P3): dusk is the hero time — a low warm sun band on the
	# horizon under an indigo zenith, so sky light and neon read in
	# the same frame (the game's day AND night identities at once).
	# v4 Phase 2.5 (かいと's reference: CP2077 at 3:52 AM): the sky
	# is NEVER black in Night City — light pollution keeps it a pale
	# teal-grey, buildings stand as dark masses against it, and the
	# light in the scene comes from signs and screens. So: light
	# sky, cool ambient, denser blue-grey haze.
	# v5.5 AAA pass (diff #1-3): the v4 grade's flat ambient (1.02)
	# and pale fog washed every value into one grey-blue — CP2077
	# keeps deep contrast in the near/mid field (dark masses vs lit
	# accents) and melts only the distance into COLOURED haze. So:
	# darker zenith, tighter warm horizon band, ambient cut to ~0.6
	# with a stronger directional moon for value separation, fog
	# colour deepened to teal and its sky-affect lowered so distant
	# silhouettes stay darker than the sky behind them.
	sky_mat.sky_top_color = Color(0.07, 0.12, 0.18)
	sky_mat.sky_horizon_color = Color(0.46, 0.42, 0.33)
	sky_mat.sky_curve = 0.06
	sky_mat.ground_bottom_color = Color(0.02, 0.025, 0.035)
	sky_mat.ground_horizon_color = Color(0.10, 0.13, 0.15)
	sky_mat.ground_curve = 0.08
	sky_mat.sun_angle_max = 30.0
	sky_mat.sun_curve = 0.02
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.36, 0.44, 0.52)
	env.ambient_light_energy = 0.68
	env.fog_enabled = true
	# Deep teal aerial perspective: distance melts into dark haze,
	# not into milk.
	env.fog_light_color = Color(0.15, 0.21, 0.26)
	env.fog_density = 0.0082
	env.fog_sky_affect = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.06
	env.adjustment_contrast = 1.14
	env.adjustment_saturation = 1.12
	# v5.5 (diff #8): glow DOES work on the Compatibility pipeline
	# (verified by pixel diff + eyeball, tests/v55_glow.gd) — neon
	# finally bleeds light. Kept modest: the device renders brights
	# hotter than llvmpipe, and fullscreen passes cost fps.
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.08
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-42, 35, 0)
	moon.light_color = Color(0.55, 0.68, 0.85)
	moon.light_energy = 0.78
	# v5.9: shadows ON — the single biggest "flat retro" cue was
	# their absence (buildings/props floated on unshaded ground).
	# Kept local: a 90 m shadow camera around the view keeps the
	# atlas resolution usable in Compatibility and the cost flat;
	# the v5.5 grade (fog / ambient / colour) is untouched.
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 90.0
	moon.shadow_bias = 0.06
	moon.shadow_normal_bias = 1.2
	moon.shadow_blur = 1.2
	add_child(moon)

func _load_font() -> Font:
	if ResourceLoader.exists("res://assets/jpfont.ttf"):
		var f: Font = load("res://assets/jpfont.ttf") as Font
		if f != null:
			return f
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Hiragino Sans", "Noto Sans JP", "Yu Gothic", "Meiryo", "sans-serif"])
	return sf

func _spawn_cars() -> void:
	# v4 spots sit on the authored roads: ring east/west edges, the SW
	# diagonal avenue, the N-S main street, and the S2 street.
	var parked_spots: Array = [
		[Vector3(153, 0.55, 30), PI], [Vector3(-153, 0.55, -40), 0.0],
		[Vector3(-150, 0.55, 142), -0.89], [Vector3(4.5, 0.55, 126), 0.0],
		[Vector3(-80, 0.55, 57), PI * 0.5],
	]
	# v3 (P1): the first parked car and one traffic colour are the
	# Cyberpunk-yellow fingerprint; the rest stay varied but muted.
	var colors: Array[Color] = [Color(0.96, 0.84, 0.08), Color(0.1, 0.5, 0.9), Color(0.75, 0.12, 0.3), Color(0.4, 0.15, 0.85), Color(0.1, 0.8, 0.5)]
	for i in range(parked_spots.size()):
		var car: CharacterBody3D = CarScript.new()
		car.add_to_group("cars")
		add_child(car)
		car.call("build", colors[i])
		car.global_position = parked_spots[i][0]
		car.set("heading", parked_spots[i][1])
		car.rotation.y = parked_spots[i][1]
		_cars.append(car)
	# v4 street traffic follows the ring-road tours from the layout.
	var loops: Array = city.get("traffic_loops")
	for i in range(8):
		var car2: CharacterBody3D = CarScript.new()
		car2.add_to_group("cars")
		add_child(car2)
		car2.call("build", colors[i % colors.size()] * Color(0.7, 0.7, 0.75))
		var lp: Array = loops[i % loops.size()]
		car2.call("set_traffic_path", lp, 11.0 + float(i % 3) * 2.0)
		# Stagger the cars around the tour instead of stacking them.
		var start_idx: int = (i * 7) % lp.size()
		car2.global_position = (lp[start_idx] as Vector3) + Vector3(0, 0.55, 0)
		car2.set("_wp", (start_idx + 1) % lp.size())
		_cars.append(car2)
	# Skyway traffic: cars tour the elevated deck both ways (kept out
	# of _cars so street-level interactions never see them).
	var deck: Array = city.get("deck_loop")
	for i in range(6):
		var car3: CharacterBody3D = CarScript.new()
		car3.add_to_group("deck_traffic")
		add_child(car3)
		car3.call("build", colors[(i + 2) % colors.size()])
		car3.set("_base_y", 10.6)
		# v5.7: set() with a whole Array silently failed on the typed
		# _loop (deck cars NEVER drove — loop size 0). set_traffic_path
		# appends element-wise and sets cruise speed.
		car3.call("set_traffic_path", deck, 13.0 + float(i % 3) * 2.5)
		var didx: int = (i * 5) % deck.size()
		car3.global_position = (deck[didx] as Vector3) + Vector3(0, 10.6, 0)
		car3.set("_wp", (didx + 1) % deck.size())
		_deck_cars.append(car3)

func _pick_crowd_block(blocks: Array) -> Dictionary:
	# Bias toward the city centre so downtown feels crowded.
	for attempt in range(4):
		var blk: Dictionary = blocks[_rng.randi() % blocks.size()]
		var c: Vector3 = blk["center"]
		var d: float = Vector2(c.x, c.z).length()
		if _rng.randf() < clampf(1.3 - d / 330.0, 0.15, 1.0):
			return blk
	return blocks[_rng.randi() % blocks.size()]

func _spawn_npcs() -> void:
	var blocks: Array = city.get("sidewalk_blocks")
	var cast: Array = People.PEDESTRIANS
	for i in range(80):
		var npc: Node3D = NpcScript.new()
		npc.add_to_group("npcs")
		add_child(npc)
		var blk: Dictionary = _pick_crowd_block(blocks)
		npc.call("setup", blk["center"], float(blk["half"]), cast[i % cast.size()], _rng, false)
		_npcs.append(npc)
	for i in range(40):
		var npc2: Node3D = NpcScript.new()
		npc2.add_to_group("npcs")
		add_child(npc2)
		var blk2: Dictionary = _pick_crowd_block(blocks)
		npc2.call("setup", blk2["center"], float(blk2["half"]), cast[(i + 3) % cast.size()], _rng, true)
		_npcs.append(npc2)

func _spawn_drones() -> void:
	for i in range(4):
		var d: Node3D = DroneScript.new()
		d.add_to_group("drones")
		add_child(d)
		d.set("target", player)
		_drones.append(d)

func _build_marker() -> void:
	_marker = Node3D.new()
	add_child(_marker)
	var cyl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.7
	cm.bottom_radius = 0.7
	cm.height = 9.0
	cyl.mesh = cm
	cyl.position.y = 4.5
	_marker_mat = StandardMaterial3D.new()
	_marker_mat.albedo_color = Color(1, 0.85, 0.15, 0.5)
	_marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker_mat.emission_enabled = true
	_marker_mat.emission = Color(1, 0.85, 0.15)
	_marker_mat.emission_energy_multiplier = 1.6
	_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cyl.material_override = _marker_mat
	_marker.add_child(cyl)
	var lab := Label3D.new()
	lab.text = "▼"
	lab.font = game_font
	lab.font_size = 96
	lab.pixel_size = 0.02
	lab.modulate = Color(1, 0.9, 0.3)
	lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lab.position.y = 10.2
	_marker.add_child(lab)
	_marker.visible = false
	_chip = Node3D.new()
	var chip_box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.4, 0.08, 0.3)
	chip_box.mesh = bm
	var cmat := StandardMaterial3D.new()
	cmat.albedo_color = Color(0.2, 1, 0.5)
	cmat.emission_enabled = true
	cmat.emission = Color(0.2, 1, 0.5)
	cmat.emission_energy_multiplier = 3.0
	chip_box.material_override = cmat
	_chip.add_child(chip_box)
	_chip.position.y = 1.0
	_chip.visible = false
	add_child(_chip)
	_gate_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 5.6
	tm.outer_radius = 6.4
	_gate_ring.mesh = tm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(1, 0.6, 0.1)
	gmat.emission_enabled = true
	gmat.emission = Color(1, 0.6, 0.1)
	gmat.emission_energy_multiplier = 2.4
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_gate_ring.material_override = gmat
	_gate_ring.visible = false
	add_child(_gate_ring)

# --- Flow ---

func on_panel_button() -> void:
	if panel_mode == "start":
		start_game()

func start_game() -> void:
	started = true
	panel_mode = "started"
	hud.call("hide_panel")
	player.set("input_enabled", true)
	hud.call("show_center_message", "JOBキオスクで仕事を受けよう")
	_try_fullscreen_landscape()

func request_mouse_capture() -> void:
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _try_fullscreen_landscape() -> void:
	if not OS.has_feature("web"):
		return
	var js: Object = Engine.get_singleton("JavaScriptBridge")
	if js != null:
		js.call("eval", "try{var e=document.documentElement;if(e.requestFullscreen){e.requestFullscreen();}if(screen.orientation&&screen.orientation.lock){screen.orientation.lock('landscape').catch(function(){});}}catch(err){}")

# --- Interaction ---

func interact() -> void:
	if not started or bool(player.get("dead")):
		return
	if in_shop >= 0:
		_shop_interact()
		return
	if player.get("in_car") != null:
		_exit_car()
		return
	var p: Vector3 = player.global_position
	var car: Node3D = _nearest_parked_car(p, 3.6)
	if car != null:
		_enter_car(car)
		return
	var shop_i: int = _nearest_shop_door(p, 2.8)
	if shop_i >= 0:
		_enter_shop(shop_i)
		return
	if mission == "" and _nearest(city.get("poi_kiosks"), p, 3.0) != null:
		_assign_mission()
		return
	if mission == "hack" and mission_stage == "at_terminal" and _hack_channel < 0.0:
		var t: Variant = _nearest(city.get("poi_terminals"), p, 3.2)
		if t != null and (t as Vector3).distance_to(mission_target_pos) < 1.0:
			_hack_channel = 0.0
			hud.call("show_center_message", "ハッキング中… その場を離れるな")

func _nearest(list: Array, p: Vector3, max_d: float) -> Variant:
	var best: Variant = null
	var bd: float = max_d
	for v in list:
		var d: float = (v as Vector3).distance_to(p)
		if d < bd:
			bd = d
			best = v
	return best

func _nearest_parked_car(p: Vector3, max_d: float) -> Node3D:
	var best: Node3D = null
	var bd: float = max_d
	for c in _cars:
		if String(c.get("mode")) == "parked":
			var d: float = (c as Node3D).global_position.distance_to(p)
			if d < bd:
				bd = d
				best = c
	return best

func _enter_car(car: Node3D) -> void:
	player.set("in_car", car)
	car.call("set_driven", true)
	player.visible = false
	for c in player.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", true)
	hud.call("toast", "ホバーカーに乗車（FLYボタン / Rキーで飛行）")

func _exit_car() -> void:
	var car: Node3D = player.get("in_car")
	if car == null:
		return
	car.call("set_driven", false)
	player.set("in_car", null)
	var right := Vector3(cos(float(car.get("heading"))), 0, -sin(float(car.get("heading"))))
	player.global_position = car.global_position + right * 2.4 + Vector3(0, 0.4, 0)
	player.visible = true
	for c in player.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", false)
	player.call("make_camera_current")
	touch_drive = Vector2.ZERO

func toggle_flight() -> void:
	var car: Node3D = player.get("in_car")
	if car == null:
		return
	var on: bool = bool(car.call("toggle_flight"))
	if on:
		hud.call("toast", "飛行モード — GAS/BRKで前後、左スティック上下で昇降")
	else:
		hud.call("toast", "飛行モードOFF")

func on_car_landed() -> void:
	hud.call("toast", "着陸")

func apply_fall_damage(dmg: float) -> void:
	if bool(player.get("dead")):
		return
	var hp: float = float(player.get("hp")) - dmg
	player.set("hp", hp)
	hud.call("toast", "落下ダメージ -%d" % int(dmg))
	if hp <= 0.0:
		_die()

# --- Shops & items (v5.4) ---

func _ensure_item_defs() -> void:
	if not item_defs.is_empty():
		return
	for s in city.get("shop_sites"):
		for b in s["buys"]:
			item_defs[String(b["id"])] = b

func _nearest_shop_door(p: Vector3, max_d: float) -> int:
	var sites: Array = city.get("shop_sites")
	var best: int = -1
	var bd: float = max_d
	for i in range(sites.size()):
		var d: float = (sites[i]["door_pos"] as Vector3).distance_to(p)
		if d < bd:
			bd = d
			best = i
	return best

func _enter_shop(i: int) -> void:
	in_shop = i
	var s: Dictionary = (city.get("shop_sites") as Array)[i]
	player.global_position = s["enter_pos"]
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	player.call("set_camera_dist", float(s.get("cam_dist", 1.7)))
	if String(s["kind"]) == "casino":
		hud.call("toast", "CASINO NEON PEARL — まずキャッシャーでチップを買おう")
	else:
		hud.call("toast", "%s — カウンターで買い物、出口で出る" % String(s["name"]))

func _exit_shop() -> void:
	var s: Dictionary = (city.get("shop_sites") as Array)[in_shop]
	in_shop = -1
	player.global_position = s["door_pos"]
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	player.call("set_camera_dist", 4.6)

func _shop_interact() -> void:
	var s: Dictionary = (city.get("shop_sites") as Array)[in_shop]
	if String(s["kind"]) == "casino":
		if casino_ui != null:
			casino_ui.call("handle_interact")
		return
	var p: Vector3 = player.global_position
	if p.distance_to(s["exit_pos"]) < 2.4:
		_exit_shop()
		return
	for b in s["buys"]:
		if p.distance_to(b["pos"]) < 2.2:
			_buy(b)
			return

func _buy(b: Dictionary) -> void:
	_ensure_item_defs()
	var price: int = int(b["price"])
	var id: String = String(b["id"])
	if money < price:
		hud.call("toast", "€$が足りない（%s €$%d）" % [String(b["label"]), price])
		return
	money -= price
	items[id] = int(items.get(id, 0)) + 1
	_sync_item_hud()
	hud.call("toast", "%s を購入（所持 ×%d）— H / ITEMで使用" % [String(b["label"]), int(items[id])])

func use_item() -> void:
	if not started or bool(player.get("dead")) or in_shop >= 0:
		return
	_ensure_item_defs()
	var hp: float = float(player.get("hp"))
	if hp >= 100.0:
		hud.call("toast", "HPは満タンだ")
		return
	var best_id: String = ""
	var best_heal: float = 0.0
	for id in items:
		if int(items[id]) > 0 and item_defs.has(id):
			var h: float = float(item_defs[id]["heal"])
			if h > best_heal:
				best_heal = h
				best_id = id
	if best_id == "":
		hud.call("toast", "回復アイテムを持っていない — 薬局や店で買える")
		return
	items[best_id] = int(items[best_id]) - 1
	player.set("hp", minf(100.0, hp + best_heal))
	_sync_item_hud()
	hud.call("toast", "%s を使用 — HP +%.0f" % [String(item_defs[best_id]["label"]), best_heal])

func _sync_item_hud() -> void:
	var n: int = 0
	for id in items:
		n += int(items[id])
	hud.call("set_item_count", n)

# --- Missions ---

func _assign_mission() -> void:
	var kinds: Array[String] = ["pickup", "hack", "race", "courier", "errand", "rooftop"]
	mission = kinds[_rng.randi() % kinds.size()]
	_hack_channel = -1.0
	if mission == "pickup":
		mission_stage = "go"
		var spots: Array = city.get("poi_pickups")
		mission_target_pos = spots[_rng.randi() % spots.size()]
		_chip.global_position = (mission_target_pos as Vector3) + Vector3(0, 0.4, 0)
		_chip.visible = true
		hud.call("show_center_message", "仕事: データ回収 — チップを拾え")
	elif mission == "hack":
		mission_stage = "at_terminal"
		var terms: Array = city.get("poi_terminals")
		mission_target_pos = terms[_rng.randi() % terms.size()]
		hud.call("show_center_message", "仕事: ハッキング — 端末へ向かえ")
	elif mission == "race":
		mission_stage = "gates"
		_race_gates.clear()
		var cur: Vector3 = player.global_position
		var used: Array[Vector3] = []
		# v4: gates come from vetted road points in the layout, each
		# the nearest unused one at least ~55 m from the previous.
		var rp: Array = city.get("race_points")
		for i in range(5):
			var best := Vector3.ZERO
			var bd: float = 1e9
			for cand_v in rp:
				var cand: Vector3 = cand_v
				if used.has(cand) or cand.distance_to(cur) < 55.0:
					continue
				var d: float = cand.distance_to(cur)
				if d < bd:
					bd = d
					best = cand
			if bd >= 1e9:  # ran out of distant points: take any unused
				for cand_v in rp:
					if not used.has(cand_v):
						best = cand_v
						break
			used.append(best)
			_race_gates.append(best)
			cur = best
		_race_idx = 0
		_race_t = 90.0
		mission_target_pos = _race_gates[0]
		_gate_ring.visible = true
		hud.call("show_center_message", "仕事: レース — 車でゲートをくぐれ")
	elif mission == "courier":
		mission_stage = "to_counter"
		var sites: Array = city.get("shop_sites")
		_shop_target = _rng.randi() % sites.size()
		mission_target_pos = sites[_shop_target]["door_pos"]
		hud.call("show_center_message", "仕事: 配達 — %sで荷物を受け取れ" % String(sites[_shop_target]["name"]))
	elif mission == "errand":
		mission_stage = "get"
		var sites2: Array = city.get("shop_sites")
		_shop_target = 0
		for i in range(sites2.size()):
			if String(sites2[i]["kind"]) == "pharmacy":
				_shop_target = i
		mission_target_pos = sites2[_shop_target]["door_pos"]
		hud.call("show_center_message", "仕事: 買い物代行 — 薬局で医療キットを買って届けろ")
	elif mission == "rooftop":
		mission_stage = "go"
		var spots: Array = city.get("poi_pickups")
		var tops: Array = []
		for sp in spots:
			if (sp as Vector3).y > 3.0:
				tops.append(sp)
		if tops.is_empty():
			tops = spots
		mission_target_pos = tops[_rng.randi() % tops.size()]
		hud.call("show_center_message", "仕事: 屋上配達 — 屋上の目印へ荷物を運べ")

func _complete_mission(reward: int, label: String) -> void:
	money += reward
	hud.call("toast", "%s 完了  +€$%d" % [label, reward])
	hud.call("show_center_message", "仕事完了")
	mission = ""
	mission_stage = ""
	_shop_target = -1
	mission_target_pos = null
	_marker.visible = false
	_chip.visible = false
	_gate_ring.visible = false
	_hack_channel = -1.0

func add_wanted(n: int) -> void:
	var before: int = wanted
	wanted = clampi(wanted + n, 0, 3)
	if wanted > before:
		hud.call("toast", "警戒レベル上昇 ★%d" % wanted)
		_escape_t = 0.0

func _die() -> void:
	if casino_ui != null:
		casino_ui.call("force_leave")
	in_shop = -1
	player.call("set_camera_dist", 4.6)
	var fee: int = mini(50, money)
	money -= fee
	wanted = 0
	player.set("hp", 100.0)
	if player.get("in_car") != null:
		_exit_car()
	player.global_position = CLINIC_POS + Vector3(0, 0.5, 0)
	hud.call("show_center_message", "クローン再生… 治療費 €$%d" % fee)

func _rescue_fallout() -> void:
	var car: Node3D = player.get("in_car")
	if car != null:
		car.global_position = CLINIC_POS + Vector3(0, 1.2, 6)
		car.rotation = Vector3.ZERO
		if car is CharacterBody3D:
			(car as CharacterBody3D).velocity = Vector3.ZERO
		if bool(car.get("flying")) and car.has_method("toggle_flight"):
			car.call("toggle_flight")
	player.global_position = CLINIC_POS + Vector3(0, 0.5, 0)
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO
	hud.call("toast", "信号ロスト… クリニック前に再配置")

# --- Per-frame ---

func _process(delta: float) -> void:
	_clock_min += delta * 2.0
	if _clock_min >= 1440.0:
		_clock_min -= 1440.0
	var hh: int = int(_clock_min) / 60
	var mm: int = int(_clock_min) % 60
	hud.call("set_stats", float(player.get("hp")), money, wanted, "%02d:%02d" % [hh, mm])
	_hit_cd = maxf(0.0, _hit_cd - delta)
	if not started:
		return
	# Safety net: if anything ever slips out of the world (a seam,
	# a physics tunnelling frame), put the player back at the
	# clinic instead of falling forever (his iPhone photo, v4.1).
	if player.global_position.y < -8.0 and in_shop < 0:
		_rescue_fallout()
		return
	_update_mission(delta)
	_update_wanted(delta)
	_update_prompts()
	if casino_ui != null and in_shop >= 0:
		var cs: Dictionary = (city.get("shop_sites") as Array)[in_shop]
		if String(cs["kind"]) == "casino":
			casino_ui.call("tick", delta)
	# Marker pulse.
	if mission_target_pos != null:
		_marker.visible = true
		_marker.global_position = mission_target_pos
		_marker.position.y = 0.3 + sin(Time.get_ticks_msec() * 0.004) * 0.15
		_gate_ring.global_position = (mission_target_pos as Vector3) + Vector3(0, 3.2, 0)
		_chip.rotation.y += delta * 2.0
	else:
		_marker.visible = false
		_gate_ring.visible = false

func _update_mission(delta: float) -> void:
	if mission == "":
		hud.call("set_mission", "フリー走行中 — JOBキオスクで仕事を受けよう")
		return
	var p: Vector3 = player.global_position
	var target: Vector3 = mission_target_pos
	var dist: float = p.distance_to(target)
	if mission == "pickup":
		if mission_stage == "go":
			hud.call("set_mission", "仕事: データ回収 — チップまで %dm" % int(dist))
			if dist < 2.8:
				mission_stage = "deliver"
				_chip.visible = false
				var kiosks: Array = city.get("poi_kiosks")
				mission_target_pos = kiosks[_rng.randi() % kiosks.size()]
				hud.call("show_center_message", "チップ回収 — キオスクへ届けろ")
		else:
			hud.call("set_mission", "仕事: データ回収 — 配達先まで %dm" % int(dist))
			if dist < 3.2:
				_complete_mission(120, "データ回収")
	elif mission == "hack":
		if _hack_channel >= 0.0:
			_hack_channel += delta
			hud.call("set_mission", "ハッキング中… %.1f / 3.0 秒" % _hack_channel)
			if p.distance_to(target) > 4.5:
				_hack_channel = -1.0
				hud.call("toast", "ハッキング中断")
			elif _hack_channel >= 3.0:
				_complete_mission(200, "ハッキング")
				add_wanted(1)
		else:
			hud.call("set_mission", "仕事: ハッキング — 端末まで %dm（着いたら ACT）" % int(dist))
	elif mission == "courier":
		var s: Dictionary = (city.get("shop_sites") as Array)[_shop_target]
		if mission_stage == "to_counter":
			mission_target_pos = s["counter_pos"] if in_shop == _shop_target else s["door_pos"]
			var d2: float = p.distance_to(mission_target_pos)
			hud.call("set_mission", "仕事: 配達 — %sのカウンターまで %dm" % [String(s["name"]), int(d2)])
			if in_shop == _shop_target and d2 < 2.6:
				mission_stage = "deliver"
				var spots: Array = city.get("poi_pickups")
				mission_target_pos = spots[_rng.randi() % spots.size()]
				hud.call("show_center_message", "荷物を受け取った — 配達先へ届けろ")
		else:
			hud.call("set_mission", "仕事: 配達 — 配達先まで %dm" % int(dist))
			if dist < 3.2:
				_complete_mission(150, "配達")
	elif mission == "errand":
		if mission_stage == "get":
			if int(items.get("medkit", 0)) > 0:
				mission_stage = "deliver"
				var kiosks: Array = city.get("poi_kiosks")
				mission_target_pos = kiosks[_rng.randi() % kiosks.size()]
				hud.call("show_center_message", "医療キットを持っている — キオスクへ届けろ")
			else:
				var s3: Dictionary = (city.get("shop_sites") as Array)[_shop_target]
				mission_target_pos = s3["counter_pos"] if in_shop == _shop_target else s3["door_pos"]
				var d3: float = p.distance_to(mission_target_pos)
				hud.call("set_mission", "仕事: 買い物代行 — 薬局で医療キットを買え（あと %dm）" % int(d3))
		else:
			hud.call("set_mission", "仕事: 買い物代行 — キオスクまで %dm" % int(dist))
			if dist < 3.2:
				items["medkit"] = int(items.get("medkit", 0)) - 1
				_sync_item_hud()
				_complete_mission(260, "買い物代行")
	elif mission == "rooftop":
		hud.call("set_mission", "仕事: 屋上配達 — 屋上の目印まで %dm" % int(dist))
		if dist < 3.4:
			_complete_mission(180, "屋上配達")
	elif mission == "race":
		_race_t -= delta
		hud.call("set_mission", "仕事: レース — ゲート %d/5 まで %dm / 残り %.0f 秒" % [_race_idx + 1, int(dist), maxf(_race_t, 0.0)])
		if _race_t <= 0.0:
			hud.call("toast", "レース失敗…")
			mission = ""
			mission_stage = ""
			mission_target_pos = null
			_gate_ring.visible = false
			return
		if dist < 9.0:
			if player.get("in_car") != null:
				_race_idx += 1
				if _race_idx >= _race_gates.size():
					var bonus: int = int(_race_t) * 2
					_complete_mission(180 + bonus, "レース")
				else:
					mission_target_pos = _race_gates[_race_idx]
					hud.call("toast", "ゲート通過 %d/5" % _race_idx)
			else:
				hud.call("set_mission", "仕事: レース — ゲートは車に乗ってくぐれ")

func _update_wanted(delta: float) -> void:
	# Drive drones.
	var want_count: int = [0, 1, 2, 4][wanted]
	for i in range(_drones.size()):
		var d: Node3D = _drones[i]
		var on: bool = i < want_count
		d.set("active", on)
		d.visible = on
		if on and not _drone_was[i]:
			# Fresh spawn: appear at a distance, never on top of the player.
			var ang: float = _rng.randf() * TAU
			d.global_position = player.global_position + Vector3(cos(ang) * 45.0, 13.0, sin(ang) * 45.0)
		_drone_was[i] = on
		_drone_cd[i] = maxf(0.0, _drone_cd[i] - delta)
		if on and _drone_cd[i] <= 0.0 and d.global_position.distance_to(player.global_position) < 2.6:
			_drone_cd[i] = 1.2
			var hp: float = float(player.get("hp")) - 8.0
			player.set("hp", hp)
			if hp <= 0.0:
				_die()
				return
	# Escape logic.
	if wanted > 0:
		var far: bool = true
		for i in range(want_count):
			if (_drones[i] as Node3D).global_position.distance_to(player.global_position) < 90.0:
				far = false
		if far:
			_escape_t += delta
			if _escape_t > 8.0:
				wanted -= 1
				_escape_t = 0.0
				hud.call("toast", "捜索を撒いた ★%d" % wanted)
		else:
			_escape_t = 0.0
	# Car hits pedestrians.
	if player.get("in_car") != null:
		var car: Node3D = player.get("in_car")
		if absf(float(car.get("speed"))) > 6.0:
			for npc in _npcs:
				if not bool(npc.call("is_down")) and (npc as Node3D).global_position.distance_to(car.global_position) < 2.3:
					npc.call("hit_by_car")
					if _hit_cd <= 0.0:
						_hit_cd = 5.0
						add_wanted(1)
						hud.call("toast", "歩行者と接触！")

func _update_prompts() -> void:
	var text: String = ""
	if player.get("in_car") != null:
		text = "F / ACT: 降車"
	else:
		var p: Vector3 = player.global_position
		if in_shop >= 0:
			var s2: Dictionary = (city.get("shop_sites") as Array)[in_shop]
			if String(s2["kind"]) == "casino":
				text = String(casino_ui.call("hint_text")) if casino_ui != null else ""
			elif p.distance_to(s2["exit_pos"]) < 2.4:
				text = "F / ACT: 店を出る"
			else:
				for b in s2["buys"]:
					if p.distance_to(b["pos"]) < 2.2:
						text = "F / ACT: %sを買う €$%d" % [String(b["label"]), int(b["price"])]
						break
		elif _nearest_parked_car(p, 3.6) != null:
			text = "F / ACT: 乗車"
		elif _nearest_shop_door(p, 2.8) >= 0:
			var si: int = _nearest_shop_door(p, 2.8)
			text = "F / ACT: %sに入る" % String((city.get("shop_sites") as Array)[si]["name"])
		elif mission == "" and _nearest(city.get("poi_kiosks"), p, 3.0) != null:
			text = "F / ACT: 仕事を受ける"
		elif mission == "hack" and _hack_channel < 0.0 and _nearest(city.get("poi_terminals"), p, 3.2) != null:
			text = "F / ACT: ハッキング開始"
	hud.call("set_prompt", text)
