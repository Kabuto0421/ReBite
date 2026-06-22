# 2026-06-21: BoarMonsterが次のSMASHを待つ状態。
extends "res://scripts/core/State.gd"

@export var wait_time := 0.7 # 次の予備動作へ入るまでの待機時間。

var timer := 0.0 # 待機の残り時間。

# 速度を止め、初期待機アニメーションへ入る。
func enter(_payload: Variant = null) -> void:
	timer = wait_time
	owner_node.velocity.x = 0.0
	owner_node.memory_tag.hide_tag()
	owner_node.set_facing_direction(owner_node.walk_direction)
	owner_node.play_animation(&"idle")

# 重力を適用しながら予備動作への遷移を待つ。
func physics_update(delta: float) -> void:
	timer -= delta
	owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	if timer <= 0.0:
		transition_requested.emit(&"Telegraph", owner_node.last_record)
