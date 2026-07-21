# 2026-07-21: Stage9の三層Boar搬送と中層Rockfall連携を確認する。
extends SceneTree

const ActionRecordScript := preload("res://scripts/core/ActionRecord.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://stage/Stage9.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	var boar_top: Node = scene.get_node("BoarTop")
	var boar_middle: Node = scene.get_node("BoarMiddle")
	var boar_bottom: Node = scene.get_node("BoarBottom")
	var top_drop: Node = scene.get_node("EditableGeometry/ActionBreakGroups/ActionBreakGroup_TopDrop")
	var middle_drop: Node = scene.get_node("EditableGeometry/ActionBreakGroups/ActionBreakGroup_MiddleDrop")
	var bottom_drop: Node = scene.get_node("EditableGeometry/ActionBreakGroups/ActionBreakGroup_BottomDrop")
	var rock: Node = scene.get_node("Rockfall_Middle")
	var skull_rock_target_a: Node2D = scene.get_node("SkullRockTargetA")
	var skull_rock_target_b: Node2D = scene.get_node("SkullRockTargetB")
	var hitbox_shape := boar_middle.get_node("AttackHitbox/CollisionShape2D").shape as RectangleShape2D

	assert(scene.get_script().resource_path.ends_with("Stage9.gd"))
	assert(scene.goal_area == null)
	assert(boar_top is BoarMonster)
	assert(boar_middle is BoarMonster)
	assert(boar_bottom is BoarMonster)
	assert(rock is Rockfall)
	for boar in [boar_top, boar_middle, boar_bottom]:
		assert(boar.is_patrol_carrier())
		assert(boar.patrol_route_open)
		assert(boar.patrol_target_id == &"A")

	assert(boar_top.patrol_smash_point == Vector2(423, 192))
	assert(boar_middle.patrol_smash_point == Vector2(600, 416))
	assert(boar_bottom.patrol_smash_point == Vector2(600, 640))
	assert(boar_top.patrol_smash_target_path == NodePath("../TauntStake_TopA"))
	assert(boar_middle.patrol_smash_target_path == NodePath("../TauntStake_MiddleA"))
	assert(boar_bottom.patrol_smash_target_path == NodePath("../TauntStake_BottomA"))
	assert(skull_rock_target_a.global_position.x >= 1600.0)
	assert(skull_rock_target_b.global_position.x >= 1700.0)
	assert(not boar_top.memory_tag_urgency_enabled)
	assert(not boar_middle.memory_tag_urgency_enabled)
	assert(not boar_bottom.memory_tag_urgency_enabled)
	assert(hitbox_shape.size.y >= 68.0)
	assert(boar_middle.attack_hitbox.position.y > -20.0)
	assert(top_drop.accepted_actions == [&"smash"])
	assert(middle_drop.accepted_actions == [&"smash"])
	assert(bottom_drop.accepted_actions == [&"smash"])
	assert(is_equal_approx(top_drop.direction_dot_threshold, 0.0))
	assert(is_equal_approx(middle_drop.direction_dot_threshold, 0.0))
	assert(is_equal_approx(bottom_drop.direction_dot_threshold, 0.0))

	_assert_routes_to_branch(boar_top)
	_assert_routes_to_branch(boar_middle)
	_assert_routes_to_branch(boar_bottom)
	_assert_target_smash_direction(boar_top, Vector2.RIGHT)
	_assert_target_smash_direction(boar_middle, Vector2.RIGHT)
	_assert_target_smash_direction(boar_bottom, Vector2.LEFT)
	_assert_drop_breaks(boar_top, top_drop, Vector2.RIGHT)
	_assert_drop_breaks(boar_middle, middle_drop, Vector2.RIGHT)
	_assert_drop_breaks(boar_bottom, bottom_drop, Vector2.LEFT)
	await _assert_attack_hitbox_overlaps_break_sensor(boar_top, top_drop)
	await _assert_runtime_drop_breaks(boar_top, top_drop, Vector2.RIGHT)

	var smash_record: Resource = ActionRecordScript.new(&"smash", Vector2.RIGHT, Vector2.RIGHT * boar_middle.smash_speed, 0.2, &"REBITE_REPLAY")
	boar_middle.set_active_action_record(smash_record)
	assert(rock.receive_memory_action_push(boar_middle, smash_record))
	assert(rock.linear_velocity.x > 0.0)
	boar_middle.clear_active_action_record(smash_record)

	print("STAGE9_MEMORY_CARRIER_CHECK_OK")
	scene.queue_free()
	await process_frame
	quit(0)

func _assert_routes_to_branch(boar: BoarMonster) -> void:
	boar._set_patrol_target(&"B", boar.patrol_turn_point)
	boar.global_position = boar.patrol_turn_point
	assert(boar.update_patrol_route_after_move() == &"")
	assert(boar.patrol_target_id == &"C")
	boar.global_position = boar.patrol_branch_point
	assert(boar.update_patrol_route_after_move() == &"")
	assert(boar.patrol_waiting_at_branch)

func _assert_drop_breaks(boar: BoarMonster, drop_group: Node, direction: Vector2) -> void:
	var smash_record: Resource = ActionRecordScript.new(&"smash", direction, direction * boar.smash_speed, 0.2, &"REBITE_REPLAY")
	boar.set_active_action_record(smash_record)
	assert(drop_group._can_break_with(boar))
	boar.clear_active_action_record(smash_record)

func _assert_target_smash_direction(boar: BoarMonster, expected_direction: Vector2) -> void:
	var previous_position := boar.global_position
	boar.global_position = boar.patrol_smash_point
	var record: Resource = boar.build_autonomous_smash_record()
	assert(record.direction == expected_direction)
	boar.global_position = previous_position

func _assert_runtime_drop_breaks(boar: BoarMonster, drop_group: Node, direction: Vector2) -> void:
	drop_group.reset_group()
	boar.global_position = boar.patrol_branch_point
	await physics_frame
	assert(not drop_group.broken_state)
	var smash_record: Resource = ActionRecordScript.new(&"smash", direction, direction * boar.smash_speed, 0.2, &"REBITE_REPLAY")
	boar.set_active_action_record(smash_record)
	await physics_frame
	assert(drop_group.broken_state)
	boar.clear_active_action_record(smash_record)

func _assert_attack_hitbox_overlaps_break_sensor(boar: BoarMonster, drop_group: Node) -> void:
	drop_group.reset_group()
	boar.global_position = boar.patrol_branch_point
	boar.set_facing_direction(Vector2.RIGHT)
	boar.set_attack_hitbox_active(true)
	await physics_frame
	var sensor := drop_group.get_node("BreakSensor") as Area2D
	assert(sensor.get_overlapping_areas().has(boar.attack_hitbox))
	boar.set_attack_hitbox_active(false)
