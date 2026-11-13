extends Node3D
## Pedestrian with a real rigged character model (Quaternius CC0).
## Walking NPCs stroll the perimeter of a city block on the sidewalk;
## standing NPCs idle / wave / chat at a sidewalk spot. Animation is
## distance-culled: beyond ~55 m the AnimationPlayer pauses (the pose
## freezes) while the walk logic keeps moving the NPC.
## Can be knocked down by a car; gets back up later elsewhere.

var _corners: Array[Vector3] = []
var _wp: int = 0
var _speed: float = 1.5
var _down: bool = false
var _down_t: float = 0.0
var _body: Node3D
var _ap: AnimationPlayer
var _standing: bool = false
var _cull_t: float = 0.0
var _rng := RandomNumberGenerator.new()

const STANDING_CLIPS: Array = ["Idle_Neutral", "Wave", "Clapping", "Standing", "Idle"]

func setup(block_center: Vector3, half: float, cast_name: String, rng: RandomNumberGenerator, standing: bool = false) -> void:
	_rng = rng
	_standing = standing
	var o: float = half - 1.6
	_corners = [
		block_center + Vector3(-o, 0, -o), block_center + Vector3(o, 0, -o),
		block_center + Vector3(o, 0, o), block_center + Vector3(-o, 0, o),
	]
	_body = People.spawn(cast_name)
	if _body == null:
		_body = Node3D.new()
	add_child(_body)
	# Slight per-person height variety.
	var j: float = _rng.randf_range(0.95, 1.05)
	_body.scale *= j
	_ap = People.find_ap(_body)
	if _standing:
		global_position = _corners[_rng.randi() % 4] + Vector3(0, 0.27, 0)
		rotation.y = _rng.randf() * TAU
		if _ap != null:
			var start: int = _rng.randi() % STANDING_CLIPS.size()
			for k in range(STANDING_CLIPS.size()):
				if People.play(_ap, STANDING_CLIPS[(start + k) % STANDING_CLIPS.size()]):
					break
			_ap.speed_scale = _rng.randf_range(0.85, 1.1)
			_ap.seek(_rng.randf() * 2.0)
	else:
		_wp = _rng.randi() % 4
		global_position = _corners[_wp] + Vector3(0, 0.27, 0)
		_wp = (_wp + 1) % 4
		_speed = _rng.randf_range(1.1, 2.1)
		if _ap != null:
			People.play(_ap, "Walk")
			_ap.speed_scale = _speed / 1.5
			_ap.seek(_rng.randf() * 2.0)
	_cull_t = _rng.randf() * 0.3

func is_down() -> bool:
	return _down

func hit_by_car() -> void:
	if _down:
		return
	_down = true
	_down_t = 6.0
	if _ap != null:
		_ap.playback_active = false
	_body.rotation.x = -PI * 0.5
	_body.position.y = 0.15

func _process(delta: float) -> void:
	# Distance-cull animation playback (not the walk logic).
	_cull_t -= delta
	if _cull_t <= 0.0 and _ap != null and not _down:
		_cull_t = 0.3
		var p: Node = get_tree().get_first_node_in_group("player")
		if p != null:
			_ap.playback_active = global_position.distance_squared_to((p as Node3D).global_position) < 3025.0
	if _down:
		_down_t -= delta
		if _down_t <= 0.0:
			_down = false
			_body.rotation.x = 0.0
			_body.position.y = 0.0
			if _ap != null:
				_ap.playback_active = true
				if not _standing:
					People.play(_ap, "Walk")
			global_position = _corners[_rng.randi() % _corners.size()] + Vector3(0, 0.27, 0)
		return
	if _standing:
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
