# 2026-06-13: 移動足場がプレイヤーを運ぶことを確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed_scene: PackedScene = load("res://stage/Stage4.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	var player = scene.get_node("Player")
	var hop = scene.get_node("HopMonster")
	var ride = scene.get_node("RidePlatform")
	player.global_position = ride.global_position + Vector2(ride.size.x * 0.5, 1.0)
	player.velocity = Vector2.ZERO
	await _settle_frames(12)

	var start_y: float = player.global_position.y
	hop.state_machine.change_state(&"Hop", null)
	await _settle_seconds(0.35)
	assert(player.global_position.y < start_y - 12.0)

	print("RIDE_PLATFORM_CARRIES_PLAYER_CHECK_OK")
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
