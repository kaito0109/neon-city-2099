extends SceneTree
## Full-city integration; add -- --shots under an X display for GL captures.
const EXTERIOR = preload("res://casino/casino_exterior.gd")
var fails: int = 0
var main: Node3D
var landmark: Node3D

func _ok(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ", label)
	if not value:
		fails += 1

func _initialize() -> void:
	_run.call_deferred()

func _wait_frames(count: int = 8) -> void:
	for i in range(count):
		await physics_frame

func _ray(a: Vector3, b: Vector3) -> Dictionary:
	return main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a, b))

func _run() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _wait_frames(15)
	main.start_game()
	var site: Dictionary = {}
	var site_index: int = -1
	for i in range(main.city.shop_sites.size()):
		if main.city.shop_sites[i]["kind"] == "casino":
			site = main.city.shop_sites[i]
			site_index = i
	landmark = main.city.get_node_or_null("CasinoLandmark")
	_ok(landmark != null, "landmark built into real city")
	if landmark == null:
		quit(1)
		return
	landmark.set_process(false)
	_ok(landmark.get_node("PearlHalo").position.y > 70, "halo is a skyline landmark")
	var batch_count: int = 0
	var instance_count: int = 0
	for child in landmark.get_children():
		if child is MultiMeshInstance3D:
			batch_count += 1
			instance_count += child.multimesh.instance_count
	_ok(batch_count <= 14 and instance_count > 250, "detail geometry batched (%d groups, %d instances)" % [batch_count, instance_count])
	var reserved: int = 0
	for plot in LayoutV4.DATA["plots"]:
		if EXTERIOR.occupies_plot(plot):
			reserved += 1
			var vacant := true
			for building in main.city.get("_buildings"):
				var center: Vector3 = building["center"]
				if Vector2(center.x, center.z).distance_to(Vector2(plot["x"], plot["z"])) < 0.1:
					vacant = false
			_ok(vacant, "reserved plot has no old building")
	_ok(reserved > 0, "existing plots reserved for resort (%d)" % reserved)
	# Above-ground obstacle probes: the road and ACT threshold stay open.
	var door: Vector3 = site["door_pos"]
	_ok(_ray(door + Vector3(0, 0.3, 0), door + Vector3(0, 3.0, 0)).is_empty(), "entrance ACT point free of walls")
	var road_clear := true
	for z in range(34, 85, 2):
		var query := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.5
		query.shape = sphere
		query.transform.origin = Vector3(0, 1, z)
		for hit in main.get_world_3d().direct_space_state.intersect_shape(query):
			if landmark.is_ancestor_of(hit["collider"]):
				road_clear = false
	_ok(road_clear, "landmark leaves north/south road open")
	var destinations_clear := true
	for destination in [Vector3(38, 1, 20), Vector3(38, 1, 26)]:
		var hit := _ray(destination, destination + Vector3(0, 1, 0))
		if not hit.is_empty() and landmark.is_ancestor_of(hit["collider"]):
			destinations_clear = false
	for shop in main.city.shop_sites:
		if shop["kind"] == "denki":
			var shop_door: Vector3 = shop["door_pos"]
			var hit := _ray(shop_door + Vector3(0, 0.2, 0), shop_door + Vector3(0, 2.0, 0))
			if not hit.is_empty() and landmark.is_ancestor_of(hit["collider"]):
				destinations_clear = false
	_ok(destinations_clear, "clinic and relocated electronics entrance stay accessible")
	_ok(not _ray(Vector3(4, 2, 50), Vector3(20, 2, 50)).is_empty(), "podium has side collision and real depth")
	landmark.update_doors(door + Vector3(0, 1, 0), 1.0)
	_ok(absf(landmark.get_node("DoorLeft").position.x) > 4, "doors slide open near entrance")
	landmark.update_doors(Vector3(-100, 0, 0), 1.0)
	_ok(is_equal_approx(absf(landmark.get_node("DoorLeft").position.x), 1.5), "doors close when player leaves")
	landmark.update_doors(Vector3(28, -60, 35), 1.0)
	_ok(is_equal_approx(absf(landmark.get_node("DoorLeft").position.x), 1.5), "interior player does not open outside doors")
	main.player.global_position = door
	main.interact()
	_ok(main.in_shop == site_index, "ACT enters existing casino interior")
	main.player.global_position = site["exit_pos"]
	main.interact()
	_ok(main.in_shop == -1 and main.player.global_position.distance_to(door) < 0.1, "exit returns to accessible doorway")
	if "--shots" in OS.get_cmdline_user_args():
		main.hud.visible = false
		main.player.visible = false
		var cam := Camera3D.new()
		cam.far = 550
		cam.fov = 62
		root.add_child(cam)
		cam.make_current()
		DirAccess.make_dir_recursive_absolute("/tmp/neon-landmark-shots")
		var views: Array = [
			["skyline", Vector3(-32, 36, -45), Vector3(28, 43, 50)],
			["street", Vector3(5, 4.2, 10), Vector3(28, 12, 40)],
			["entrance", Vector3(28, 2.0, 23), Vector3(28, 3.0, 35)],
			["side", Vector3(-12, 16, 60), Vector3(28, 24, 52)]]
		for view in views:
			cam.position = view[1]
			cam.look_at(view[2])
			landmark.update_doors(Vector3(28, 1, 31), 1.0)
			await _wait_frames(12)
			await RenderingServer.frame_post_draw
			var path: String = "/tmp/neon-landmark-shots/" + view[0] + ".png"
			root.get_texture().get_image().save_png(path)
			print("SHOT ", path)
	main.queue_free()
	await _wait_frames(2)
	print("CASINO_LANDMARK_DONE fails=", fails)
	quit(1 if fails else 0)
