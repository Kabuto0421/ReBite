# 2026-06-13: SkullMonsterの記憶タグ受付時間。
extends "res://scripts/core/State.gd"

@export var recover_time := 1.0
var timer := 0.0

func enter(_payload: Variant = null) -> void:
	timer = recover_time
	owner_node.velocity.x = 0.0
	owner_node.play_animation(&"idle")

func physics_update(delta: float) -> void:
	timer -= delta
	if owner_node.memory_tag.has_method("set_window_progress"):
		owner_node.memory_tag.set_window_progress(timer / recover_time)
	owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	if timer <= 0.0:
		if owner_node.last_record != null and owner_node.last_record.direction.x < 0.0:
			transition_requested.emit(&"RightDash", null)
		else:
			owner_node.memory_tag.hide_tag()
			owner_node.prepare_dash_record(Vector2.LEFT)
			transition_requested.emit(&"Idle", null)
