# 2026-06-24: 地上加速、空中制御、ジャンプ猶予、離着陸変形を確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var player: Node = load("res://entities/Player.tscn").instantiate()
	root.add_child(player)
	await process_frame

	assert(player.ground_acceleration == 3000.0)
	assert(player.ground_deceleration == 4200.0)
	assert(player.ground_turn_acceleration == 5000.0)
	assert(player.air_acceleration == 1800.0)
	assert(player.coyote_time == 0.08)
	assert(player.jump_buffer_time == 0.10)

	Input.action_press("move_right")
	player.velocity.x = 0.0
	player.apply_ground_horizontal_input(1.0 / 60.0)
	assert(is_equal_approx(player.velocity.x, 50.0))
	player.velocity.x = 0.0
	player.apply_air_horizontal_input(1.0 / 60.0)
	assert(is_equal_approx(player.velocity.x, 30.0))
	Input.action_release("move_right")

	player.refresh_coyote_window()
	player.buffer_jump()
	assert(player.try_consume_buffered_jump())
	assert(player.velocity.y == player.jump_velocity)
	assert(player.coyote_timer == 0.0)
	assert(player.jump_buffer_timer == 0.0)
	assert(player.sprite.scale.is_equal_approx(player.visual_scale * Vector2(1.08, 0.92)))

	player.play_landing_feedback(player.landing_feedback_speed)
	assert(player.sprite.scale.is_equal_approx(player.visual_scale * Vector2(1.12, 0.88)))
	await create_timer(0.2).timeout
	assert(player.sprite.scale.is_equal_approx(player.visual_scale))

	print("PLAYER_MOVEMENT_FEEL_CHECK_OK")
	player.queue_free()
	await process_frame
	quit(0)
