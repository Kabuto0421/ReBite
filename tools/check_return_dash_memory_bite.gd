# 2026-06-24: 逆向きDASH中も直前記憶を保持し、K入力フレームで再演へ上書きできることを確認する。
extends SceneTree

# SceneTree起動後にStage1の実ノードで検査する。
func _init() -> void:
	call_deferred("_run")

# タグ保持、入力時停止、向き直り、元方向再演を順に確認する。
func _run() -> void:
	assert(not InputMap.has_action("parry"))
	var scene: Node = load("res://stage/Stage1.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var player: Node = scene.get_node("Player")
	var skull: Node = scene.get_node("SkullMonster")
	assert(player.get_node_or_null("ParryShield") == null)

	skull.commit_dash_record(Vector2.LEFT)
	skull.state_machine.change_state(&"Recover", null)
	await _settle_frames(2)
	assert(skull.memory_tag.visible)
	assert(skull.last_record.direction.x < 0.0)

	skull.state_machine.change_state(&"RightDash", null)
	await _settle_frames(2)
	assert(skull.current_state_name() == &"RightDash")
	assert(skull.memory_tag.visible)
	assert(skull.is_biteable())
	assert(skull.last_record.direction.x < 0.0)
	assert(skull.current_action_record().direction.x > 0.0)
	assert(not skull.sprite.flip_h)

	player.global_position = skull.global_position + Vector2(58.0, 0.0)
	player.velocity = Vector2.ZERO
	player.facing = -1
	player.sprite.flip_h = true
	player.bite_area.position.x = -34.0
	await _settle_frames(2)
	assert(player.pick_bite_target() == skull)
	var bite_context: Dictionary = player.prepare_bite_context()
	assert(bite_context.get("target") == skull)
	assert((bite_context.get("record") as Resource).direction.x < 0.0)
	assert(skull.current_state_name() == &"Recalled")
	assert(skull.memory_tag.lifecycle == MemoryTag.Lifecycle.BREAKING)
	assert(is_zero_approx(skull.velocity.x))
	assert(skull.current_action_record() == null)
	assert(not skull.sprite.is_playing())
	assert(player.is_contact_immune_from(skull))

	player.state_machine.change_state(&"BiteWindup", bite_context)
	await _settle_seconds(0.03)
	assert(skull.current_state_name() == &"Recalled")
	assert(skull.state_machine.current_state.record.direction.x < 0.0)
	assert(not skull.sprite.flip_h)
	var held_position: Vector2 = skull.global_position
	var held_frame: int = skull.sprite.frame
	await _settle_seconds(0.24)
	assert(skull.sprite.flip_h)
	assert(skull.memory_tag.lifecycle == MemoryTag.Lifecycle.REPLAYING)
	var replay_material := skull.sprite.material as ShaderMaterial
	assert((replay_material.get_shader_parameter("outline_color") as Color).is_equal_approx(skull.replay_outline_color))
	assert(is_equal_approx(float(replay_material.get_shader_parameter("outline_size")), skull.replay_outline_size))
	await _settle_seconds(0.06)
	assert(skull.global_position.is_equal_approx(held_position))
	assert(skull.sprite.frame == held_frame)
	assert(not skull.sprite.is_playing())

	await _settle_seconds(skull.recall_start_delay - 0.30 + 0.03)
	assert(skull.current_state_name() == &"Recalled")
	assert(skull.current_action_record() != null)
	assert(skull.current_action_record().direction.x < 0.0)
	assert(skull.velocity.x < 0.0)
	assert(skull.sprite.is_playing())
	await _settle_seconds(skull.dash_duration + 0.18)
	assert(skull.last_record.direction.x < 0.0)
	assert(skull.last_record.source == &"REPLAY")
	assert(skull.memory_tag.is_available())
	assert((replay_material.get_shader_parameter("outline_color") as Color).is_equal_approx(skull.default_outline_color))

	player.reset_to_spawn()
	skull.reset_to_spawn()
	skull.commit_dash_record(Vector2.LEFT)
	skull.state_machine.change_state(&"RightDash", null)
	await _settle_frames(2)
	skull._on_attack_hitbox_body_entered(player)
	assert(player.is_dead)

	print("RETURN_DASH_MEMORY_BITE_CHECK_OK")
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit(0)

# 指定数の描画・物理フレームを進める。
func _settle_frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame

# 60fps換算で指定時間分のフレームを進める。
func _settle_seconds(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await process_frame
		await physics_frame
		elapsed += 1.0 / 60.0
