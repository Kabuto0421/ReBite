# 2026-06-22: 正面攻撃と短い衝撃波を出すBossBoarのSMASH状態。
extends "res://scripts/core/State.gd"

var timer := 0.0 # SMASH残り時間。
var request: RefCounted # 固定方向と発生源。
var impact_active := false # 現在攻撃判定中か。

func enter(payload: Variant = null) -> void:
	request = payload as RefCounted
	timer = owner_node.smash_duration
	impact_active = false
	owner_node.begin_attack(request)
	owner_node.play_animation(&"smash")
	owner_node.sprite.set_frame_and_progress(0, 0.0)

func physics_update(delta: float) -> void:
	timer -= delta
	var elapsed: float = owner_node.smash_duration - maxf(timer, 0.0)
	var next_impact: bool = owner_node.is_smash_impact_active(elapsed)
	if next_impact != impact_active:
		impact_active = next_impact
		owner_node.set_attack_hitbox_active(impact_active)
		owner_node.set_shockwave_active(impact_active)
		if impact_active:
			owner_node.notify_smash_impact_started(request)
	owner_node.velocity.x = request.direction.x * owner_node.smash_speed if impact_active else 0.0
	owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	if timer <= 0.0:
		transition_requested.emit(&"AttackRecovery", request)

func exit() -> void:
	owner_node.velocity.x = 0.0
	owner_node.finish_attack(request)
