# 2026-06-13: SkullMonsterが戻る右突進状態。
extends "res://scripts/core/State.gd"

var record: Resource
var start_x := 0.0

func enter(payload: Variant = null) -> void:
	record = payload as Resource
	if record == null:
		record = owner_node.build_natural_dash_record()
	start_x = owner_node.global_position.x
	owner_node.set_active_action_record(record)
	if owner_node.has_method("set_dash_direction_visual"):
		owner_node.set_dash_direction_visual(record.direction)
	owner_node.set_attack_hitbox_active(true)
	owner_node.play_animation(&"dash")
	_play_stage_sfx(&"skull_dash")

func exit() -> void:
	owner_node.clear_active_action_record(record)
	owner_node.set_attack_hitbox_active(false)

func physics_update(delta: float) -> void:
	owner_node.apply_gravity(delta)
	var remaining: float = maxf(0.0, record.distance - absf(owner_node.global_position.x - start_x))
	if owner_node.memory_tag.has_method("set_window_progress") and owner_node.memory_tag.is_available():
		owner_node.memory_tag.set_window_progress(remaining / maxf(record.distance, 0.001))
	owner_node.velocity.x = signf(record.velocity.x) * minf(absf(record.velocity.x), remaining / maxf(delta, 0.0001))
	owner_node.move_and_slide()
	if absf(owner_node.global_position.x - start_x) >= record.distance - 0.5:
		owner_node.commit_dash_record(record.direction, &"NATURAL")
		transition_requested.emit(&"Recover", null)
	elif owner_node.is_on_wall():
		owner_node.handle_blocked_dash(record)
		transition_requested.emit(&"Recover", {"blocked": true})

func _play_stage_sfx(sound_name: StringName) -> void:
	var root := owner_node.get_tree().current_scene
	if root != null and root.has_method("play_sfx"):
		root.play_sfx(sound_name)
