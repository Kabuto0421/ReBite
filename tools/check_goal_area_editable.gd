# 2026-06-13: ゴール領域の編集用設定を確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed_scene: PackedScene = load("res://stage/Stage4.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame

	var goal = scene.get_node("GoalArea")
	var shape_node := goal.get_node("CollisionShape2D") as CollisionShape2D
	var label := goal.get_node("GoalLabel") as Label

	goal.hitbox_offset = Vector2(12, -48)
	goal.hitbox_size = Vector2(72, 40)
	goal.label_text = "EXIT"
	await process_frame

	assert(shape_node.position == Vector2(48, -28))
	assert((shape_node.shape as RectangleShape2D).size == Vector2(72, 40))
	assert(goal.get_hitbox_rect_global() == Rect2(goal.global_position + Vector2(12, -48), Vector2(72, 40)))
	assert(label.text == "EXIT")
	assert(label.offset_left == 12.0)
	assert(label.offset_right == 84.0)

	print("GOAL_AREA_EDITABLE_CHECK_OK")
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit(0)
