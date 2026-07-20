# 2026-06-24: 左右DASH記憶仕様v1.1の更新、割り込み、再形成を検証する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://stage/Stage1.tscn").instantiate()
	root.add_child(scene)
	await _settle_frames(2)
	var player: Node = scene.get_node("Player")
	var skull: Node = scene.get_node("SkullMonster")
	player.global_position = Vector2(1600.0, 200.0)
	skull.global_position = Vector2(850.0, 330.0)

	assert(skull.last_record == null)
	assert(skull.memory_tag.lifecycle == MemoryTag.Lifecycle.NONE)
	assert(skull.sprite.sprite_frames.get_frame_count(&"telegraph") == 1)
	assert(not skull.sprite.sprite_frames.get_animation_loop(&"telegraph"))
	assert(skull.sprite.sprite_frames.get_frame_count(&"dash") == 4)
	assert(skull.sprite.sprite_frames.get_animation_loop(&"dash"))
	skull.play_animation(&"idle")
	skull.sprite.frame = 1
	skull.sprite.flip_h = false
	skull.attack_warning_eyes.sync_to_sprite()
	assert(is_equal_approx(skull.attack_warning_eyes.position.x, 3.5))
	skull.sprite.flip_h = true
	skull.attack_warning_eyes.sync_to_sprite()
	assert(is_equal_approx(skull.attack_warning_eyes.position.x, -3.5))
	skull.play_animation(&"telegraph")
	skull.sprite.frame = 0
	skull.sprite.flip_h = false
	skull.attack_warning_eyes.sync_to_sprite()
	assert(skull.attack_warning_eyes.position == Vector2(-5.5, -8.0))
	skull.state_machine.change_state(&"Telegraph", skull.build_dash_record(Vector2.LEFT))
	await _settle_seconds(0.25)
	assert(skull.current_state_name() == &"Telegraph")
	assert(skull.sprite.animation == &"telegraph")
	assert(skull.sprite.frame == 0)
	await _settle_seconds(0.20)
	assert(skull.current_state_name() == &"Dash")
	assert(skull.sprite.animation == &"dash")
	skull.reset_to_spawn()

	var left_dash: Resource = skull.build_dash_record(Vector2.LEFT)
	skull.state_machine.change_state(&"Dash", left_dash)
	await _settle_seconds(skull.dash_duration + 0.08)
	assert(skull.last_record.direction == Vector2.LEFT)
	assert(skull.last_record.source == &"NATURAL")
	assert(skull.last_record.distance == skull.dash_speed * skull.dash_duration)
	assert(skull.memory_tag.is_available())
	var left_memory_id: int = skull.last_record.memory_id

	var right_dash: Resource = skull.build_dash_record(Vector2.RIGHT)
	skull.state_machine.change_state(&"RightDash", right_dash)
	await _settle_frames(2)
	assert(skull.last_record.memory_id == left_memory_id)
	assert(skull.last_record.direction == Vector2.LEFT)
	assert(skull.current_action_record().direction == Vector2.RIGHT)
	assert(skull.is_biteable())
	await _settle_seconds(skull.dash_duration * 0.40)
	assert(skull.current_state_name() == &"RightDash")
	assert(skull.memory_tag.window_progress > skull.memory_tag.blink_start_progress)
	skull.memory_tag.set_window_progress(0.10)
	assert(skull.current_state_name() == &"RightDash")
	assert(skull.memory_tag.window_progress < skull.memory_tag.blink_start_progress)

	player.global_position = skull.global_position + Vector2(58.0, 0.0)
	player.facing = -1
	player.sprite.flip_h = true
	player.bite_area.position.x = -34.0
	await _settle_frames(2)
	var context: Dictionary = player.prepare_bite_context()
	assert(context.get("replay_started", false))
	assert(skull.current_state_name() == &"Recalled")
	assert(skull.state_machine.current_state.record.direction == Vector2.LEFT)
	assert(skull.last_record.memory_id == left_memory_id)
	assert(not skull.last_record.is_available)
	assert(not skull.attack_hitbox.monitoring or player.is_contact_immune_from(skull))

	await _settle_seconds(skull.recall_start_delay + 0.03)
	assert(skull.current_action_record().direction == Vector2.LEFT)
	await _settle_seconds(skull.dash_duration + 0.18)
	assert(skull.last_record.direction == Vector2.LEFT)
	assert(skull.last_record.source == &"REPLAY")
	assert(skull.last_record.memory_id > left_memory_id)
	assert(skull.memory_tag.is_available())
	assert(skull.next_dash_direction == Vector2.RIGHT)

	var completed_right: Resource = skull.build_natural_dash_record()
	skull.state_machine.change_state(&"RightDash", completed_right)
	await _settle_seconds(skull.dash_duration + 0.08)
	assert(skull.last_record.direction == Vector2.RIGHT)
	assert(skull.last_record.source == &"NATURAL")
	assert(skull.memory_tag.is_available())
	assert(skull.next_dash_direction == Vector2.LEFT)

	var right_memory_id: int = skull.last_record.memory_id
	skull.global_position = Vector2(968.0, 330.0)
	skull.state_machine.change_state(&"RightDash", skull.build_dash_record(Vector2.RIGHT))
	await _settle_seconds(0.12)
	assert(skull.current_state_name() == &"Recover")
	assert(skull.next_dash_direction == Vector2.LEFT)
	assert(skull.last_record.memory_id > right_memory_id)
	assert(skull.last_record.direction == Vector2.RIGHT)
	assert(skull.last_record.is_available)
	assert(skull.memory_tag.visible)
	var blocked_x: float = skull.global_position.x
	await _settle_seconds(0.30)
	assert(skull.current_state_name() == &"Recover")
	assert(is_equal_approx(skull.global_position.x, blocked_x))
	assert(is_zero_approx(skull.velocity.x))
	await _settle_seconds(0.35)
	assert(skull.current_state_name() == &"Telegraph")
	assert(is_zero_approx(skull.velocity.x))
	await _settle_seconds(0.42)
	assert(skull.current_state_name() == &"Dash")
	assert(skull.current_action_record().direction == Vector2.LEFT)

	print("DASH_MEMORY_SPEC_V11_CHECK_OK")
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
