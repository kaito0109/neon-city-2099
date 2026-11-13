extends CharacterBody3D
## Hover car: three modes — parked (enterable), driven (player), traffic (AI loop).

var mode: String = "parked"  # parked | driven | traffic
var heading: float = 0.0
var speed: float = 0.0
var flying: bool = false
var _roof_landed: bool = false
var _was_floor: bool = true
var _flight_airborne: bool = false
var _takeoff_t: float = 0.0
var body_color: Color = Color(0.7, 0.1, 0.3)
var _bob_t: float = 0.0
var _body: Node3D
var _cam_pivot: Node3D
var _cam_spring: SpringArm3D
var _camera: Camera3D
var _headlight: SpotLight3D
var _cone: MeshInstance3D
var _glow_light: OmniLight3D
var _loop: Array[Vector3] = []
var _wp: int = 0
var _base_y: float = 0.55

const MAX_SPEED: float = 29.0
const REV_SPEED: float = -9.0
const ACCEL: float = 16.0

func build(color: Color) -> void:
	body_color = color
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 1.0, 4.3)
	shape.shape = box
	shape.position.y = 0.75
	add_child(shape)
	_body = Node3D.new()
	add_child(_body)
	if not _try_blender_model():
		_add_box(Vector3(1.85, 0.5, 4.25), Vector3(0, 0.62, 0), _mat(body_color, 0.0, 0.35))
		_add_box(Vector3(1.6, 0.45, 2.1), Vector3(0, 1.05, -0.25), _mat(Color(0.03, 0.05, 0.1), 0.0, 0.15))
		_add_box(Vector3(1.9, 0.14, 4.35), Vector3(0, 0.34, 0), _mat(Color(0.05, 0.9, 1.0), 2.8, 0.4))
		_add_box(Vector3(1.5, 0.1, 0.15), Vector3(0, 0.72, -2.14), _mat(Color(1.0, 0.95, 0.75), 3.5, 0.4))
		_add_box(Vector3(1.5, 0.1, 0.15), Vector3(0, 0.72, 2.14), _mat(Color(1.0, 0.1, 0.25), 3.0, 0.4))
		for sx in [-0.95, 0.95]:
			for sz in [-1.45, 1.45]:
				_add_box(Vector3(0.22, 0.3, 0.8), Vector3(sx, 0.32, sz), _mat(Color(0.02, 0.02, 0.04), 0.0, 0.6))
	_glow_light = OmniLight3D.new()
	_glow_light.light_color = Color(0.1, 0.85, 1.0)
	_glow_light.light_energy = 0.7
	_glow_light.omni_range = 4.5
	_glow_light.position.y = 0.4
	_body.add_child(_glow_light)
	# Driver camera rig.
	_cam_pivot = Node3D.new()
	_cam_pivot.position.y = 2.5
	add_child(_cam_pivot)
	_cam_spring = SpringArm3D.new()
	_cam_spring.spring_length = 8.5
	_cam_spring.margin = 0.4
	_cam_pivot.add_child(_cam_spring)
	_camera = Camera3D.new()
	_camera.fov = 70.0
	_cam_spring.add_child(_camera)
	_headlight = SpotLight3D.new()
	_headlight.light_color = Color(1.0, 0.95, 0.8)
	_headlight.light_energy = 0.0
	_headlight.spot_range = 26.0
	_headlight.spot_angle = 32.0
	_headlight.position = Vector3(0, 0.9, -2.0)
	_headlight.rotation_degrees.x = -6.0
	add_child(_headlight)
	# Fake volumetric headlight cone (additive gradient cylinder, front = -Z).
	_cone = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 1.7
	cyl.height = 8.6
	_cone.mesh = cyl
	var cm := StandardMaterial3D.new()
	cm.albedo_texture = _cone_texture()
	cm.albedo_color = Color(1.0, 0.95, 0.8, 1.0)
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cone.material_override = cm
	_cone.position = Vector3(0, 0.78, -6.45)
	_cone.rotation_degrees.x = 90.0
	_cone.visible = false
	_body.add_child(_cone)

func _cone_texture() -> ImageTexture:
	# Vertical gradient: bright at the lamp end (v=1), fading out forward.
	var img := Image.create(8, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		var v: float = 1.0 - float(y) / 63.0
		var a: float = pow(v, 1.6) * 0.22
		img.fill_rect(Rect2i(0, y, 8, 1), Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

const MODEL_PATH := "res://assets/models/hover_car.glb"

func _try_blender_model() -> bool:
	# v1.2: Blender-modeled hover car (beveled wedge hull, glass canopy,
	# thruster pods, rear wing). In imported mesh space the nose sits at
	# +Z (LightFront centroid z=+2.21), so rotate PI to face Godot's -Z
	# forward. Guarded by tests/v12_test.gd (in-frame centroid check —
	# transforms read in _initialize are stale and mislead; the in-game
	# check is authoritative).
	var inst: Node3D = ModelLoader.load_model(MODEL_PATH)
	if inst == null:
		return false
	inst.rotation.y = PI
	inst.name = "HoverCarModel"
	_tint_body(inst)
	_body.add_child(inst)
	return true

func _tint_body(node: Node) -> void:
	# Repaint only the BodyPaint surfaces with this car's color; glass,
	# lights and neon keep the materials baked in Blender.
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for i in range(mi.mesh.get_surface_count()):
				var m: Material = mi.mesh.surface_get_material(i)
				if m != null and m.resource_name.find("BodyPaint") >= 0:
					var paint := StandardMaterial3D.new()
					paint.albedo_color = body_color
					paint.metallic = 0.6
					paint.roughness = 0.32
					mi.set_surface_override_material(i, paint)
	for c in node.get_children():
		_tint_body(c)

func _mat(color: Color, emission: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = 0.35
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m

func _add_box(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	_body.add_child(mi)

func toggle_flight() -> bool:
	if mode != "driven":
		return flying
	flying = not flying
	if flying:
		_roof_landed = false
		_flight_airborne = false
		_takeoff_t = 0.6
	return flying

func set_driven(on: bool) -> void:
	mode = "driven" if on else "parked"
	flying = false
	speed = 0.0
	_headlight.light_energy = 2.2 if on else 0.0
	if _cone != null:
		_cone.visible = on
	if on and _camera != null:
		_camera.make_current()

func set_traffic(block_center: Vector3, half: float) -> void:
	mode = "traffic"
	if _cone != null:
		_cone.visible = true
	var lane: float = 4.2
	_loop = [
		block_center + Vector3(-half - lane, 0, -half - lane),
		block_center + Vector3(half + lane, 0, -half - lane),
		block_center + Vector3(half + lane, 0, half + lane),
		block_center + Vector3(-half - lane, 0, half + lane),
	]
	global_position = _loop[0] + Vector3(0, _base_y, 0)
	_wp = 1
	speed = 10.0

func _physics_process(delta: float) -> void:
	_bob_t += delta
	if mode == "driven":
		_drive(delta)
	elif mode == "traffic":
		_traffic(delta)
	else:
		speed = move_toward(speed, 0.0, delta * 10.0)
		# A car left parked in mid-air (driver bailed out while flying)
		# falls and crash-lands instead of hanging in the sky.
		if global_position.y > _base_y + 1.5 and not is_on_floor():
			velocity.x = 0.0
			velocity.z = 0.0
			velocity.y = maxf(velocity.y - 22.0 * delta, -30.0)
			move_and_slide()
			if is_on_floor():
				velocity = Vector3.ZERO
				_roof_landed = global_position.y > _base_y + 2.0
		else:
			velocity = Vector3.ZERO
	_body.position.y = sin(_bob_t * 2.1) * 0.05
	if not (mode == "driven" and flying):
		# In flight the drive code owns the bank angle instead.
		_body.rotation.z = sin(_bob_t * 1.7) * 0.008

func _drive(delta: float) -> void:
	var main: Node = get_tree().get_first_node_in_group("main")
	var throttle: float = 0.0
	var steer: float = 0.0
	if Input.is_key_pressed(KEY_W):
		throttle += 1.0
	if Input.is_key_pressed(KEY_S):
		throttle -= 1.0
	if Input.is_key_pressed(KEY_A):
		steer += 1.0
	if Input.is_key_pressed(KEY_D):
		steer -= 1.0
	if main != null:
		var td: Vector2 = main.get("touch_drive")
		throttle += td.y
		steer += -td.x
	throttle = clampf(throttle, -1.0, 1.0)
	steer = clampf(steer, -1.0, 1.0)
	var fwd := Vector3(-sin(heading), 0, -cos(heading))
	if flying:
		# Flight: auto-cruise forward; throttle becomes climb/sink
		# (W/GAS up, S/BRK down, Space up, Shift down).
		var v_in: float = throttle
		if Input.is_key_pressed(KEY_SPACE):
			v_in += 1.0
		if Input.is_key_pressed(KEY_SHIFT):
			v_in -= 1.0
		v_in = clampf(v_in, -1.0, 1.0)
		# Takeoff assist: lift off on toggle even before any climb
		# input (without this, a grounded car read as "landed" and
		# flight cancelled itself on the first frame).
		_takeoff_t = maxf(_takeoff_t - delta, 0.0)
		if _takeoff_t > 0.0:
			v_in = maxf(v_in, 0.65)
		speed = move_toward(speed, 21.0, delta * 9.0)
		heading += steer * delta * 0.85
		rotation.y = heading
		fwd = Vector3(-sin(heading), 0, -cos(heading))
		velocity.x = fwd.x * speed
		velocity.z = fwd.z * speed
		velocity.y = v_in * (11.5 if v_in >= 0.0 else 13.5)
		if global_position.y > 95.0 and velocity.y > 0.0:
			velocity.y = 0.0
		move_and_slide()
		_body.rotation.x = lerpf(_body.rotation.x, clampf(-v_in * 0.16, -0.18, 0.18), delta * 5.0)
		_body.rotation.z = lerpf(_body.rotation.z, clampf(steer * 0.3, -0.3, 0.3), delta * 5.0)
		if not is_on_floor():
			_flight_airborne = true
		if is_on_floor() and _flight_airborne and v_in <= 0.0:
			flying = false
			_roof_landed = global_position.y > _base_y + 2.0
			speed = minf(speed, 8.0)
			if main != null:
				main.call("on_car_landed")
	else:
		_body.rotation.x = lerpf(_body.rotation.x, 0.0, delta * 5.0)
		var target: float = throttle * (MAX_SPEED if throttle >= 0.0 else -REV_SPEED)
		var rate: float = ACCEL if signf(target) == signf(speed) or absf(speed) < 0.5 else ACCEL * 2.2
		speed = move_toward(speed, target, rate * delta)
		if absf(speed) > 0.2:
			heading += steer * delta * clampf(absf(speed) / 9.0, 0.25, 1.15) * signf(speed) * 1.05
		rotation.y = heading
		fwd = Vector3(-sin(heading), 0, -cos(heading))
		velocity.x = fwd.x * speed
		velocity.z = fwd.z * speed
		if is_on_floor():
			velocity.y = -2.0
			if not _roof_landed:
				global_position.y = move_toward(global_position.y, _base_y, delta * 3.0)
		elif global_position.y > _base_y + 1.5:
			# Airborne without flight (bailed landing, drove off a roof):
			# real gravity until touchdown.
			velocity.y = maxf(velocity.y - 22.0 * delta, -30.0)
		else:
			velocity.y = -2.0
		move_and_slide()
		if is_on_floor() and not _was_floor:
			_roof_landed = global_position.y > _base_y + 2.0
		if get_slide_collision_count() > 0 and absf(speed) > 6.0:
			speed *= 0.55
	_was_floor = is_on_floor()
	# Camera pivot is a child of the car, whose root already rotates by
	# heading — applying heading here too double-rotates the rig (at a
	# 180-degree turn the camera ended up in FRONT of the car).
	_cam_pivot.rotation = Vector3(-0.22, 0.0, 0.0)
	_camera.fov = 70.0 + clampf(absf(speed) / MAX_SPEED, 0.0, 1.0) * 10.0

func _traffic(delta: float) -> void:
	if _loop.is_empty():
		return
	var target: Vector3 = _loop[_wp]
	var to: Vector3 = target - global_position
	to.y = 0.0
	if to.length() < 6.0:
		_wp = (_wp + 1) % _loop.size()
		return
	var want: float = atan2(to.x, to.z) + PI  # forward is -Z of heading frame
	# Our forward for heading h is (-sin h, -cos h); solve h so it points along 'to'.
	want = atan2(-to.x, -to.z)
	heading = lerp_angle(heading, want, clampf(delta * 1.6, 0.0, 1.0))
	rotation.y = heading
	var fwd := Vector3(-sin(heading), 0, -cos(heading))
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	velocity.y = -2.0
	global_position.y = move_toward(global_position.y, _base_y, delta * 3.0)
	move_and_slide()
	if get_slide_collision_count() > 0:
		_wp = (_wp + 1) % _loop.size()
