# 2026-06-22: BossBoarが主人公へ近づいて攻撃を選ぶ状態。
extends "res://scripts/core/State.gd"

@export var decision_time := 0.55 # 攻撃判断まで追跡する時間。
var timer := 0.0 # 判断までの残り時間。

func enter(_payload: Variant = null) -> void:
	timer = decision_time
	owner_node.memory_tag.hide_tag()
	owner_node.play_animation(&"walk")

func physics_update(delta: float) -> void:
	timer -= delta
	if owner_node.player != null:
		var direction := Vector2.RIGHT if owner_node.player.global_position.x > owner_node.global_position.x else Vector2.LEFT
		owner_node.set_facing_direction(direction)
		owner_node.velocity.x = direction.x * owner_node.chase_speed
	owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	if timer <= 0.0:
		var request: RefCounted = owner_node.choose_natural_action()
		var next_state := &"DashTelegraph" if request.action_id == &"dash" else &"SmashTelegraph"
		transition_requested.emit(next_state, request)

func exit() -> void:
	owner_node.velocity.x = 0.0
