# 2026-06-22: ボス攻撃の種類、固定方向、発生源をまとめるデータ。
class_name BossActionRequest
extends RefCounted

const ActionRecordScript := preload("res://scripts/core/ActionRecord.gd")

var action_id: StringName # DASHまたはSMASH。
var direction: Vector2 # Telegraph開始時に固定する攻撃方向。
var source: StringName # NATURALまたはREBITE_REPLAY。
var target_position: Vector2 # 通常攻撃選択時の主人公位置。
var payload: Dictionary # 攻撃固有の追加情報。

# 攻撃要求を生成する。
func _init(
	_action_id: StringName = &"",
	_direction: Vector2 = Vector2.ZERO,
	_source: StringName = &"NATURAL",
	_target_position: Vector2 = Vector2.ZERO,
	_payload: Dictionary = {}
) -> void:
	action_id = _action_id
	direction = _direction.normalized()
	source = _source
	target_position = _target_position
	payload = _payload.duplicate(true)

# 記憶タグと地形通知に使うActionRecordへ変換する。
func to_action_record(speed: float, duration: float) -> Resource:
	return ActionRecordScript.new(action_id, direction, direction * speed, duration, source, payload)
