# 2026-06-21: BoarMonsterのアニメーション、SMASH記憶、再演値を確認する。
extends SceneTree

# テスト本体を次フレームから実行する。
func _init() -> void:
	call_deferred("_run")

# シーンを生成し、自律SMASHから噛み再演までの契約を検証する。
func _run() -> void:
	var packed_scene: PackedScene = load("res://entities/boar_monster.tscn")
	assert(packed_scene != null)
	var boar = packed_scene.instantiate()
	root.add_child(boar)
	await process_frame
	await physics_frame

	assert(boar is BoarMonster)
	assert(boar.current_state_name() == &"Idle")
	assert(boar.last_record.action_name == &"smash")
	assert(boar.last_record.direction == Vector2.LEFT)
	assert(is_equal_approx(boar.last_record.velocity.x, -boar.smash_speed))
	assert(is_equal_approx(boar.last_record.duration, boar.smash_duration))
	assert(boar.sprite.sprite_frames.get_frame_count(&"idle") == 12)
	assert(boar.sprite.sprite_frames.get_frame_count(&"walk") == 6)
	assert(boar.sprite.sprite_frames.get_frame_count(&"smash") == 10)
	assert(boar.sprite.sprite_frames.get_frame_count(&"dead") == 10)
	_assert_smash_hitbox_reaches_floor_break_sensor(boar)

	var committed_record: Resource = boar.last_record
	boar.commit_smash_record(committed_record)
	boar.state_machine.change_state(&"Recover")
	assert(boar.is_biteable())
	assert(boar.memory_tag.visible)
	assert(boar.sprite.animation == &"walk")

	boar.recall_start_delay = 0.0
	boar.receive_committed_bite(null, committed_record)
	assert(boar.current_state_name() == &"Recalled")
	await physics_frame
	var boar_material := boar.sprite.material as ShaderMaterial
	assert((boar_material.get_shader_parameter("outline_color") as Color).is_equal_approx(boar.replay_outline_color))
	for i in 31:
		await physics_frame
	assert(boar.current_action_record() == committed_record)
	assert(is_equal_approx(boar.velocity.x, committed_record.velocity.x))
	assert(boar.sprite.animation == &"smash")

	root.remove_child(boar)
	boar.queue_free()
	await process_frame

	var player := CharacterBody2D.new()
	player.name = "Player"
	player.global_position = Vector2(420, 0)
	root.add_child(player)

	var chasing_boar = packed_scene.instantiate()
	chasing_boar.global_position = Vector2.ZERO
	chasing_boar.smash_range = 120.0
	root.add_child(chasing_boar)
	await process_frame
	await physics_frame
	chasing_boar.get_node("StateMachine/Idle").wait_time = 0.01
	chasing_boar.get_node("StateMachine/Telegraph").telegraph_time = 0.2
	chasing_boar.state_machine.change_state(&"Idle")
	for _frame in 6:
		await physics_frame
	assert(chasing_boar.current_state_name() == &"Recover")
	assert(chasing_boar.walk_direction == Vector2.RIGHT)
	assert(chasing_boar.sprite.animation == &"walk")

	for _frame in 10:
		await physics_frame
	assert(chasing_boar.current_state_name() == &"Recover")
	player.global_position = chasing_boar.global_position + Vector2(60, 0)
	for _frame in 4:
		await physics_frame
	assert(chasing_boar.current_state_name() == &"Telegraph")
	assert(chasing_boar.last_record.direction == Vector2.RIGHT)

	print("BOAR_MONSTER_CHECK_OK")
	root.remove_child(chasing_boar)
	chasing_boar.queue_free()
	root.remove_child(player)
	player.queue_free()
	await process_frame
	quit(0)

func _assert_smash_hitbox_reaches_floor_break_sensor(boar: BoarMonster) -> void:
	var attack_shape := boar.get_node("AttackHitbox/CollisionShape2D").shape as RectangleShape2D
	var attack_hitbox := boar.get_node("AttackHitbox") as Area2D
	assert(attack_hitbox.collision_layer & 4)
	assert(attack_shape.size.y >= 96.0)
	var top_left := attack_hitbox.position - attack_shape.size * 0.5
	var bottom_right := attack_hitbox.position + attack_shape.size * 0.5
	var floor_sensor_top := -18.0
	var floor_sensor_bottom := 50.0
	assert(top_left.y <= floor_sensor_bottom)
	assert(bottom_right.y >= floor_sensor_top)
