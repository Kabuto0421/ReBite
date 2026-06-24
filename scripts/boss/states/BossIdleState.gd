# 2026-06-22: BossBoarが次の追跡開始を待つ状態。
extends "res://scripts/core/State.gd"

@export var wait_time := 0.35 # 待機時間。
var timer := 0.0 # 残り待機時間。

func enter(_payload: Variant = null) -> void:
	timer = wait_time
	owner_node.velocity.x = 0.0
	owner_node.memory_tag.hide_tag()
	owner_node.play_animation(&"idle")

func physics_update(delta: float) -> void:
	timer -= delta
	owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	if timer <= 0.0:
		transition_requested.emit(&"Chase", null)
