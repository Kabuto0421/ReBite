# 2026-06-21: BoarMonsterがSMASH記憶を保持し、Playerへ歩く状態。
extends "res://scripts/core/State.gd"

@export var memory_walk_time := 3.2 # タグを噛めるまま歩き続ける時間。

var timer := 0.0 # 記憶歩行の残り時間。

# タグを維持したまま歩行アニメーションへ入る。
func enter(_payload: Variant = null) -> void:
	timer = memory_walk_time
	owner_node.set_facing_direction(owner_node.walk_direction)
	owner_node.play_animation(&"walk")

# Playerへ歩き、射程内なら次の自律SMASHへ戻る。
func physics_update(delta: float) -> void:
	timer -= delta
	if owner_node.has_method("should_update_memory_tag_urgency") and owner_node.should_update_memory_tag_urgency() and owner_node.memory_tag.has_method("set_window_progress"):
		owner_node.memory_tag.set_window_progress(timer / memory_walk_time)
	owner_node.apply_gravity(delta)
	if owner_node.is_patrol_carrier():
		owner_node.face_patrol_target()
	else:
		owner_node.face_player()
	owner_node.velocity.x = owner_node.walk_direction.x * owner_node.walk_speed
	if owner_node.is_patrol_carrier() and owner_node.patrol_waiting_at_branch:
		owner_node.velocity.x = 0.0
	owner_node.move_and_slide()
	if owner_node.is_on_wall():
		owner_node.reverse_walk_direction()
	if owner_node.is_patrol_carrier():
		var next_state: StringName = owner_node.update_patrol_route_after_move()
		if next_state != &"":
			owner_node.memory_tag.hide_tag()
			transition_requested.emit(next_state, null)
	elif owner_node.is_player_in_smash_range():
		owner_node.memory_tag.hide_tag()
		transition_requested.emit(&"Telegraph", owner_node.build_autonomous_smash_record())
	elif timer <= 0.0:
		timer = memory_walk_time

# 噛み再演へ抜ける時に歩行速度を残さない。
func exit() -> void:
	owner_node.velocity.x = 0.0
