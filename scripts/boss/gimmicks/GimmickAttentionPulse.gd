# 2026-06-22: 現在使用できるボスギミックを共通の発光パルスで示す。
class_name GimmickAttentionPulse
extends Node

@export var pulse_speed := 5.5 # 明滅の速さ。
@export var tint_strength := 0.48 # 最大発光色の混合率。
@export var scale_boost := 0.04 # 最大拡大率。
@export var attention_color := Color(0.45, 1.0, 1.0, 1.0) # 注目対象の発光色。

var active := false # 現在パルス表示中か。
var _targets: Array[CanvasItem] = [] # 発光対象の描画ノード。
var _base_modulates: Dictionary = {} # 対象ごとの元modulate。
var _base_scales: Dictionary = {} # Node2D対象ごとの元scale。
var _elapsed := 0.0 # パルス位相用の経過時間。

# 発光対象を登録し、元の見た目を保存する。
func setup(items: Array[CanvasItem]) -> void:
	_targets = items
	_base_modulates.clear()
	_base_scales.clear()
	for target in _targets:
		if not is_instance_valid(target):
			continue
		var key := target.get_instance_id()
		_base_modulates[key] = target.modulate
		if target is Node2D:
			_base_scales[key] = target.scale
	set_process(false)

# 注目表示を切り替え、終了時は元の見た目へ戻す。
func set_active(value: bool) -> void:
	if active == value:
		return
	active = value
	_elapsed = 0.0
	set_process(active)
	if not active:
		_restore_targets()

# 色と大きさを周期的に変えて注目対象を示す。
func _process(delta: float) -> void:
	_elapsed += delta
	var phase := (sin(_elapsed * pulse_speed) + 1.0) * 0.5
	for target in _targets:
		if not is_instance_valid(target):
			continue
		var key := target.get_instance_id()
		var base_modulate: Color = _base_modulates.get(key, Color.WHITE)
		target.modulate = base_modulate.lerp(attention_color, 0.14 + tint_strength * phase)
		if target is Node2D and _base_scales.has(key):
			target.scale = (_base_scales[key] as Vector2) * (1.0 + scale_boost * phase)

# 登録時の色と大きさへ戻す。
func _restore_targets() -> void:
	for target in _targets:
		if not is_instance_valid(target):
			continue
		var key := target.get_instance_id()
		if _base_modulates.has(key):
			target.modulate = _base_modulates[key]
		if target is Node2D and _base_scales.has(key):
			target.scale = _base_scales[key]
