# 2026-06-13: 行動破壊タイルの基本挙動を確認する。
extends SceneTree

const ActionBreakGroupScript := preload("res://scripts/stage/ActionBreakGroup.gd")
const ActionRecordScript := preload("res://scripts/core/ActionRecord.gd")
const TileRectPartScript := preload("res://scripts/stage/TileRectPart.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var group := ActionBreakGroupScript.new()
	_add_part(group, "Rect_Top", Vector2.ZERO, Vector2(96, 32))
	_add_part(group, "Rect_Side", Vector2(0, 32), Vector2(32, 96))
	root.add_child(group)
	await process_frame

	var collision := group.get_node("Collision") as StaticBody2D
	var sensor := group.get_node("BreakSensor") as Area2D
	assert(collision.collision_layer == 8)
	assert(sensor.collision_mask == 5)
	assert(collision.get_child_count() == 2)
	assert(sensor.get_child_count() == 2)

	var enemy := _FakeEnemy.new()
	enemy.global_position = Vector2(132, 16)
	enemy.record = ActionRecordScript.new(&"dash", Vector2.LEFT, Vector2(-220.0, 0.0), 0.3)
	assert(group._can_break_with(enemy))
	group._on_break_area_body_entered(enemy)
	assert(group.broken_state)
	assert(not group.get_node("GeneratedTiles").visible)

	print("ACTION_BREAK_GROUP_CHECK_OK")
	root.remove_child(group)
	group.queue_free()
	enemy.queue_free()

	var hop_group := ActionBreakGroupScript.new()
	hop_group.accepted_actions = [&"jump"]
	_add_part(hop_group, "Rect_Hop", Vector2.ZERO, Vector2(64, 64))
	root.add_child(hop_group)
	await process_frame

	var hop_enemy := _FakeEnemy.new()
	hop_enemy.global_position = Vector2(300, 300)
	hop_enemy.record = ActionRecordScript.new(&"jump", Vector2.UP, Vector2.ZERO, 0.42)
	assert(hop_group._can_break_with(hop_enemy))
	hop_group._on_break_area_body_entered(hop_enemy)
	assert(hop_group.broken_state)

	root.remove_child(hop_group)
	hop_group.queue_free()
	hop_enemy.queue_free()

	var floor_group := ActionBreakGroupScript.new()
	floor_group.accepted_actions = [&"dash"]
	_add_part(floor_group, "Rect_Floor", Vector2.ZERO, Vector2(160, 32))
	root.add_child(floor_group)
	await process_frame

	var floor_dash_enemy := _FakeEnemy.new()
	floor_dash_enemy.global_position = Vector2(80, -18)
	floor_dash_enemy.record = ActionRecordScript.new(&"dash", Vector2.LEFT, Vector2.ZERO, 0.3)
	assert(not floor_group._can_break_with(floor_dash_enemy))

	root.remove_child(floor_group)
	floor_group.queue_free()
	floor_dash_enemy.queue_free()

	var smash_floor_group := ActionBreakGroupScript.new()
	smash_floor_group.accepted_actions = [&"smash"]
	smash_floor_group.direction_dot_threshold = 0.0
	_add_part(smash_floor_group, "Rect_SmashFloor", Vector2.ZERO, Vector2(160, 32))
	root.add_child(smash_floor_group)
	await process_frame
	await physics_frame

	var smash_enemy := _FakeBodyEnemy.new()
	smash_enemy.global_position = Vector2(80, -18)
	root.add_child(smash_enemy)
	await process_frame
	await physics_frame
	assert(not smash_floor_group.broken_state)
	smash_enemy.record = ActionRecordScript.new(&"smash", Vector2.RIGHT, Vector2(120.0, 0.0), 0.3)
	await physics_frame
	assert(smash_floor_group.broken_state)

	root.remove_child(smash_floor_group)
	smash_floor_group.queue_free()
	root.remove_child(smash_enemy)
	smash_enemy.queue_free()
	await process_frame
	quit(0)

func _add_part(group: Node, part_name: String, part_position: Vector2, part_size: Vector2) -> void:
	var part := TileRectPartScript.new()
	part.name = part_name
	part.rect_name = part_name
	part.position = part_position
	part.size = part_size
	group.add_child(part)

class _FakeEnemy:
	extends Node2D

	var record: Resource

	func current_action_record() -> Resource:
		return record

class _FakeBodyEnemy:
	extends CharacterBody2D

	var record: Resource

	func _init() -> void:
		collision_layer = 4
		collision_mask = 0
		var shape_node := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(32, 48)
		shape_node.shape = shape
		add_child(shape_node)

	func current_action_record() -> Resource:
		return record
