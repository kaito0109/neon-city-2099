extends Node3D
## NEON CITY 2099 — orchestration: city, actors, missions, wanted, economy.

const CityScript := preload("res://city.gd")
const PlayerScript := preload("res://player.gd")
const CarScript := preload("res://car.gd")
const NpcScript := preload("res://npc.gd")
const DroneScript := preload("res://drone.gd")
const HudScript := preload("res://hud.gd")

var city: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var game_font: Font

var started: bool = false
var panel_mode: String = "start"
var money: int = 150
var wanted: int = 0
var touch_drive: Vector2 = Vector2.ZERO

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
var mission: String = ""           # "" | pickup | hack | race
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

const CLINIC_POS := Vector3(4, 0.6, 116)  # on the z=120 road, never inside a block building

func _ready() -> void:
	add_to_group("main")
	_rng.seed = 777
	_build_environment()
	game_font = _load_font()
	city = CityScript.new()
	add_child(city)
	city.call("build", game_font)
	player = PlayerScript.new()
	player.position = CLINIC_POS
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
	hud.call("build", game_font)
	hud.call("show_panel", "NEON CITY 2099",
		"2099年、ネオンの街ネオ・キバラ。運び屋として街を駆け、仕事をこなしてエディ（€$）を稼げ。\n\n移動: WASD / 左スティック　視点: マウス / 右ドラッグ\nダッシュ: Shift　ジャンプ: Space　調べる・乗る: F / ACT\n車の運転: 乗って W/S・A/D　全体マップ: M\n\nJOBキオスクで仕事を受けよう。ハッキングと事故は警察ドローンを呼ぶ。",
		"スタート")

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	# Graded night sky with a city-glow horizon (a flat BG colour read
	# as a black void above the rooftops).
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.016, 0.024, 0.075)
	sky_mat.sky_horizon_color = Color(0.14, 0.10, 0.27)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color(0.008, 0.008, 0.03)
	sky_mat.ground_horizon_color = Color(0.09, 0.065, 0.17)
	sky_mat.ground_curve = 0.08
	sky_mat.sun_angle_max = 30.0
	sky_mat.sun_curve = 0.02
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.38, 0.41, 0.62)
	env.ambient_light_energy = 0.88
	env.fog_enabled = true
	env.fog_light_color = Color(0.11, 0.09, 0.24)
	env.fog_density = 0.0038
	env.fog_sky_affect = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.13
	env.adjustment_contrast = 1.03
	env.adjustment_saturation = 1.12
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-52, 35, 0)
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = 0.85
	moon.shadow_enabled = false
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
	var parked_spots: Array = [
		[Vector3(64, 0.55, 12), 0.0], [Vector3(-56, 0.55, -104), PI * 0.5],
		[Vector3(128, 0.55, 64), PI], [Vector3(-122, 0.55, 176), -PI * 0.5],
		[Vector3(8, 0.55, -176), 0.0],
	]
	var colors: Array[Color] = [Color(0.75, 0.12, 0.3), Color(0.1, 0.5, 0.9), Color(0.95, 0.6, 0.1), Color(0.4, 0.15, 0.85), Color(0.1, 0.8, 0.5)]
	for i in range(parked_spots.size()):
		var car: CharacterBody3D = CarScript.new()
		car.add_to_group("cars")
		add_child(car)
		car.call("build", colors[i])
		car.global_position = parked_spots[i][0]
		car.set("heading", parked_spots[i][1])
		car.rotation.y = parked_spots[i][1]
		_cars.append(car)
	var blocks: Array = city.get("sidewalk_blocks")
	for i in range(8):
		var car2: CharacterBody3D = CarScript.new()
		car2.add_to_group("cars")
		add_child(car2)
		car2.call("build", colors[i % colors.size()] * Color(0.7, 0.7, 0.75))
		var blk: Dictionary = blocks[_rng.randi() % blocks.size()]
		car2.call("set_traffic", blk["center"], float(blk["half"]))
		_cars.append(car2)
	# Expressway traffic: cars shuttle along the elevated deck (kept
	# out of _cars so street-level interactions never see them).
	for i in range(6):
		var car3: CharacterBody3D = CarScript.new()
		add_child(car3)
		car3.call("build", colors[(i + 2) % colors.size()])
		var lane: float = -2.8 if i % 2 == 0 else 2.8
		var dir_z: float = 1.0 if i % 2 == 0 else -1.0
		var z0: float = -dir_z * (40.0 + float(i) * 42.0)
		car3.set("mode", "traffic")
		car3.set("_base_y", 10.05)
		car3.set("_loop", [Vector3(lane, 0, z0), Vector3(lane, 0, dir_z * 318.0), Vector3(lane, 0, -dir_z * 318.0)])
		car3.global_position = Vector3(lane, 10.05, z0)
		car3.set("_wp", 1)
		car3.set("speed", 13.0 + float(i % 3) * 2.5)
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
	if player.get("in_car") != null:
		_exit_car()
		return
	var p: Vector3 = player.global_position
	var car: Node3D = _nearest_parked_car(p, 3.6)
	if car != null:
		_enter_car(car)
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
	hud.call("toast", "ホバーカーに乗車")

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

# --- Missions ---

func _assign_mission() -> void:
	var kinds: Array[String] = ["pickup", "hack", "race"]
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
		for i in range(5):
			var best := Vector3.ZERO
			var bd: float = 1e9
			for k in range(14):
				var cand := Vector3(_rng.randi_range(-4, 4) * 60.0, 0, _rng.randi_range(-4, 4) * 60.0)
				if used.has(cand) or cand.distance_to(cur) < 70.0:
					continue
				var d: float = cand.distance_to(cur)
				if d < bd:
					bd = d
					best = cand
			used.append(best)
			_race_gates.append(best)
			cur = best
		_race_idx = 0
		_race_t = 90.0
		mission_target_pos = _race_gates[0]
		_gate_ring.visible = true
		hud.call("show_center_message", "仕事: レース — 車でゲートをくぐれ")

func _complete_mission(reward: int, label: String) -> void:
	money += reward
	hud.call("toast", "%s 完了  +€$%d" % [label, reward])
	hud.call("show_center_message", "仕事完了")
	mission = ""
	mission_stage = ""
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
	var fee: int = mini(50, money)
	money -= fee
	wanted = 0
	player.set("hp", 100.0)
	if player.get("in_car") != null:
		_exit_car()
	player.global_position = CLINIC_POS + Vector3(0, 0.5, 0)
	hud.call("show_center_message", "クローン再生… 治療費 €$%d" % fee)

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
	_update_mission(delta)
	_update_wanted(delta)
	_update_prompts()
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
		if _nearest_parked_car(p, 3.6) != null:
			text = "F / ACT: 乗車"
		elif mission == "" and _nearest(city.get("poi_kiosks"), p, 3.0) != null:
			text = "F / ACT: 仕事を受ける"
		elif mission == "hack" and _hack_channel < 0.0 and _nearest(city.get("poi_terminals"), p, 3.2) != null:
			text = "F / ACT: ハッキング開始"
	hud.call("set_prompt", text)
