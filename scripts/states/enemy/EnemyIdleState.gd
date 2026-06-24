# 2026-06-13: SkullMonsterの待機状態。
extends "res://scripts/core/State.gd"

@export var wait_time := 0.8
var timer := 0.0

func enter(_payload: Variant = null) -> void:
	timer = wait_time
	owner_node.velocity.x = 0.0
	owner_node.play_animation(&"idle")

func physics_update(delta: float) -> void:
	timer -= delta
	owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	if timer <= 0.0:
		transition_requested.emit(&"Telegraph", owner_node.build_natural_dash_record())
