# 2026-06-13: 突進攻撃の当たり判定を確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed_scene: PackedScene = load("res://stage/Stage1.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	var player = scene.get_node("Player")
	var skull = scene.get_node("SkullMonster")
	var spawn: Vector2 = player.spawn_position

	player.global_position = skull.global_position
	await _settle_frames(3)
	assert(player.global_position.distance_to(spawn) > 8.0)

	skull.set_attack_hitbox_active(true)
	await _settle_frames(3)
	assert(player.is_dead)
	assert(player.current_state_name() == &"Dead")
	await _settle_seconds(1.05)
	assert(not player.is_dead)
	assert(player.current_state_name() != &"Dead")
	assert(abs(player.global_position.x - spawn.x) < 1.0)

	player.global_position = skull.global_position
	skull.set_attack_hitbox_active(false)
	skull.state_machine.change_state(&"Recover", null)
	await _settle_frames(3)
	assert(player.global_position.distance_to(spawn) > 8.0)

	print("DASH_HITBOX_CHECK_OK")
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
