# 2026-06-13: 最後の敵の針ヒット演出を確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed_scene: PackedScene = load("res://stage/Stage1.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	var enemy = scene.get_node("SkullMonster")
	var impact_position: Vector2 = enemy.global_position
	var enemy_state: StringName = enemy.current_state_name()
	var camera_position: Vector2 = scene.camera.global_position
	var camera_zoom: Vector2 = scene.camera.zoom
	var expected_zoom: Vector2 = scene.camera_base_zoom * scene.spike_impact_zoom_multiplier
	scene.handle_spike_body_entered(enemy, impact_position)
	await process_frame
	var expected_focus_position: Vector2 = impact_position.lerp(enemy.global_position, 0.55) + Vector2(0, -18)

	assert(scene.camera_cinematic)
	assert(scene.spike_impact_freeze_active)
	assert(scene.get_tree().paused)
	assert(scene.camera.global_position == expected_focus_position)
	assert(scene.camera.global_position != camera_position)
	assert(scene.camera.zoom == expected_zoom)
	assert(scene.camera.zoom != camera_zoom)
	assert(enemy.current_state_name() == enemy_state)
	assert(enemy.sprite.animation == &"dead")
	assert(enemy.sprite.frame == 3)
	assert(not enemy.sprite.is_playing())
	assert(scene.get_tree().get_nodes_in_group("spike_impact_shard").is_empty())
	assert(scene.get_tree().get_nodes_in_group("spike_impact_ray").is_empty())
	assert(scene.get_tree().get_nodes_in_group("spike_impact_flash").is_empty())

	await _settle_seconds(max(0.01, scene.spike_impact_hold_time * 0.5))
	assert(scene.camera.global_position == expected_focus_position)
	assert(scene.camera.zoom == expected_zoom)
	assert(enemy.current_state_name() == enemy_state)
	assert(enemy.sprite.animation == &"dead")
	assert(enemy.sprite.frame == 3)
	assert(scene.get_tree().paused)
	assert(scene.get_tree().get_nodes_in_group("spike_impact_shard").is_empty())
	assert(scene.get_tree().get_nodes_in_group("spike_impact_ray").is_empty())
	assert(scene.get_tree().get_nodes_in_group("spike_impact_flash").is_empty())

	await _wait_until_state(enemy, &"Dying", scene.spike_impact_hold_time * 0.5 + 0.4)
	assert(enemy.current_state_name() == &"Dying")
	assert(not scene.get_tree().paused)
	assert(not scene.spike_impact_freeze_active)
	assert(scene.get_tree().get_nodes_in_group("spike_impact_shard").size() >= 40)
	assert(scene.get_tree().get_nodes_in_group("spike_impact_ray").size() >= 12)
	assert(scene.get_tree().get_nodes_in_group("spike_impact_flash").size() == 1)

	await _wait_until_camera_released(scene, 2.0)
	assert(not scene.get_tree().paused)
	assert(not scene.spike_impact_freeze_active)
	assert(not scene.camera_cinematic)

	print("SPIKE_IMPACT_FEEDBACK_CHECK_OK")
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit(0)

func _settle_seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func _wait_until_camera_released(scene: Node, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout and scene.camera_cinematic:
		await create_timer(0.02, true, false, true).timeout
		elapsed += 0.02

func _wait_until_state(node: Node, state_name: StringName, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout and node.current_state_name() != state_name:
		await create_timer(0.01, true, false, true).timeout
		elapsed += 0.01
