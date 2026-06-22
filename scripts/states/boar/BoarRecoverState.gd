# 2026-06-21: BoarMonsterがSMASH記憶を保持して歩く状態。
extends "res://scripts/core/State.gd"

@export var memory_walk_time := 3.2 # タグを噛めるまま歩き続ける時間。

var timer := 0.0 # 記憶歩行の残り時間。

# タグを維持したまま歩行アニメーションへ入る。
func enter(_payload: Variant = null) -> void:
	timer = memory_walk_time
	owner_node.set_facing_direction(owner_node.walk_direction)
	owner_node.play_animation(&"walk")

# 壁で反転しながら歩き、時間切れなら次の自律SMASHへ戻る。
func physics_update(delta: float) -> void:
	timer -= delta
	if owner_node.memory_tag.has_method("set_window_progress"):
		owner_node.memory_tag.set_window_progress(timer / memory_walk_time)
	owner_node.apply_gravity(delta)
	owner_node.velocity.x = owner_node.walk_direction.x * owner_node.walk_speed
	owner_node.move_and_slide()
	if owner_node.is_on_wall():
		owner_node.reverse_walk_direction()
	if timer <= 0.0:
		owner_node.memory_tag.hide_tag()
		owner_node.prepare_smash_record(owner_node.walk_direction)
		transition_requested.emit(&"Idle", null)

# 噛み再演へ抜ける時に歩行速度を残さない。
func exit() -> void:
	owner_node.velocity.x = 0.0
