# 2026-06-13: HopMonsterの通常跳躍状態。
extends "res://scripts/core/State.gd"

@export var memory_delay := 0.38
var timer := 0.0
var launch_frame_pending := false

func enter(_payload: Variant = null) -> void:
	timer = memory_delay
	launch_frame_pending = true
	owner_node.prepare_hop_record()
	owner_node.velocity = owner_node.last_record.velocity
	owner_node.set_active_action_record(owner_node.last_record)
	owner_node.set_attack_hitbox_active(true)
	owner_node.play_animation(&"hop")
	_play_stage_sfx(&"hop_launch")

func exit() -> void:
	owner_node.clear_active_action_record()
	owner_node.set_attack_hitbox_active(false)

func physics_update(delta: float) -> void:
	timer -= delta
	if launch_frame_pending:
		launch_frame_pending = false
	else:
		owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	if timer <= 0.0:
		owner_node.commit_hop_record()
		transition_requested.emit(&"Recover", null)

func _play_stage_sfx(sound_name: StringName) -> void:
	var root := owner_node.get_tree().current_scene
	if root != null and root.has_method("play_sfx"):
		root.play_sfx(sound_name)
