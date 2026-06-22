# 2026-06-13: HopMonsterの記憶タグ受付時間。
extends "res://scripts/core/State.gd"

@export var recover_time := 1.0
var timer := 0.0

func enter(_payload: Variant = null) -> void:
	timer = recover_time
	owner_node.velocity.x = 0.0
	owner_node.play_animation(&"idle")

func physics_update(delta: float) -> void:
	timer -= delta
	if owner_node.memory_tag.has_method("set_window_progress") and recover_time > 0.0:
		owner_node.memory_tag.set_window_progress(timer / recover_time)
	owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	if timer <= 0.0:
		owner_node.memory_tag.hide_tag()
		owner_node.prepare_hop_record()
		if owner_node.is_on_floor():
			transition_requested.emit(&"Idle", null)
		else:
			transition_requested.emit(&"Fall", null)
