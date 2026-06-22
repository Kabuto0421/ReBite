# 2026-06-14: Stage6の基本構成を確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage5: PackedScene = load("res://stage/Stage5.tscn")
	var stage5_scene: Node = stage5.instantiate()
	assert(stage5_scene.next_stage_path == "res://stage/Stage6.tscn")
	stage5_scene.queue_free()

	var packed_scene: PackedScene = load("res://stage/Stage6.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame

	for path in [
		"Player",
		"HopMonster",
		"RidePlatform",
		"SkullMonsterA",
		"SkullMonsterB",
		"SkullMonsterC",
		"GoalArea",
		"EditableGeometry/NormalTileGroups",
		"EditableGeometry/ActionBreakGroups/ActionBreakGroup_GateA",
		"EditableGeometry/ActionBreakGroups/ActionBreakGroup_GateB",
		"EditableGeometry/ActionBreakGroups/ActionBreakGroup_GateC",
	]:
		assert(scene.has_node(path))

	for group_name in ["ActionBreakGroup_GateA", "ActionBreakGroup_GateB", "ActionBreakGroup_GateC"]:
		var group := scene.get_node("EditableGeometry/ActionBreakGroups/%s" % group_name)
		assert(group.accepted_actions.has(&"dash"))
		assert(group.blocks_enemy)
		assert(group.get_tile_rects().size() == 2)

	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	print("STAGE6_LAYOUT_CHECK_OK")
	quit(0)
