# 2026-06-13: HopMonsterの落下復帰状態。
extends "res://scripts/core/State.gd"

func enter(_payload: Variant = null) -> void:
	owner_node.velocity.x = 0.0
	owner_node.memory_tag.hide_tag()
	owner_node.play_animation(&"idle")

func physics_update(delta: float) -> void:
	owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	if owner_node.is_on_floor():
		owner_node.prepare_hop_record()
		transition_requested.emit(&"Idle", null)
