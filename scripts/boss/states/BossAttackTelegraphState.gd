# 2026-06-22: 攻撃種類と方向を固定して予備動作を見せる共通状態。
extends "res://scripts/core/State.gd"

@export var action_id: StringName # このStateが予告する行動ID。
@export var telegraph_time := 0.42 # 方向固定後の予備動作時間。

var timer := 0.0 # 残り予備動作時間。
var request: RefCounted # 固定済み攻撃要求。

func enter(payload: Variant = null) -> void:
	request = payload as RefCounted
	if request == null:
		request = owner_node.choose_natural_action()
	request.action_id = action_id
	timer = telegraph_time
	owner_node.velocity = Vector2.ZERO
	owner_node.begin_telegraph(request)
	owner_node.play_animation(&"smash" if action_id == &"smash" else &"idle")
	owner_node.sprite.set_frame_and_progress(0, 0.0)
	if request.source == &"REBITE_REPLAY":
		owner_node.sprite.modulate = Color.WHITE
	else:
		owner_node.sprite.modulate = Color(1.0, 0.72, 0.34) if action_id == &"smash" else Color(0.62, 0.78, 1.0)

func physics_update(delta: float) -> void:
	timer -= delta
	owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	if timer <= 0.0:
		transition_requested.emit(&"DashExecute" if action_id == &"dash" else &"SmashExecute", request)

func exit() -> void:
	owner_node.sprite.modulate = Color.WHITE
