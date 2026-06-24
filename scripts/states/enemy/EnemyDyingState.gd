# 2026-06-13: 敵の死亡アニメーションと死亡通知。
extends "res://scripts/core/State.gd"

@export var death_time := 0.65
var timer := 0.0

func enter(_payload: Variant = null) -> void:
	timer = death_time
	owner_node.velocity = Vector2.ZERO
	owner_node.clear_active_action_record()
	owner_node.set_attack_hitbox_active(false)
	owner_node.set_replay_outline_active(false)
	owner_node.memory_tag.hide_tag()
	if owner_node.last_record != null:
		owner_node.last_record.is_available = false
	var death_sound: StringName = &"enemy_die"
	if owner_node.has_method("death_sfx_name"):
		death_sound = StringName(owner_node.death_sfx_name())
	if death_sound != &"":
		_play_stage_sfx(death_sound)
	owner_node.spawn_death_burst()
	owner_node.play_animation(&"dead")
	owner_node.sprite.set_frame_and_progress(0, 0.0)

func physics_update(delta: float) -> void:
	timer -= delta
	if timer <= 0.0:
		owner_node.died.emit()
		owner_node.queue_free()

func _play_stage_sfx(sound_name: StringName) -> void:
	var root := owner_node.get_tree().current_scene
	if root != null and root.has_method("play_sfx"):
		root.play_sfx(sound_name)
