# 2026-06-22: BoarBossの非致命被弾を停止と点滅で見せる状態。
extends "res://scripts/core/State.gd"

@export var stagger_time := 0.65 # 被弾後に行動を止める時間。

var timer := 0.0 # 被弾停止の残り時間。

# 攻撃を解除し、被弾姿勢へ入る。
func enter(_payload: Variant = null) -> void:
	timer = stagger_time
	owner_node.velocity = Vector2.ZERO
	owner_node.clear_active_action_record()
	owner_node.set_attack_hitbox_active(false)
	owner_node.memory_tag.hide_tag()
	owner_node.restore_boss_sprite_transform()
	owner_node.play_animation(&"idle")
	owner_node.sprite.modulate = Color(1.0, 0.42, 0.34)

# 接地を維持しながら被弾停止後に待機へ戻る。
func physics_update(delta: float) -> void:
	timer -= delta
	owner_node.apply_gravity(delta)
	owner_node.move_and_slide()
	owner_node.sprite.modulate = Color.WHITE if int(timer * 16.0) % 2 == 0 else Color(1.0, 0.42, 0.34)
	if timer <= 0.0:
		transition_requested.emit(&"Idle", null)

# 次状態へ移る前に通常色へ戻す。
func exit() -> void:
	owner_node.sprite.modulate = Color.WHITE
	owner_node.restore_boss_sprite_transform()
