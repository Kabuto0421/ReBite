# 2026-06-13: 噛み後の硬直から通常操作へ戻す状態。
extends "res://scripts/core/State.gd"

@export var recover_time := 0.14
var timer := 0.0

func enter(_payload: Variant = null) -> void:
	timer = recover_time

func physics_update(delta: float) -> void:
	timer -= delta
	owner_node.apply_gravity(delta)
	owner_node.velocity.x = move_toward(owner_node.velocity.x, 0.0, 900.0 * delta)
	owner_node.move_and_slide()

	if timer <= 0.0:
		if owner_node.is_on_floor():
			transition_requested.emit(&"Ground", null)
		else:
			transition_requested.emit(&"Air", null)
