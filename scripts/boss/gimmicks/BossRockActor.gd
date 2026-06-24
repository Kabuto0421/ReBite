# 2026-06-22: 固定スロット間を移動し2回の有効ダメージに使える岩。
class_name BossRockActor
extends AnimatableBody2D

const GimmickAttentionPulseScript := preload("res://scripts/boss/gimmicks/GimmickAttentionPulse.gd")

signal socketed(rock: Node) # 固定穴へ入った時に通知する。
signal smash_contacted(rock: Node, impact_position: Vector2) # 再演SMASHが岩へ接触した瞬間を通知する。
signal condition_changed(rock_id: StringName, condition: StringName) # 耐久状態変化を通知する。

enum Condition { INTACT, CRACKED, BROKEN }

@export var rock_id: StringName = &"rock_a" # Encounter内の岩ID。
@export var socket_offset := Vector2(250.0, 0.0) # Homeから固定穴までの差。
@export_range(0.05, 0.5, 0.01) var socket_travel_time := 0.18 # ヒットストップ後にSocketへ移動する時間。

var condition := Condition.INTACT # 現在の耐久状態。
var uses_remaining := 2 # 残り有効ダメージ回数。
var socketed_state := false # 現在固定穴にいるか。
var active := false # RockRecoveryで操作可能か。
var _home_position := Vector2.ZERO # 初期Home位置。
var attention_pulse: Node # 現在使用できる岩を示す発光部品。
var socket_tween: Tween # Socketへ移動中のTween。
var impact_feedback_enabled := false # 接触後にPresenterの続行通知を待つか。

@onready var sprite: Sprite2D = $Sprite # 岩状態表示。
@onready var collision_shape: CollisionShape2D = $CollisionShape2D # SMASH検知形状。

func _ready() -> void:
	_home_position = global_position
	_update_visual()
	attention_pulse = GimmickAttentionPulseScript.new()
	add_child(attention_pulse)
	attention_pulse.setup([sprite] as Array[CanvasItem])

# RockRecoveryで岩を表示・操作可能にする。
func activate() -> void:
	active = uses_remaining > 0
	visible = uses_remaining > 0
	collision_shape.set_deferred("disabled", not active)
	set_attention_active(active)

# 保存方向の再演SMASHでHomeからSocketへ移動する。
func receive_memory_action_push(_source: Node, record: Resource) -> bool:
	if not active or socketed_state or record == null:
		return false
	if record.action_name != &"smash" or record.source != &"REBITE_REPLAY":
		return false
	var target_direction := socket_offset.normalized()
	if record.direction.normalized().dot(target_direction) < 0.25:
		return false
	socketed_state = true
	active = false
	set_attention_active(false)
	collision_shape.set_deferred("disabled", true)
	smash_contacted.emit(self, sprite.global_position)
	if not impact_feedback_enabled:
		continue_socket_move()
	return true

# Stage10の共通ImpactPresenterによる接触待機を切り替える。
func set_impact_feedback_enabled(value: bool) -> void:
	impact_feedback_enabled = value

# 接触ヒットストップ解除後にSocketへ移動する。
func continue_socket_move() -> void:
	if not socketed_state or uses_remaining <= 0:
		return
	_kill_socket_tween()
	socket_tween = create_tween()
	socket_tween.set_trans(Tween.TRANS_QUART)
	socket_tween.set_ease(Tween.EASE_OUT)
	socket_tween.tween_property(self, "global_position", _home_position + socket_offset, socket_travel_time)
	socket_tween.tween_callback(func(): socketed.emit(self))

# 成功ダメージと同時に耐久を1消費する。
func consume_use() -> void:
	if uses_remaining <= 0:
		return
	uses_remaining -= 1
	_kill_socket_tween()
	condition = Condition.CRACKED if uses_remaining == 1 else Condition.BROKEN
	condition_changed.emit(rock_id, condition_name())
	socketed_state = false
	_update_visual()
	if uses_remaining > 0:
		global_position = _home_position
		activate()
	else:
		active = false
		set_attention_active(false)
		collision_shape.set_deferred("disabled", true)

# 初回罠命中時も同じ耐久規則を適用する。
func consume_initial_hit() -> void:
	consume_use()
	if uses_remaining > 0:
		visible = false

# 使用中のSocketが埋まっていた場合にHomeへ安全に戻す。
func return_home_from_socket() -> void:
	_kill_socket_tween()
	socketed_state = false
	global_position = _home_position
	activate()

# Encounterの攻略順に応じて岩の注目表示だけを切り替える。
func set_attention_active(value: bool) -> void:
	if attention_pulse != null:
		attention_pulse.set_active(value and active and visible)

# 耐久状態名を返す。
func condition_name() -> StringName:
	match condition:
		Condition.CRACKED:
			return &"CRACKED"
		Condition.BROKEN:
			return &"BROKEN"
		_:
			return &"INTACT"

# 初期耐久とHome位置へ戻す。
func reset_gimmick() -> void:
	_kill_socket_tween()
	condition = Condition.INTACT
	uses_remaining = 2
	socketed_state = false
	active = false
	set_attention_active(false)
	global_position = _home_position
	visible = false
	collision_shape.set_deferred("disabled", true)
	_update_visual()

# 耐久に対応するパッケージ画像へ切り替える。
func _update_visual() -> void:
	var index := 0 if condition == Condition.INTACT else (1 if condition == Condition.CRACKED else 2)
	sprite.texture = load("res://assets/boss/gimmicks/frames/rock_0%d.png" % index)

# 実行中のSocket移動を停止する。
func _kill_socket_tween() -> void:
	if socket_tween != null and socket_tween.is_valid():
		socket_tween.kill()
	socket_tween = null
