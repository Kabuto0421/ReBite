# 2026-06-13: 突進前の予備動作状態。
extends "res://scripts/core/State.gd"

@export var telegraph_time := 0.35
var timer := 0.0

func enter(_payload: Variant = null) -> void:
	timer = telegraph_time
	owner_node.velocity.x = 0.0
	owner_node.play_animation(&"idle")

func physics_update(delta: float) -> void:
	timer -= delta
	owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	if timer <= 0.0:
		transition_requested.emit(&"Dash", owner_node.last_record)
