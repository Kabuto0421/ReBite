# 2026-07-07: Stage0の練習用記憶タグを噛み対象として扱う。
class_name TutorialMemoryTarget
extends StaticBody2D

signal bitten

const ActionRecordScript := preload("res://scripts/core/ActionRecord.gd")

@export var starts_available := true # 初期状態で噛めるか。
@export var tag_offset := Vector2(0.0, -54.0) # 本体基準の記憶タグ位置。
@export var action_velocity := Vector2(220.0, 0.0) # 予測矢印とタグに使う行動速度。
@export var action_duration := 0.35 # 予測矢印とタグに使う行動時間。

var available := false # 現在噛める状態か。
var last_record: Resource # StageBaseの予測矢印が参照する行動記録。

@onready var memory_tag: MemoryTag = $MemoryTag
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# 表示と判定を初期化する。
func _ready() -> void:
	last_record = ActionRecordScript.new(&"dash", Vector2.RIGHT, action_velocity, action_duration)
	last_record.mark_as_memory(get_instance_id(), &"NATURAL")
	set_available(starts_available)

# 噛める状態を切り替える。
func set_available(active: bool) -> void:
	available = active
	if collision_shape != null:
		collision_shape.disabled = not active
	if memory_tag == null:
		return
	memory_tag.position = tag_offset
	if active:
		last_record.mark_as_memory(get_instance_id(), &"NATURAL")
		memory_tag.show_record(last_record)
	else:
		memory_tag.hide_tag()

# Playerの対象探索用に噛み可否を返す。
func is_biteable() -> bool:
	return available

# Playerが噛み開始した瞬間に行動記録を固定する。
func bite_commit_record() -> Resource:
	return last_record if available else null

# K入力時点で噛み成功を確定し、タグを消費する。
func begin_committed_bite(_player: Node, _record: Resource) -> bool:
	_consume()
	return true

# 牙が届いたタイミングで未消費なら消費する。
func receive_committed_bite(_player: Node, _record: Resource) -> bool:
	_consume()
	return true

# 古い噛み処理との互換口。
func receive_bite(_player: Node) -> void:
	_consume()

# MemoryTagへ飛びつくためのワールド座標を返す。
func memory_tag_global_position() -> Vector2:
	return memory_tag.global_position if memory_tag != null else global_position + tag_offset

# 予測対象になった時の牙ヒントを切り替える。
func set_memory_bite_hint_active(active: bool) -> void:
	if memory_tag != null:
		memory_tag.set_bite_hint_active(active and available)

# 一度だけタグを割って通知する。
func _consume() -> void:
	if not available:
		return
	available = false
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	if memory_tag != null:
		memory_tag.begin_breaking(last_record)
	bitten.emit()
