# 2026-06-22: 固定方向へ曲がらず直進するBossBoarのDASH状態。
extends "res://scripts/core/State.gd"

var timer := 0.0 # DASH残り時間。
var request: RefCounted # 固定方向と発生源。
var record: Resource # 地形へ渡す実行中記録。

func enter(payload: Variant = null) -> void:
	request = payload as RefCounted
	timer = owner_node.dash_duration
	record = owner_node.begin_attack(request)
	owner_node.set_attack_hitbox_active(true)
	owner_node.play_animation(&"dash")

func physics_update(delta: float) -> void:
	timer -= delta
	owner_node.velocity.x = request.direction.x * owner_node.dash_speed
	owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	if timer <= 0.0 or owner_node.is_on_wall():
		transition_requested.emit(&"AttackRecovery", request)

func exit() -> void:
	owner_node.velocity.x = 0.0
	owner_node.finish_attack(request)
