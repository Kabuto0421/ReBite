# 2026-06-13: HopMonsterの再演跳躍高さを確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed_scene: PackedScene = load("res://stage/Stage4.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	var hop = scene.get_node("HopMonster")
	var start_position: Vector2 = hop.global_position

	hop.state_machine.change_state(&"Hop", null)
	var normal_apex_y := await _measure_apex_y(hop, 1.2)
	var normal_lift := start_position.y - normal_apex_y
	var record = hop.last_record

	hop.global_position = start_position
	hop.velocity = Vector2.ZERO
	hop.memory_tag.show_record(record)
	hop.state_machine.change_state(&"Recalled", record)
	await _settle_seconds(hop.recall_start_delay + 0.02)
	var replay_apex_y := await _measure_apex_y(hop, 1.2)

	assert(abs(normal_apex_y - replay_apex_y) <= 4.0)
	assert(hop.replay_hop_velocity(record).y == hop.hop_velocity)

	print("HOP_REPLAY_HEIGHT_CHECK_OK normal_lift=%.2f normal_apex=%.2f replay_apex=%.2f" % [normal_lift, normal_apex_y, replay_apex_y])
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit(0)

func _measure_apex_y(hop: Node, seconds: float) -> float:
	var elapsed := 0.0
	var apex_y: float = hop.global_position.y
	while elapsed < seconds:
		await process_frame
		await physics_frame
		apex_y = min(apex_y, hop.global_position.y)
		elapsed += 1.0 / 60.0
	return apex_y

func _settle_seconds(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await process_frame
		await physics_frame
		elapsed += 1.0 / 60.0
