# 2026-06-22: 環境ダメージ後にBossBoarをよろめかせる状態。
extends "res://scripts/core/State.gd"

@export var stagger_time := 0.8 # 被弾硬直時間。
var timer := 0.0 # 残り硬直時間。

func enter(_payload: Variant = null) -> void:
	timer = stagger_time
	owner_node.velocity = Vector2.ZERO
	owner_node.finish_attack(owner_node.current_request)
	owner_node.memory_tag.hide_tag()
	owner_node.restore_boss_sprite_transform()
	owner_node.play_animation(&"idle")

func physics_update(delta: float) -> void:
	timer -= delta
	owner_node.sprite.modulate = Color.WHITE if int(timer * 16.0) % 2 == 0 else Color(1.0, 0.34, 0.24)
	owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	if timer <= 0.0:
		transition_requested.emit(&"Chase", null)

func exit() -> void:
	owner_node.restore_boss_sprite_transform()
