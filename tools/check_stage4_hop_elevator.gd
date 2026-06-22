# 2026-06-13: Stage4のHop足場ギミックを確認する。
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
	var hop2 = scene.get_node("HopMonster2")
	var ride2 = scene.get_node("RidePlatform2")
	var goal = scene.get_node("GoalArea")

	assert(ride.global_position == hop.global_position + ride.offset)
	assert(ride2.global_position == hop2.global_position + ride2.offset)
	assert(ride.has_node("CollisionShape2D"))
	assert(ride2.has_node("CollisionShape2D"))
	var goal_rect: Rect2 = goal.get_hitbox_rect_global()
	assert(goal_rect.end.y < ride.global_position.y - 250.0)
	assert(not scene.stage_cleared)

	var initial_ride_y: float = ride.global_position.y
	hop.state_machine.change_state(&"Hop", null)
	await _settle_seconds(0.35)
	assert(ride.global_position.y < initial_ride_y - 24.0)
	assert(not scene.stage_cleared)

	await _settle_seconds(0.12)
	assert(hop.is_biteable())
	player.global_position = ride.global_position + Vector2(ride.size.x * 0.5, 1.0)
	player.velocity = Vector2.ZERO
	await _settle_frames(3)
	assert(player.pick_bite_target() == hop)

	player.state_machine.change_state(&"BiteLunge", null)
	await _settle_seconds(hop.recall_start_delay + 0.55)
	assert(not scene.stage_cleared)

	var initial_ride2_y: float = ride2.global_position.y
	hop2.state_machine.change_state(&"Hop", null)
	await _settle_seconds(0.35)
	assert(ride2.global_position.y < initial_ride2_y - 24.0)
	assert(not scene.stage_cleared)

	await _settle_seconds(0.12)
	assert(hop2.is_biteable())
	player.global_position = ride2.global_position + Vector2(ride2.size.x * 0.5, 1.0)
	player.velocity = Vector2.ZERO
	await _settle_frames(3)
	assert(player.pick_bite_target() == hop2)

	player.state_machine.change_state(&"BiteLunge", null)
	await _settle_seconds(0.24)
	assert(not scene.stage_cleared)
	var before_second_replay_y: float = player.global_position.y
	await _settle_seconds(hop2.recall_start_delay + 0.75)
	assert(player.global_position.y < before_second_replay_y - 24.0)

	print("STAGE4_HOP_ELEVATOR_CHECK_OK")
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
