# 2026-06-13: 上から噛める範囲とStage2ジャンプ導線を確認する。
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
	var target = scene.get_node("SkullMonster2")
	assert(player.jump_velocity <= -520.0)
	assert(is_equal_approx(target.dash_duration, 0.34))

	target.commit_dash_record(Vector2.LEFT)
	target.state_machine.change_state(&"Recover", null)
	player.global_position = target.global_position + Vector2(0, -96)
	player.velocity = Vector2.ZERO
	await _settle_frames(4)

	assert(player.pick_bite_target() == target)
	print("TOP_BITE_AND_STAGE2_JUMP_CHECK_OK")
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit(0)

func _settle_frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame
