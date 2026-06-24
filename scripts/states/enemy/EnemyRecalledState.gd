# 2026-06-13: 噛まれた突進記憶を再演する状態。
extends "res://scripts/core/State.gd"

var start_delay := 0.0
var replay_started := false
var record: Resource
var start_x := 0.0

func enter(payload: Variant = null) -> void:
	record = payload as Resource
	start_delay = owner_node.recall_start_delay
	replay_started = false
	start_x = owner_node.global_position.x
	owner_node.velocity = Vector2.ZERO
	owner_node.set_attack_hitbox_active(false)
	owner_node.pause_animation()
	if owner_node.has_method("set_attack_warning_active"):
		owner_node.set_attack_warning_active(false)

func physics_update(delta: float) -> void:
	if start_delay > 0.0:
		start_delay -= delta
		owner_node.velocity = Vector2.ZERO
		owner_node.move_and_slide()
		return

	if not replay_started:
		replay_started = true
		owner_node.set_replay_outline_active(true)
		if owner_node.has_method("set_dash_direction_visual") and record != null:
			owner_node.set_dash_direction_visual(record.direction)
		if owner_node.has_method("set_attack_warning_active"):
			owner_node.set_attack_warning_active(false)
		owner_node.set_active_action_record(record)
		owner_node.set_attack_hitbox_active(true)
		owner_node.play_animation(&"dash")
		if owner_node.has_method("play_replay_launch_feedback") and record != null:
			owner_node.play_replay_launch_feedback(record.direction)
		_play_stage_sfx(&"enemy_replay_start")

	owner_node.apply_gravity(delta)
	if record != null:
		var remaining: float = maxf(0.0, record.distance - absf(owner_node.global_position.x - start_x))
		owner_node.velocity.x = signf(record.velocity.x) * minf(absf(record.velocity.x), remaining / maxf(delta, 0.0001))
	owner_node.move_and_slide()
	if record != null and absf(owner_node.global_position.x - start_x) >= record.distance - 0.5:
		owner_node.set_attack_hitbox_active(false)
		owner_node.commit_dash_record(record.direction, &"REPLAY", true)
		transition_requested.emit(&"Recover", null)
	elif owner_node.is_on_wall():
		owner_node.set_attack_hitbox_active(false)
		owner_node.last_record = null
		owner_node.memory_tag.hide_tag()
		owner_node.handle_blocked_dash(record.direction)
		transition_requested.emit(&"Recover", {"blocked": true})

func exit() -> void:
	if owner_node.has_method("set_attack_warning_active"):
		owner_node.set_attack_warning_active(false)
	if owner_node.has_method("set_replay_outline_active"):
		owner_node.set_replay_outline_active(false)
	owner_node.clear_active_action_record(record)
	owner_node.set_attack_hitbox_active(false)

func _play_stage_sfx(sound_name: StringName) -> void:
	var root := owner_node.get_tree().current_scene
	if root != null and root.has_method("play_sfx"):
		root.play_sfx(sound_name)
