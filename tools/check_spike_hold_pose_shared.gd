# 2026-06-13: 針ヒット停止姿勢が敵共通で使えることを確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed_scene: PackedScene = load("res://stage/Stage3.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	var hop = scene.get_node("HopMonster")
	var impact_position: Vector2 = hop.global_position + Vector2(0, -28)
	scene.handle_spike_body_entered(hop, impact_position)
	await process_frame

	assert(scene.get_tree().paused)
	assert(hop.current_state_name() != &"Dying")
	assert(hop.sprite.animation == &"dead")
	assert(hop.sprite.frame == 3)
	assert(not hop.sprite.is_playing())
	assert(scene.get_tree().get_nodes_in_group("spike_impact_shard").is_empty())

	await _wait_until_state(hop, &"Dying", scene.spike_impact_hold_time + 0.4)
	assert(hop.current_state_name() == &"Dying")
	assert(not scene.get_tree().paused)

	print("SPIKE_HOLD_POSE_SHARED_CHECK_OK")
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit(0)

func _wait_until_state(node: Node, state_name: StringName, timeout: float) -> void:
	var elapsed := 0.0
	while elapsed < timeout and node.current_state_name() != state_name:
		await create_timer(0.01, true, false, true).timeout
		elapsed += 0.01
