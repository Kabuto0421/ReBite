# 2026-06-13: 記憶タグが再演する行動データを保持する。
class_name ActionRecord
extends Resource

var action_name: StringName # 再演する行動の種類。
var direction: Vector2 # 行動の向き。
var velocity: Vector2 # 再演時に使う速度。
var duration: float # 行動を続ける時間。

# 行動記録の初期値をまとめて受け取る。
func _init(
	_action_name: StringName = &"",
	_direction: Vector2 = Vector2.ZERO,
	_velocity: Vector2 = Vector2.ZERO,
	_duration: float = 0.0
) -> void:
	action_name = _action_name
	direction = _direction
	velocity = _velocity
	duration = _duration
