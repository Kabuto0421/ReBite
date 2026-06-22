# 2026-06-13: GoalAreaを置いたステージが自動でクリアすることを確認する。
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
	var goal = scene.get_node("GoalArea")
	assert(scene.goal_area == goal)
	assert(not scene.stage_cleared)

	player.global_position = goal.get_hitbox_rect_global().get_center()
	player.velocity = Vector2.ZERO
	await _settle_frames(3)
	assert(scene.stage_cleared)

	print("GOAL_STAGE_AUTO_CLEAR_CHECK_OK")
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit(0)

func _settle_frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame
