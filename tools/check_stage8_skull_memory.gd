# 2026-06-24: Stage8の檻内SkullMonsterAがInspector指定の初期DASH記憶を保持することを確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://stage/Stage8.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame
	var skull: Node = scene.get_node("SkullMonsterA")
	assert(skull.initial_dash_memory == 1)
	assert(skull.dash_duration == 0.34)
	assert(skull.last_record != null)
	assert(skull.last_record.action_name == &"dash")
	assert(skull.last_record.direction == Vector2.LEFT)
	assert(skull.last_record.is_available)
	assert(skull.memory_tag.visible)

	var first_memory_id: int = skull.last_record.memory_id
	await _settle_seconds(2.2)
	assert(skull.last_record.memory_id > first_memory_id)
	assert(skull.last_record.direction == Vector2.RIGHT)
	assert(skull.last_record.is_available)
	assert(skull.memory_tag.visible)
	assert(skull.current_state_name() != &"Dying")

	print("STAGE8_SKULL_MEMORY_CHECK_OK")
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit(0)

func _settle_seconds(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await process_frame
		await physics_frame
		elapsed += 1.0 / 60.0
