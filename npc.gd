extends Node3D
## Pedestrian: walks the perimeter of a city block on the sidewalk.
## Can be knocked down by a car; gets back up later elsewhere.

var _corners: Array[Vector3] = []
var _wp: int = 0
var _speed: float = 1.5
var _down: bool = false
var _down_t: float = 0.0
var _body: Node3D
var _rng := RandomNumberGenerator.new()

func setup(block_center: Vector3, half: float, color: Color, rng: RandomNumberGenerator) -> void:
	_rng = rng
	var o: float = half - 1.6
	_corners = [
		block_center + Vector3(-o, 0, -o), block_center + Vector3(o, 0, -o),
		block_center + Vector3(o, 0, o), block_center + Vector3(-o, 0, o),
	]
	_wp = _rng.randi() % 4
	global_position = _corners[_wp] + Vector3(0, 0.27, 0)
	_wp = (_wp + 1) % 4
	_speed = _rng.randf_range(1.1, 2.1)
	_body = Node3D.new()
	add_child(_body)
	var torso := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.26
	cap.height = 1.25
	torso.mesh = cap
	torso.position.y = 0.85
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	torso.material_override = m
	_body.add_child(torso)
	var head := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.17
	sp.height = 0.34
	head.mesh = sp
	head.position.y = 1.68
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.85, 0.65, 0.5)
	head.material_override = hm
	_body.add_child(head)
	# Neon hair/visor accent.
	var acc := MeshInstance3D.new()
	var ab := BoxMesh.new()
	ab.size = Vector3(0.3, 0.06, 0.3)
	acc.mesh = ab
	acc.position.y = 1.82
	var am := StandardMaterial3D.new()
	var ac: Color = [Color(1, 0.2, 0.6), Color(0.1, 0.9, 1), Color(1, 0.8, 0.15)][_rng.randi() % 3]
	am.albedo_color = ac
	am.emission_enabled = true
	am.emission = ac
	am.emission_energy_multiplier = 2.2
	acc.material_override = am
	_body.add_child(acc)

func is_down() -> bool:
	return _down

func hit_by_car() -> void:
	if _down:
		return
	_down = true
	_down_t = 6.0
	_body.rotation.x = -PI * 0.5
	_body.position.y = 0.15

func _process(delta: float) -> void:
	if _down:
		_down_t -= delta
		if _down_t <= 0.0:
			# Respawn standing on a random corner (main may relocate us later).
			_down = false
			_body.rotation.x = 0.0
			_body.position.y = 0.0
			global_position = _corners[_rng.randi() % _corners.size()] + Vector3(0, 0.27, 0)
		return
	var target: Vector3 = _corners[_wp] + Vector3(0, 0.27, 0)
	var to: Vector3 = target - global_position
	to.y = 0.0
	if to.length() < 0.5:
		_wp = (_wp + 1) % _corners.size()
		return
	var dir: Vector3 = to.normalized()
	global_position += dir * _speed * delta
	_body.rotation.y = lerp_angle(_body.rotation.y, atan2(dir.x, dir.z), clampf(delta * 8.0, 0.0, 1.0))
	_body.position.y = absf(sin(Time.get_ticks_msec() * 0.012 * _speed)) * 0.05
