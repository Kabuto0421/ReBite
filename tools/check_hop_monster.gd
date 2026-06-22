# 2026-06-13: HopMonsterの基本挙動を確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed_scene: PackedScene = load("res://stage/Stage3.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	var player = scene.get_node("Player")
	var hop = scene.get_node("HopMonster")
	hop.state_machine.change_state(&"Hop", null)
	await _settle_seconds(0.44)
	assert(hop.current_state_name() == &"Recover")
	assert(hop.is_biteable())
	assert(hop.memory_tag.get_node("Label").text == "↑跳躍")
	assert(hop.last_record.action_name == &"jump")
	assert(hop.last_record.velocity == Vector2(0.0, hop.hop_velocity))

	player.global_position = hop.global_position + Vector2(58, 0)
	player.velocity = Vector2.ZERO
	player.facing = -1
	player.sprite.flip_h = true
	player.bite_area.position.x = -34.0
	await _settle_frames(3)
	assert(player.pick_bite_target() == hop)

	var recall_start_y: float = hop.global_position.y
	player.state_machine.change_state(&"BiteLunge", null)
	assert(player.bite_invulnerable)
	await _settle_seconds(0.22)
	assert(hop.current_state_name() == &"Recalled")

	await _settle_seconds(hop.recall_start_delay + 0.18)
	assert(hop.current_state_name() == &"Dying")

	print("HOP_MONSTER_CHECK_OK")
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
