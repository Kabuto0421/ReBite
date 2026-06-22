# 2026-06-13: 共通キャラクター基盤とSkullの待機動作を確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed_scene: PackedScene = load("res://entities/SkullMonster.tscn")
	var skull = packed_scene.instantiate()
	root.add_child(skull)
	await process_frame
	await physics_frame

	assert(skull.has_method("remember_spawn_position"))
	assert(skull.has_method("apply_gravity"))
	assert(skull.sprite.sprite_frames.has_animation(&"idle"))
	assert(skull.sprite.sprite_frames.get_frame_count(&"idle") == 4)
	assert(skull.sprite.sprite_frames.get_animation_loop(&"idle"))
	assert(is_equal_approx(skull.sprite.sprite_frames.get_animation_speed(&"idle"), 4.0))
	assert(skull.current_state_name() == &"Idle")

	print("CHARACTER_BASE_AND_SKULL_IDLE_CHECK_OK")
	root.remove_child(skull)
	skull.queue_free()
	await process_frame
	quit(0)
