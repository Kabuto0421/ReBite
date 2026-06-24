# 2026-06-13: SkullMonsterの記憶タグ受付時間。
extends "res://scripts/core/State.gd"

@export var recover_time := 1.0
@export_range(0.05, 0.5, 0.01) var blocked_recover_time := 0.18
@export var return_warning_time := 0.22
var timer := 0.0
var active_duration := 0.0

func enter(payload: Variant = null) -> void:
	var context: Dictionary = payload if payload is Dictionary else {}
	active_duration = blocked_recover_time if bool(context.get("blocked", false)) else recover_time
	timer = active_duration
	owner_node.velocity.x = 0.0
	owner_node.play_animation(&"idle")
	if owner_node.has_method("set_attack_warning_active"):
		owner_node.set_attack_warning_active(false)

func exit() -> void:
	if owner_node.has_method("set_attack_warning_active"):
		owner_node.set_attack_warning_active(false)

func physics_update(delta: float) -> void:
	timer -= delta
	owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	if owner_node.has_method("set_attack_warning_active"):
		owner_node.set_attack_warning_active(timer <= return_warning_time)
	if timer <= 0.0:
		transition_requested.emit(&"Telegraph", owner_node.build_natural_dash_record())
