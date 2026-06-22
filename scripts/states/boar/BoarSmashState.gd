# 2026-06-21: BoarMonsterが自律SMASHを実行して記憶する状態。
extends "res://scripts/core/State.gd"

var timer := 0.0 # SMASHの残り時間。
var record: Resource # 実行中のSMASH記録。
var impact_active := false # 攻撃区間が現在有効か。

# SMASHアニメーションを先頭から開始する。
func enter(payload: Variant = null) -> void:
	record = payload as Resource
	if record == null:
		record = owner_node.last_record
	timer = record.duration
	impact_active = false
	owner_node.velocity = Vector2.ZERO
	owner_node.set_facing_direction(record.direction)
	owner_node.play_animation(&"smash")
	owner_node.sprite.set_frame_and_progress(0, 0.0)

# 状態を抜ける時に攻撃判定と行動記録を必ず解除する。
func exit() -> void:
	_set_impact_active(false)
	owner_node.velocity.x = 0.0

# SMASHの衝撃区間だけ踏み込みと攻撃判定を有効にする。
func physics_update(delta: float) -> void:
	timer -= delta
	var elapsed: float = record.duration - maxf(timer, 0.0)
	_set_impact_active(owner_node.is_smash_impact_active(elapsed))
	owner_node.apply_gravity(delta)
	owner_node.velocity.x = owner_node.smash_velocity(record, elapsed).x
	owner_node.move_and_slide()
	if timer <= 0.0:
		owner_node.commit_smash_record(record)
		transition_requested.emit(&"Recover", null)

# 攻撃区間に合わせてプレイヤー攻撃判定と地形行動記録を切り替える。
func _set_impact_active(active: bool) -> void:
	if impact_active == active:
		return
	impact_active = active
	owner_node.set_attack_hitbox_active(active)
	if active:
		owner_node.set_active_action_record(record)
	else:
		owner_node.clear_active_action_record(record)
