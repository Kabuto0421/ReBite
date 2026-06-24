# 2026-06-13: 突進前の予備動作状態。
extends "res://scripts/core/State.gd"

@export var telegraph_time := 0.35
var timer := 0.0
var record: Resource

func enter(payload: Variant = null) -> void:
	record = payload as Resource
	if record == null:
		record = owner_node.build_natural_dash_record()
	timer = telegraph_time
	owner_node.velocity.x = 0.0
	if owner_node.has_method("set_dash_direction_visual"):
		owner_node.set_dash_direction_visual(record.direction)
	owner_node.play_animation(&"telegraph")
	owner_node.sprite.set_frame_and_progress(0, 0.0)
	if owner_node.has_method("set_attack_warning_active"):
		owner_node.set_attack_warning_active(true)

func exit() -> void:
	if owner_node.has_method("set_attack_warning_active"):
		owner_node.set_attack_warning_active(false)

func physics_update(delta: float) -> void:
	timer -= delta
	owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	if timer <= 0.0:
		transition_requested.emit(&"RightDash" if record.direction.x > 0.0 else &"Dash", record)
