# 2026-06-13: Stage2の連鎖撃破導線を確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed_scene: PackedScene = load("res://stage/Stage2.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	assert(scene.has_node("EditableGeometry"))
	var geometry = scene.get_node("EditableGeometry")
	assert(geometry.get_child_count() > 0)
	assert(scene.has_node("EditableGeometry/LeftPitSpikes"))
	assert(scene.has_node("EditableGeometry/NormalTileGroups"))
	assert(scene.has_node("EditableGeometry/ActionBreakGroups"))
	var normal_tile_groups = scene.get_node("EditableGeometry/NormalTileGroups")

	var enemies := [
		scene.get_node("SkullMonster"),
		scene.get_node("SkullMonster2"),
		scene.get_node("SkullMonster3"),
	]

	var platform_count := 0
	var spike_count := 0
	assert(normal_tile_groups.get_script().resource_path == "res://scripts/stage/EditableTileGroup.gd")
	var rects: Array[Rect2] = normal_tile_groups.get_tile_rects()
	platform_count = rects.size()
	assert(platform_count > 0)
	for rect in rects:
		assert(rect.size.x > 0.0 and rect.size.y > 0.0)
	for child in geometry.get_children():
		var script_path: String = child.get_script().resource_path if child.get_script() != null else ""
		if script_path == "res://scripts/stage/EditableSpikes.gd":
			spike_count += 1
			assert(child.size.x > 0.0 and child.size.y > 0.0)

	assert(platform_count > 0)
	assert(spike_count == 1)

	for enemy in enemies:
		assert(is_equal_approx(enemy.dash_duration, 0.34))

	print("STAGE2_EDITABLE_GEOMETRY_CHECK_OK")
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit(0)

func _settle_frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame

func _settle_seconds(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await process_frame
		await physics_frame
		elapsed += 1.0 / 60.0

func _wait_until_freed(node: Node, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout and is_instance_valid(node):
		await process_frame
		await physics_frame
		elapsed += 1.0 / 60.0
