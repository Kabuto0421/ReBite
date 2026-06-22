# 2026-06-13: 予測矢印と噛み対象の一致を確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed_scene: PackedScene = load("res://stage/Stage2.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	var player = scene.get_node("Player")
	var far_enemy = scene.get_node("SkullMonster")
	var near_enemy = scene.get_node("SkullMonster2")

	far_enemy.global_position = Vector2(220, 330)
	near_enemy.global_position = Vector2(500, 330)
	player.global_position = near_enemy.global_position + Vector2(0, -80)

	for enemy in [far_enemy, near_enemy]:
		enemy.velocity = Vector2.ZERO
		enemy.commit_dash_record(Vector2.LEFT)
		enemy.state_machine.change_state(&"Recover", null)

	await _settle_frames(4)
	assert(player.pick_bite_target() == near_enemy)

	scene._update_memory_focus()
	assert(scene.prediction_arrow.visible)
	assert(scene.prediction_arrow.start_position == near_enemy.global_position + Vector2(0, -26))

	scene.locked_bite_target = near_enemy
	scene.camera_cinematic = true
	assert(scene.locked_bite_target == near_enemy)
	scene._update_memory_focus()
	assert(scene.prediction_arrow.start_position == near_enemy.global_position + Vector2(0, -26))

	print("PREDICTION_MATCHES_BITE_TARGET_CHECK_OK")
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit(0)

func _settle_frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame
