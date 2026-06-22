# 2026-06-13: Stage5の連鎖破壊構成を確認する。
extends SceneTree

const ActionRecordScript := preload("res://scripts/core/ActionRecord.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed_scene: PackedScene = load("res://stage/Stage5.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	assert(scene.has_node("EditableGeometry/NormalTileGroups"))
	assert(scene.has_node("EditableGeometry/ActionBreakGroups"))
	var break_group := scene.get_node("EditableGeometry/ActionBreakGroups/ActionBreakGroup_SkullFloor")
	var rects: Array[Rect2] = break_group.get_tile_rects()
	assert(rects.size() == 3)
	assert(break_group.accepted_actions.has(&"jump"))
	assert(break_group.blocks_enemy)

	var skull_count := 0
	for child in scene.get_children():
		if child.name.begins_with("SkullMonster"):
			skull_count += 1
	assert(skull_count >= 5)

	var hop := scene.get_node("HopMonster")
	var record := ActionRecordScript.new(&"jump", Vector2.UP, Vector2.ZERO, 0.42)
	var hop_target := _first_rect_center_global(break_group)
	hop.global_position = hop_target + Vector2.DOWN * 120.0
	hop.set_active_action_record(record)
	assert(break_group._can_break_with(hop))
	break_group._on_break_area_body_entered(hop)
	assert(break_group.broken_state)
	assert(not break_group.get_node("GeneratedTiles").visible)

	var second_wall := scene.get_node("EditableGeometry/ActionBreakGroups/ActionBreakGroup_SecondWall")
	assert(second_wall.get_tile_rects().size() > 0)
	assert(second_wall.accepted_actions.has(&"dash"))
	var fake_enemy := _FakeDashEnemy.new()
	fake_enemy.name = "FakeDashEnemy"
	var dash_target := _first_rect_center_global(second_wall)
	fake_enemy.global_position = dash_target + Vector2.RIGHT * 160.0
	var dash_record := ActionRecordScript.new(&"dash", Vector2.LEFT, Vector2(-260.0, 0.0), 0.34)
	fake_enemy.set_active_action_record(dash_record)
	assert(second_wall._can_break_with(fake_enemy))
	fake_enemy.queue_free()

	print("STAGE5_CHAIN_BREAK_CHECK_OK")
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit(0)

func _first_rect_center_global(group: Node2D) -> Vector2:
	var rects: Array[Rect2] = group.get_tile_rects()
	assert(rects.size() > 0)
	return group.to_global(rects[0].position + rects[0].size * 0.5)

class _FakeDashEnemy:
	extends Node2D

	var record: Resource

	func set_active_action_record(action_record: Resource) -> void:
		record = action_record

	func current_action_record() -> Resource:
		return record
