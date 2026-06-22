# 2026-06-13: 記憶タグを持つ敵の共通処理。
class_name MemoryEnemy
extends "res://scripts/entities/Character.gd"

signal died # 死亡演出完了後にステージへ通知する。

var last_record: Resource # 最後に記憶タグへ保存した行動。
var active_action_record: Resource # 現在実行中で地形ギミックに伝える行動。

@onready var memory_tag: Node = $MemoryTag # 敵の頭上に出る記憶タグ。
@onready var attack_hitbox: Area2D = $AttackHitbox # 攻撃中だけ有効になる当たり判定。

# 記憶敵に共通する初期化を行う。
func setup_memory_enemy() -> void:
	remember_spawn_position()
	attack_hitbox.collision_mask |= 1
	attack_hitbox.body_entered.connect(_on_attack_hitbox_body_entered)
	set_attack_hitbox_active(false)

# 通常の噛み受付から記憶再演へ入る。
func receive_bite(_player: Node) -> void:
	if last_record == null or not is_biteable():
		return
	state_machine.change_state(&"Recalled", last_record)

# 噛み開始時に確定した記憶で再演へ入る。
func receive_committed_bite(_player: Node, record: Resource = null) -> void:
	if current_state_name() == &"Dying":
		return
	if record == null:
		record = last_record
	if record == null:
		return
	state_machine.change_state(&"Recalled", record)

# 噛み開始時に固定する記憶を返す。
func bite_commit_record() -> Resource:
	return last_record

# 現在実行中の行動記録を返す。
func current_action_record() -> Resource:
	return active_action_record

# 地形ギミックへ通知する現在行動を設定する。
func set_active_action_record(record: Resource) -> void:
	active_action_record = record

# 地形ギミックへ通知する現在行動を解除する。
func clear_active_action_record(record: Resource = null) -> void:
	if record == null or active_action_record == record:
		active_action_record = null

# 現在噛める状態かを返す。
func is_biteable() -> bool:
	return memory_tag.visible and current_state_name() == &"Recover"

# 噛みカメラが注目するタグ位置を返す。
func memory_tag_global_position() -> Vector2:
	return memory_tag.global_position

# 予測矢印の対象になっている間だけタグの噛み案内を強調する。
func set_memory_bite_hint_active(active: bool) -> void:
	if memory_tag != null and memory_tag.has_method("set_bite_hint_active"):
		memory_tag.set_bite_hint_active(active)

# 攻撃判定の有効/無効を切り替える。
func set_attack_hitbox_active(active: bool) -> void:
	attack_hitbox.set_deferred("monitoring", active)
	attack_hitbox.set_deferred("monitorable", active)

# 敵を死亡状態へ遷移させる。
func die() -> void:
	state_machine.change_state(&"Dying", null)

# 攻撃判定に入った相手を死亡させる。
func _on_attack_hitbox_body_entered(body: Node) -> void:
	if not attack_hitbox.monitoring:
		return
	if body.has_method("receive_memory_action_push"):
		body.receive_memory_action_push(self, active_action_record)
		return
	if body.has_method("die"):
		body.die()
