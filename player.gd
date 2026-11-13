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
	if not input_enabled or dead or in_car != null:
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
	velocity.x = wish.x * speed * minf(1.0, iv.length() + 0.001)
	velocity.z = wish.z * speed * minf(1.0, iv.length() + 0.001)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5
		if _jump_queued or Input.is_key_pressed(KEY_SPACE):
			velocity.y = 7.0
	_jump_queued = false
	move_and_slide()
	# Face movement direction; keep model under the camera yaw when idle.
	if wish.length() > 0.1:
		var target: float = atan2(wish.x, wish.z)
		_model_yaw = lerp_angle(_model_yaw, target, clampf(delta * 10.0, 0.0, 1.0))
	if _model != null:
		_model.rotation.y = _model_yaw
	if _anim != null:
		var hspeed: float = Vector2(velocity.x, velocity.z).length()
		var want: String = "Idle"
		if hspeed > 3.4:
			want = "Run"
		elif hspeed > 0.4:
			want = "Walk"
		if want != _cur_clip:
			_cur_clip = want
			People.play(_anim, want)
		if want == "Walk":
			_anim.speed_scale = clampf(hspeed / 2.2, 0.6, 1.8)
		elif want == "Run":
			_anim.speed_scale = clampf(hspeed / 5.6, 0.7, 1.6)
		else:
			_anim.speed_scale = 1.0
