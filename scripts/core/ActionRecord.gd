# 2026-06-13: 記憶タグが再演する行動データを保持する。
class_name ActionRecord
extends Resource

var action_name: StringName # 再演する行動の種類。
var direction: Vector2 # 行動の向き。
var velocity: Vector2 # 再演時に使う速度。
var duration: float # 行動を続ける時間。
var distance: float # 行動完了に必要な移動距離。
var memory_id: int # 同じ記憶の二重使用を防ぐ識別子。
var is_available: bool # 現在この記憶を使用できるか。
var source: StringName # NATURALまたはREPLAYの発生源。
var payload: Dictionary # 行動固有の追加情報。

# 行動記録の初期値をまとめて受け取る。
func _init(
	_action_name: StringName = &"",
	_direction: Vector2 = Vector2.ZERO,
	_velocity: Vector2 = Vector2.ZERO,
	_duration: float = 0.0,
	_source: StringName = &"NATURAL",
	_payload: Dictionary = {}
) -> void:
	action_name = _action_name
	direction = _direction
	velocity = _velocity
	duration = _duration
	distance = _velocity.length() * _duration
	memory_id = 0
	is_available = false
	source = _source
	payload = _payload.duplicate(true)

# 記憶タグへ保存する際の識別情報を設定する。
func mark_as_memory(_memory_id: int, source_type: StringName) -> void:
	memory_id = _memory_id
	is_available = true
	source = source_type
