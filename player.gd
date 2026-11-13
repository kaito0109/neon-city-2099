extends CharacterBody3D
## Third-person runner: walk / dash / jump on foot, plus the camera rig.
## When driving, the car owns movement and this body just rides along hidden.

var hp: float = 100.0
var dead: bool = false
var yaw: float = 0.0
var pitch: float = -0.18
var in_car: Node3D = null

var touch_move: Vector2 = Vector2.ZERO
var touch_dashing: bool = false
var input_enabled: bool = false

var _model: Node3D
var _anim: AnimationPlayer
var _pivot: Node3D
var _spring: SpringArm3D
var _camera: Camera3D
var _model_yaw: float = 0.0
var _jump_queued: bool = false
var _cur_clip: String = ""
var _air_jumps: int = 0
var _fall_peak: float = 0.0
var _was_floor: bool = true
var _climbing: bool = false
var _wall_normal: Vector3 = Vector3.ZERO
var _roll_t: float = 0.0
var _flip_t: float = 0.0
var _air_time: float = 0.0

const WALK_SPEED: float = 5.4
const DASH_SPEED: float = 9.2
const GRAVITY: float = 22.0

func _ready() -> void:
	add_to_group("player")
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.7
	shape.shape = cap
	shape.position.y = 0.85
	add_child(shape)
	_pivot = Node3D.new()
	_pivot.position.y = 1.62
	add_child(_pivot)
	# Soft fill light so the character (and nearby pedestrians) stay
	# readable against the dark streets.
	var fill := OmniLight3D.new()
	fill.position.y = 1.7
	fill.omni_range = 5.5
	fill.light_energy = 0.55
	fill.light_color = Color(0.72, 0.84, 1.0)
	fill.shadow_enabled = false
	add_child(fill)
	_spring = SpringArm3D.new()
	_spring.spring_length = 4.6
	_spring.margin = 0.35
	_pivot.add_child(_spring)
	_camera = Camera3D.new()
	_camera.fov = 68.0
	_spring.add_child(_camera)
	_build_model()

func _build_model() -> void:
	_model = Node3D.new()
	add_child(_model)
	# Quaternius "Punk" (CC0) — mohawk runner, full rig + clip set.
	var inst: Node3D = People.spawn("Punk")
	if inst != null:
		_model.add_child(inst)
		_anim = People.find_ap(inst)
		People.play(_anim, "Idle")
	else:
		# Fallback silhouette if the model cannot be loaded.
		var cap := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.3
		cm.height = 1.7
		cap.mesh = cm
		cap.position.y = 0.85
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.12, 0.13, 0.2)
		cap.material_override = m
		_model.add_child(cap)

func make_camera_current() -> void:
	if _camera != null:
		_camera.make_current()

func add_look_input(rel: Vector2) -> void:
	yaw -= rel.x * 0.0042
	pitch = clampf(pitch - rel.y * 0.0042, -1.1, 1.2)
	_apply_camera()

func _apply_camera() -> void:
	if _pivot != null:
		_pivot.rotation = Vector3(pitch, yaw, 0.0)

func queue_jump() -> void:
	_jump_queued = true

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or dead:
		return
	if in_car != null:
		# Desktop mouse look orbits the car camera while driving.
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var mm2 := event as InputEventMouseMotion
			in_car.call("add_car_look", mm2.relative / 0.0042 * 0.0026)
		# Driving keys: F exits (even mid-air — you fall), R toggles flight.
		if event is InputEventKey and event.pressed and not event.echo:
			var kk := event as InputEventKey
			var m: Node = get_tree().get_first_node_in_group("main")
			if m != null:
				if kk.keycode == KEY_F:
					m.call("interact")
				elif kk.keycode == KEY_R:
					m.call("toggle_flight")
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm := event as InputEventMouseMotion
		add_look_input(mm.relative / 0.0042 * 0.0026)
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			var main: Node = get_tree().get_first_node_in_group("main")
			if main != null:
				main.call("request_mouse_capture")
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_SPACE:
			queue_jump()
		elif k.keycode == KEY_F:
			var main2: Node = get_tree().get_first_node_in_group("main")
			if main2 != null:
				main2.call("interact")

func _ray_hit(from: Vector3, dir: Vector3, len: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * len)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)

func _wall_dir(wish: Vector3) -> Vector3:
	if wish.length() > 0.2:
		return wish.normalized()
	return Vector3(sin(_model_yaw), 0, cos(_model_yaw))

func _try_start_climb(wish: Vector3) -> bool:
	var dir: Vector3 = _wall_dir(wish)
	var hit: Dictionary = _ray_hit(global_position + Vector3(0, 1.15, 0), dir, 0.85)
	if hit.is_empty():
		return false
	if not (hit["collider"] is StaticBody3D):
		return false
	var n: Vector3 = hit["normal"]
	if absf(n.y) > 0.3:
		return false
	_climbing = true
	_wall_normal = n
	velocity.y = 0.0
	return true

func _maybe_autograb(wish: Vector3) -> void:
	# Falling past a wall while pushing into it: grab on (parkour flow).
	if velocity.y > -1.0 or wish.length() < 0.3:
		return
	var dir: Vector3 = wish.normalized()
	var hit: Dictionary = _ray_hit(global_position + Vector3(0, 1.15, 0), dir, 0.85)
	if hit.is_empty():
		return
	if not (hit["collider"] is StaticBody3D):
		return
	var n: Vector3 = hit["normal"]
	if absf(n.y) > 0.3 or wish.dot(n) > -0.55:
		return
	_climbing = true
	_wall_normal = n
	velocity.y = 0.0

func _on_land() -> void:
	if _fall_peak > 13.0:
		_roll_t = 0.5
		_cur_clip = ""
	if _fall_peak > 16.0:
		var dmg: float = minf(55.0, (_fall_peak - 16.0) * 2.4)
		var main: Node = get_tree().get_first_node_in_group("main")
		if main != null:
			main.call("apply_fall_damage", dmg)
	_fall_peak = 0.0

func _do_climb(wish: Vector3) -> void:
	var n: Vector3 = _wall_normal
	var into: Vector3 = -n
	var chest: Dictionary = _ray_hit(global_position + Vector3(0, 1.15, 0), into, 0.85)
	if not chest.is_empty() and not (chest["collider"] is StaticBody3D):
		chest = _ray_hit(global_position + Vector3(0, 1.15, 0), into, 1.7)
	var head: Dictionary = _ray_hit(global_position + Vector3(0, 1.55, 0), into, 0.85)
	if not head.is_empty() and not (head["collider"] is StaticBody3D):
		head = _ray_hit(global_position + Vector3(0, 1.55, 0), into, 1.7)
	if head.is_empty():
		# Ledge within reach: mantle up onto the roof. Checked FIRST —
		# near the top the chest ray can also miss (setback crowns),
		# and treating that as "wall ended" stalled the climb.
		_climbing = false
		velocity = into * 3.4 + Vector3(0, 8.6, 0)
		_air_jumps = 0
		move_and_slide()
		return
	if chest.is_empty():
		_climbing = false
		velocity = into * 1.5 + Vector3(0, 1.0, 0)
		move_and_slide()
		return
	_wall_normal = chest["normal"]
	n = _wall_normal
	into = -n
	if _jump_queued:
		# Wall jump.
		_climbing = false
		velocity = n * 5.6 + Vector3(0, 7.6, 0)
		_air_jumps = 0
		_model_yaw = atan2(n.x, n.z)
		move_and_slide()
		return
	if wish.dot(n) > 0.45:
		_climbing = false
		velocity = n * 1.6
		move_and_slide()
		return
	velocity = Vector3(0, 3.4, 0) + into * 1.1
	_model_yaw = atan2(into.x, into.z)
	move_and_slide()

func _physics_process(delta: float) -> void:
	if in_car != null:
		global_position = in_car.global_position + Vector3(0, 1.2, 0)
		return
	if not input_enabled or dead:
		velocity = Vector3.ZERO
		return
	_apply_camera()
	var iv := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		iv.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		iv.x += 1.0
	if Input.is_key_pressed(KEY_W):
		iv.y += 1.0
	if Input.is_key_pressed(KEY_S):
		iv.y -= 1.0
	if touch_move.length() > 0.08:
		iv = Vector2(touch_move.x, -touch_move.y)
	if iv.length() > 1.0:
		iv = iv.normalized()
	var dashing: bool = Input.is_key_pressed(KEY_SHIFT) or touch_dashing
	var speed: float = DASH_SPEED if dashing and iv.length() > 0.05 else WALK_SPEED
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var wish: Vector3 = (right * iv.x + fwd * iv.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	var on_floor: bool = is_on_floor()
	if on_floor and not _was_floor:
		_on_land()
	_was_floor = on_floor
	if _roll_t > 0.0:
		_roll_t -= delta
	if _climbing:
		_do_climb(wish)
		_jump_queued = false
		_update_anim(delta, wish, on_floor)
		return
	velocity.x = wish.x * speed * minf(1.0, iv.length() + 0.001)
	velocity.z = wish.z * speed * minf(1.0, iv.length() + 0.001)
	if on_floor:
		_air_jumps = 0
		_fall_peak = 0.0
		_air_time = 0.0
		velocity.y = -0.5
		if _jump_queued and _try_start_climb(wish):
			pass  # grabbed the wall instead of jumping
		elif _jump_queued or Input.is_key_pressed(KEY_SPACE):
			velocity.y = 7.0
	else:
		velocity.y -= GRAVITY * delta
		_air_time += delta
		_fall_peak = maxf(_fall_peak, -velocity.y)
		if _jump_queued:
			if not _try_start_climb(wish):
				if _air_jumps < 1:
					_air_jumps += 1
					velocity.y = 6.8
					_flip_t = 0.45
		else:
			_maybe_autograb(wish)
	_jump_queued = false
	move_and_slide()
	_update_anim(delta, wish, on_floor)

func _update_anim(delta: float, wish: Vector3, on_floor: bool) -> void:
	# Face movement direction; keep model under the camera yaw when idle.
	if wish.length() > 0.1 and not _climbing:
		var target: float = atan2(wish.x, wish.z)
		_model_yaw = lerp_angle(_model_yaw, target, clampf(delta * 10.0, 0.0, 1.0))
	if _model == null:
		return
	_model.rotation.y = _model_yaw
	if _flip_t > 0.0:
		_flip_t -= delta
		var p: float = 1.0 - clampf(_flip_t / 0.45, 0.0, 1.0)
		_model.rotation.x = -TAU * p
	else:
		var pitch_t: float = 0.0
		if not on_floor and not _climbing:
			# Falling pose: lean back with a slow leg cycle (the pack
			# has no dedicated fall clip).
			pitch_t = 0.34 if velocity.y < -2.5 else 0.1
		_model.rotation.x = lerpf(_model.rotation.x, pitch_t, clampf(delta * 8.0, 0.0, 1.0))
	if _anim == null:
		return
	var hspeed: float = Vector2(velocity.x, velocity.z).length()
	var want: String = "Idle"
	var spd: float = 1.0
	if _climbing:
		want = "Walk"
		spd = 1.15
	elif _roll_t > 0.0:
		want = "Roll"
		spd = 1.5
	elif not on_floor:
		want = "Run"
		spd = 0.35 if velocity.y < -2.5 else 0.8
	elif hspeed > 3.4:
		want = "Run"
		spd = clampf(hspeed / 5.6, 0.7, 1.6)
	elif hspeed > 0.4:
		want = "Walk"
		spd = clampf(hspeed / 2.2, 0.6, 1.8)
	if want != _cur_clip:
		_cur_clip = want
		People.play(_anim, want)
	_anim.speed_scale = spd
