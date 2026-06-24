# 2026-06-21: 噛まれたSMASH記憶を同じ強さで再演する状態。
extends "res://scripts/core/State.gd"

var timer := 0.0 # 再演SMASHの残り時間。
var start_delay := 0.0 # タグ破壊後の停止時間。
var replay_started := false # 再演アニメーションを開始済みか。
var impact_active := false # 攻撃区間が現在有効か。
var record: Resource # 噛み開始時に確定したSMASH記録。

# タグを砕き、記録済みSMASHの再演待ちへ入る。
func enter(payload: Variant = null) -> void:
	record = payload as Resource
	if record == null:
		record = owner_node.last_record
	timer = record.duration if record != null else owner_node.smash_duration
	start_delay = owner_node.recall_start_delay
	replay_started = false
	impact_active = false
	owner_node.velocity = Vector2.ZERO
	owner_node.memory_tag.crack_tag()
	owner_node.set_facing_direction(record.direction)
	owner_node.play_animation(&"idle")

# 状態を抜ける時に攻撃判定と行動記録を必ず解除する。
func exit() -> void:
	_set_impact_active(false)
	owner_node.set_replay_outline_active(false)
	owner_node.velocity.x = 0.0

# 停止演出後、記録時と同じ速度・長さでSMASHを再演する。
func physics_update(delta: float) -> void:
	if start_delay > 0.0:
		start_delay -= delta
		owner_node.velocity = Vector2.ZERO
		owner_node.move_and_slide()
		return

	if not replay_started:
		replay_started = true
		owner_node.set_replay_outline_active(true)
		owner_node.play_animation(&"smash")
		owner_node.sprite.set_frame_and_progress(0, 0.0)

	timer -= delta
	var elapsed: float = record.duration - maxf(timer, 0.0)
	_set_impact_active(owner_node.is_smash_impact_active(elapsed))
	owner_node.apply_gravity(delta)
	owner_node.velocity.x = owner_node.smash_velocity(record, elapsed).x
	owner_node.move_and_slide()
	if timer <= 0.0:
		owner_node.memory_tag.hide_tag()
		owner_node.set_facing_direction(owner_node.walk_direction)
		owner_node.prepare_smash_record(owner_node.walk_direction)
		transition_requested.emit(&"Idle", null)

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
