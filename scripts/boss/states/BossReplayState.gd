# 2026-06-22: 記憶タグ破壊後に保存方向の攻撃へ接続する状態。
extends "res://scripts/core/State.gd"

var timer := 0.0 # 再演開始までの停止時間。
var request: RefCounted # 保存済み方向の再演要求。

func enter(payload: Variant = null) -> void:
	request = payload as RefCounted
	timer = owner_node.recall_start_delay
	owner_node.velocity = Vector2.ZERO
	owner_node.memory_tag.crack_tag()
	owner_node.set_replay_outline_active(true)
	owner_node.play_animation(&"idle")
	owner_node.pause_animation()

func physics_update(delta: float) -> void:
	timer -= delta
	owner_node.velocity = Vector2.ZERO
	owner_node.move_and_slide()
	if timer <= 0.0:
		owner_node.resume_animation()
		owner_node.memory_tag.hide_tag()
		transition_requested.emit(&"DashTelegraph" if request.action_id == &"dash" else &"SmashTelegraph", request)

func exit() -> void:
	owner_node.resume_animation()
