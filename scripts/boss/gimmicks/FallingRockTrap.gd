# 2026-06-22: 再演SMASHで支柱を壊して落石させる初回罠。
class_name FallingRockTrap
extends AnimatableBody2D

const GimmickAttentionPulseScript := preload("res://scripts/boss/gimmicks/GimmickAttentionPulse.gd")

signal trap_resolved(trap_id: StringName, hit: bool, rock_id: StringName, event: Dictionary) # 落石結果を通知する。
signal fall_started # 岩の落下開始を通知する。
signal landing_contact(trap: Node, impact_position: Vector2, hit: bool) # 岩が着地した瞬間を通知する。

@export var trap_id: StringName = &"falling_rock" # Encounterで識別する罠ID。
@export var rock_id: StringName = &"rock_a" # 耐久を消費する岩ID。
@export var landing_offset := Vector2(0.0, 300.0) # 吊り位置から着地点までの差。

var boss: Node # 命中対象BossBoar。
var active := false # 現在使用可能か。
var resolved := false # 結果確定済みか。
var _spawn_position := Vector2.ZERO # リセット時の位置。
var attention_pulse: Node # 現在使用できる罠を示す発光部品。
var pending_landing_hit := false # ヒットストップ後に確定する命中結果。
var pending_landing_event: Dictionary = {} # ヒットストップ後に通知するDamageEvent。
var waiting_for_landing_feedback := false # 着地結果の続行待ちか。
var impact_feedback_enabled := false # 着地後にPresenterの続行通知を待つか。

@onready var support_sprite: Sprite2D = $SupportSprite # 支柱表示。
@onready var rock_sprite: Sprite2D = $RockSprite # 吊り岩表示。
@onready var collision_shape: CollisionShape2D = $CollisionShape2D # SMASH検知用Body形状。

func _ready() -> void:
	_spawn_position = global_position
	attention_pulse = GimmickAttentionPulseScript.new()
	add_child(attention_pulse)
	attention_pulse.setup([support_sprite, rock_sprite] as Array[CanvasItem])

# 対象Bossを設定して罠を有効化する。
func arm(target_boss: Node) -> void:
	boss = target_boss
	active = true
	visible = true
	collision_shape.set_deferred("disabled", false)
	attention_pulse.set_active(true)

# Encounterの状態遷移に応じて注目表示だけを切り替える。
func set_attention_active(value: bool) -> void:
	attention_pulse.set_active(value and active and visible)

# 再演SMASHだけを支柱破壊として受け付ける。
func receive_memory_action_push(_source: Node, record: Resource) -> bool:
	if not active or resolved or record == null:
		return false
	if record.action_name != &"smash" or record.source != &"REBITE_REPLAY":
		return false
	_release_rock()
	return true

# 支柱を崩して岩を着地点へ落とす。
func _release_rock() -> void:
	resolved = true
	active = false
	attention_pulse.set_active(false)
	collision_shape.set_deferred("disabled", true)
	support_sprite.texture = load("res://assets/boss/gimmicks/frames/support_03.png")
	fall_started.emit()
	var target := rock_sprite.position + landing_offset
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(rock_sprite, "position", target, 0.58)
	tween.tween_callback(_resolve_landing)

# 着地点のBoss有無を判定して再演DamageEventを作る。
func _resolve_landing() -> void:
	pending_landing_hit = boss != null and absf(boss.global_position.x - rock_sprite.global_position.x) <= 86.0 and absf(boss.global_position.y - rock_sprite.global_position.y) <= 105.0
	pending_landing_event = {
		"event_id": "%s_%d" % [trap_id, Time.get_ticks_msec()],
		"source": &"REBITE_REPLAY",
		"trap_id": trap_id,
		"rock_id": rock_id,
		"damage": 1,
	}
	waiting_for_landing_feedback = true
	landing_contact.emit(self, rock_sprite.global_position, pending_landing_hit)
	if not impact_feedback_enabled:
		complete_landing_after_impact()

# Stage10の共通ImpactPresenterによる着地待機を切り替える。
func set_impact_feedback_enabled(value: bool) -> void:
	impact_feedback_enabled = value

# 着地ヒットストップ解除後に攻略結果を確定する。
func complete_landing_after_impact() -> void:
	if not waiting_for_landing_feedback:
		return
	waiting_for_landing_feedback = false
	trap_resolved.emit(trap_id, pending_landing_hit, rock_id, pending_landing_event)

# 再利用岩へ状態を引き継ぐ時に落下演出側の岩を隠す。
func handoff_rock_actor() -> void:
	rock_sprite.visible = false

# 初期吊り状態へ戻す。
func reset_gimmick() -> void:
	global_position = _spawn_position
	active = false
	resolved = false
	waiting_for_landing_feedback = false
	pending_landing_event.clear()
	attention_pulse.set_active(false)
	visible = true
	rock_sprite.visible = true
	support_sprite.texture = load("res://assets/boss/gimmicks/frames/support_00.png")
	rock_sprite.position = Vector2(0.0, -94.0)
	collision_shape.set_deferred("disabled", false)
