# 2026-06-29: Stage9の記憶搬送路とBoar巡回仕様を確認する。
extends SceneTree

const ActionRecordScript := preload("res://scripts/core/ActionRecord.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://stage/Stage9.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	var boar: Node = scene.get_node("BoarMonster")
	var latch: Node = scene.get_node("EditableGeometry/ActionBreakGroups/ActionBreakGroup_RouteLatch")
	var cracked_floor: Node = scene.get_node("EditableGeometry/ActionBreakGroups/ActionBreakGroup_CrackedFloorC")
	var skull: Node = scene.get_node("SkullMonster")

	assert(scene.get_script().resource_path.ends_with("Stage9.gd"))
	assert(scene.goal_area != null)
	assert(boar is BoarMonster)
	assert(boar.is_patrol_carrier())
	assert(boar.patrol_smash_point == Vector2(640, 288))
	assert(boar.patrol_turn_point == Vector2(980, 288))
	assert(boar.patrol_branch_point == Vector2(1190, 288))
	assert(boar.patrol_target_id == &"A")
	assert(not boar.patrol_route_open)
	assert(skull.initial_dash_memory == 2)
	assert(cracked_floor.accepted_actions == [&"smash"])
	assert(is_equal_approx(cracked_floor.direction_dot_threshold, 0.0))

	latch.broken.emit(skull, ActionRecordScript.new(&"dash", Vector2.RIGHT, Vector2.RIGHT * 260.0, 0.2, &"REPLAY"))
	assert(boar.patrol_route_open)

	boar.patrol_route_open = false
	boar._set_patrol_target(&"B", boar.patrol_turn_point)
	boar.global_position = boar.patrol_turn_point
	assert(boar.update_patrol_route_after_move() == &"")
	assert(boar.patrol_target_id == &"A")

	boar.patrol_route_open = true
	boar._set_patrol_target(&"B", boar.patrol_turn_point)
	boar.global_position = boar.patrol_turn_point
	assert(boar.update_patrol_route_after_move() == &"")
	assert(boar.patrol_target_id == &"C")

	boar.global_position = boar.patrol_branch_point
	assert(boar.update_patrol_route_after_move() == &"")
	assert(boar.patrol_waiting_at_branch)

	var smash_record: Resource = ActionRecordScript.new(&"smash", Vector2.LEFT, Vector2.LEFT * boar.smash_speed, 0.2, &"REBITE_REPLAY")
	boar.set_active_action_record(smash_record)
	assert(cracked_floor._can_break_with(boar))
	boar.clear_active_action_record(smash_record)

	print("STAGE9_MEMORY_CARRIER_CHECK_OK")
	scene.queue_free()
	await process_frame
	quit(0)
