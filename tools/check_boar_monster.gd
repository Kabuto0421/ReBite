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

	var committed_record: Resource = boar.last_record
	boar.commit_smash_record(committed_record)
	boar.state_machine.change_state(&"Recover")
	assert(boar.is_biteable())
	assert(boar.memory_tag.visible)
	assert(boar.sprite.animation == &"walk")

	boar.recall_start_delay = 0.0
	boar.receive_committed_bite(null, committed_record)
	assert(boar.current_state_name() == &"Recalled")
	for i in 32:
		await physics_frame
	assert(boar.current_action_record() == committed_record)
	assert(is_equal_approx(boar.velocity.x, committed_record.velocity.x))
	assert(boar.sprite.animation == &"smash")

	print("BOAR_MONSTER_CHECK_OK")
	root.remove_child(boar)
	boar.queue_free()
	await process_frame
	quit(0)
