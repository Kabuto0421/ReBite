# 2026-06-13: 途中撃破でカメラ演出が出ないことを確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed_scene: PackedScene = load("res://stage/Stage2.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	var enemy = scene.get_node("SkullMonster")
	var other_enemy = scene.get_node("SkullMonster2")
	var impact_position: Vector2 = enemy.global_position
	var camera_position: Vector2 = scene.camera.global_position
	var camera_zoom: Vector2 = scene.camera.zoom

	assert(not scene.should_use_defeat_camera_for_enemy(enemy))
	scene.handle_spike_body_entered(enemy, impact_position)
	await process_frame

	assert(not scene.camera_cinematic)
	assert(not scene.spike_impact_freeze_active)
	assert(not scene.get_tree().paused)
	assert(scene.camera.global_position == camera_position)
	assert(scene.camera.zoom == camera_zoom)
	assert(enemy.current_state_name() == &"Dying")
	assert(scene.get_tree().get_nodes_in_group("spike_impact_shard").size() >= 40)
	assert(scene.get_tree().get_nodes_in_group("spike_impact_ray").size() >= 12)
	assert(scene.get_tree().get_nodes_in_group("spike_impact_flash").size() == 1)

	scene.handle_spike_body_entered(other_enemy, other_enemy.global_position)
	await process_frame
	assert(other_enemy.current_state_name() == &"Dying")
	assert(not scene.get_tree().paused)
	assert(not scene.spike_impact_freeze_active)

	print("NONFINAL_SPIKE_IMPACT_NO_CAMERA_CHECK_OK")
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit(0)

func _settle_seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func _wait_until_state(enemy: Node, state_name: StringName, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout and enemy.current_state_name() != state_name:
		await create_timer(0.02, true, false, true).timeout
		elapsed += 0.02
	assert(enemy.current_state_name() == state_name)
