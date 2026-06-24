# 2026-06-22: 4ダメージ後の再演DASHでだけ壊れる最終壁。
class_name FinalWall
extends AnimatableBody2D

const GimmickAttentionPulseScript := preload("res://scripts/boss/gimmicks/GimmickAttentionPulse.gd")

signal final_impact(event: Dictionary) # 最終有効ダメージを通知する。
signal wall_contact(wall: Node, event: Dictionary, impact_position: Vector2) # Boarが壁へ接触した瞬間を通知する。

var active := false # FinalCharge中か。
var resolved := false # 最終激突済みか。
var attention_pulse: Node # 最終DASH対象を示す発光部品。
var pending_impact_event: Dictionary = {} # ヒットストップ後に通知する最終DamageEvent。
var waiting_for_impact_feedback := false # 最終ダメージの続行待ちか。
var impact_feedback_enabled := false # 接触後にPresenterの続行通知を待つか。

@onready var sprite: Sprite2D = $Sprite # 壁状態表示。
@onready var collision_shape: CollisionShape2D = $CollisionShape2D # DASH検知形状。

func _ready() -> void:
	attention_pulse = GimmickAttentionPulseScript.new()
	add_child(attention_pulse)
	attention_pulse.setup([sprite] as Array[CanvasItem])

# 最終フェーズで壁を露出する。
func expose() -> void:
	active = true
	resolved = false
	visible = true
	sprite.texture = load("res://assets/boss/gimmicks/frames/final_wall_01.png")
	collision_shape.set_deferred("disabled", false)
	attention_pulse.set_active(true)

# 再演DASHだけを最終激突として受け付ける。
func receive_memory_action_push(source: Node, record: Resource) -> bool:
	if not active or resolved or record == null:
		return false
	if record.action_name != &"dash" or record.source != &"REBITE_REPLAY":
		return false
	resolved = true
	active = false
	attention_pulse.set_active(false)
	collision_shape.set_deferred("disabled", true)
	pending_impact_event = {
		"event_id": "final_wall_%d" % Time.get_ticks_msec(),
		"source": &"REBITE_REPLAY",
		"trap_id": &"final_wall",
		"rock_id": &"",
		"damage": 1,
	}
	waiting_for_impact_feedback = true
	var impact_position := sprite.global_position
	if source != null:
		impact_position.y = source.global_position.y - 24.0
	wall_contact.emit(self, pending_impact_event, impact_position)
	if not impact_feedback_enabled:
		complete_final_impact()
	return true

# Stage10の共通ImpactPresenterによる接触待機を切り替える。
func set_impact_feedback_enabled(value: bool) -> void:
	impact_feedback_enabled = value

# 壁ヒットストップ解除後に最終ダメージを確定する。
func complete_final_impact() -> void:
	if not waiting_for_impact_feedback:
		return
	waiting_for_impact_feedback = false
	sprite.texture = load("res://assets/boss/gimmicks/frames/final_wall_04.png")
	final_impact.emit(pending_impact_event)

# 非公開の初期壁状態へ戻す。
func reset_gimmick() -> void:
	active = false
	resolved = false
	waiting_for_impact_feedback = false
	pending_impact_event.clear()
	attention_pulse.set_active(false)
	visible = true
	sprite.texture = load("res://assets/boss/gimmicks/frames/final_wall_00.png")
	collision_shape.set_deferred("disabled", true)
