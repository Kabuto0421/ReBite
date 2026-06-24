# 2026-06-22: 攻撃後に記憶タグを提示して噛みを待つ状態。
extends "res://scripts/core/State.gd"

@export var memory_window := 2.4 # 通常攻撃後の噛み受付時間。
@export var replay_recovery := 0.45 # 再演後の短い硬直時間。

var timer := 0.0 # 残り硬直または受付時間。
var request: RefCounted # 直前攻撃要求。

func enter(payload: Variant = null) -> void:
	request = payload as RefCounted
	var replayed: bool = request != null and request.source == &"REBITE_REPLAY"
	timer = replay_recovery if replayed else memory_window
	owner_node.velocity.x = 0.0
	owner_node.play_animation(&"idle")
	owner_node.show_attack_memory_if_available()

func physics_update(delta: float) -> void:
	timer -= delta
	if owner_node.memory_tag.visible and owner_node.memory_tag.has_method("set_window_progress"):
		owner_node.memory_tag.set_window_progress(timer / memory_window)
	owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	if timer <= 0.0:
		owner_node.memory_tag.hide_tag()
		transition_requested.emit(&"Idle", null)
