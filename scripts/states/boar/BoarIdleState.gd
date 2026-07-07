# 2026-06-21: BoarMonsterが射程内SMASHか接近歩行を選ぶ状態。
extends "res://scripts/core/State.gd"

@export var wait_time := 0.7 # 次の予備動作へ入るまでの待機時間。

var timer := 0.0 # 待機の残り時間。

# 速度を止め、射程確認の待機アニメーションへ入る。
func enter(_payload: Variant = null) -> void:
	timer = wait_time
	owner_node.velocity.x = 0.0
	if not owner_node.memory_tag.visible:
		owner_node.memory_tag.hide_tag()
	owner_node.set_facing_direction(owner_node.walk_direction)
	owner_node.play_animation(&"idle")

# 重力を適用し、近ければSMASH、遠ければ歩行へ遷移する。
func physics_update(delta: float) -> void:
	timer -= delta
	owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	if timer <= 0.0:
		if owner_node.is_patrol_carrier():
			if owner_node.can_start_patrol_smash():
				transition_requested.emit(&"Telegraph", owner_node.build_autonomous_smash_record())
			else:
				transition_requested.emit(&"Recover", null)
		elif owner_node.is_player_in_smash_range():
			transition_requested.emit(&"Telegraph", owner_node.build_autonomous_smash_record())
		else:
			owner_node.face_player()
			transition_requested.emit(&"Recover", null)
