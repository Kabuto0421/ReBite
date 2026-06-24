# 2026-06-13: 噛まれた跳躍記憶を再演する状態。
extends "res://scripts/core/State.gd"

var timer := 0.0
var start_delay := 0.0
var replay_started := false
var launch_frame_pending := false
var record: Resource

func enter(payload: Variant = null) -> void:
	record = payload as Resource
	if record == null:
		record = owner_node.last_record
	timer = record.duration if record != null else 0.42
	start_delay = owner_node.recall_start_delay
	replay_started = false
	launch_frame_pending = false
	owner_node.velocity = Vector2.ZERO
	owner_node.memory_tag.crack_tag()
	owner_node.play_animation(&"idle")
	owner_node.pause_animation()

func physics_update(delta: float) -> void:
	if start_delay > 0.0:
		start_delay -= delta
		owner_node.velocity = Vector2.ZERO
		owner_node.move_and_slide()
		return

	if not replay_started:
		replay_started = true
		owner_node.set_replay_outline_active(true)
		owner_node.resume_animation()
		owner_node.set_active_action_record(record)
		owner_node.set_attack_hitbox_active(true)
		owner_node.play_animation(&"hop")
		_play_stage_sfx(&"enemy_replay_start")
		_play_stage_sfx(&"hop_launch")
		if record != null:
			owner_node.velocity = owner_node.replay_hop_velocity(record)
		launch_frame_pending = true

	timer -= delta
	if launch_frame_pending:
		launch_frame_pending = false
	else:
		owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	if timer <= 0.0:
		owner_node.set_attack_hitbox_active(false)
		owner_node.memory_tag.hide_tag()
		owner_node.prepare_hop_record()
		transition_requested.emit(&"Fall", null)

func exit() -> void:
	owner_node.resume_animation()
	owner_node.set_replay_outline_active(false)
	owner_node.clear_active_action_record(record)
	owner_node.set_attack_hitbox_active(false)

func _play_stage_sfx(sound_name: StringName) -> void:
	var root := owner_node.get_tree().current_scene
	if root != null and root.has_method("play_sfx"):
		root.play_sfx(sound_name)
