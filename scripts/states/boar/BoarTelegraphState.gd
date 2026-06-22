# 2026-06-21: BoarMonsterがSMASH直前に構える状態。
extends "res://scripts/core/State.gd"

@export var telegraph_time := 0.3 # 構えを見せる時間。

var timer := 0.0 # 構えの残り時間。
var record: Resource # 次に実行するSMASH記録。

# SMASH先頭フレームで静止し、攻撃方向を予告する。
func enter(payload: Variant = null) -> void:
	record = payload as Resource
	if record == null:
		record = owner_node.last_record
	timer = telegraph_time
	owner_node.velocity.x = 0.0
	owner_node.set_facing_direction(record.direction)
	owner_node.play_animation(&"smash")
	owner_node.sprite.set_frame_and_progress(0, 0.0)
	owner_node.sprite.pause()

# 構え時間の終了後に自律SMASHへ遷移する。
func physics_update(delta: float) -> void:
	timer -= delta
	owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	if timer <= 0.0:
		transition_requested.emit(&"Smash", record)
