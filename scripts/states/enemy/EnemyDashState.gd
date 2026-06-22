# 2026-06-13: SkullMonsterの左突進状態。
extends "res://scripts/core/State.gd"

var timer := 0.0
var record: Resource

func enter(payload: Variant = null) -> void:
	record = payload as Resource
	if record == null:
		record = owner_node.last_record
	timer = record.duration
	owner_node.set_active_action_record(record)
	owner_node.set_attack_hitbox_active(true)
	owner_node.play_animation(&"dash")
	_play_stage_sfx(&"skull_dash")

func exit() -> void:
	owner_node.clear_active_action_record(record)
	owner_node.set_attack_hitbox_active(false)

func physics_update(delta: float) -> void:
	timer -= delta
	owner_node.apply_gravity(delta)
	owner_node.velocity.x = record.velocity.x
	owner_node.move_and_slide()
	if timer <= 0.0 or owner_node.is_on_wall():
		owner_node.commit_dash_record(record.direction)
		transition_requested.emit(&"Recover", null)

func _play_stage_sfx(sound_name: StringName) -> void:
	var root := owner_node.get_tree().current_scene
	if root != null and root.has_method("play_sfx"):
		root.play_sfx(sound_name)
