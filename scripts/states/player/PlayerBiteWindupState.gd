# 2026-06-13: 噛み入力直後の短い溜め状態。
extends "res://scripts/core/State.gd"

@export var windup_time := 0.08
var timer := 0.0

func enter(_payload: Variant = null) -> void:
	timer = windup_time
	owner_node.velocity.x *= 0.25
	owner_node.play_animation(&"bite")

func physics_update(delta: float) -> void:
	timer -= delta
	owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	if timer <= 0.0:
		transition_requested.emit(&"BiteLunge", null)
