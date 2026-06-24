# 2026-06-22: 着地点警告後に岩を落とすDASH誘導罠。
class_name TimedDropTrap
extends Node2D

const GimmickAttentionPulseScript := preload("res://scripts/boss/gimmicks/GimmickAttentionPulse.gd")

signal trap_resolved(trap_id: StringName, hit: bool, rock_id: StringName, event: Dictionary) # 時限落石結果を通知する。
signal fall_started # 岩の落下開始を通知する。
signal landing_contact(trap: Node, impact_position: Vector2, hit: bool) # 岩が着地した瞬間を通知する。

@export var trap_id: StringName = &"timed_drop" # Encounterで識別する罠ID。
@export var rock_id: StringName = &"rock_b" # 耐久を消費する岩ID。
@export var countdown_time := 3.0 # 起動から落下までの猶予。
@export var fall_time := 0.48 # 岩の落下時間。
@export var landing_offset := Vector2(0.0, 350.0) # 装置から着地点までの差。
@export var landing_tolerance_x := 90.0 # 着地点として認める横幅。

var boss: Node # 命中対象BossBoar。
var active := false # カウントダウン中か。
var resolved := false # 結果確定済みか。
var timer := 0.0 # 落下までの残り時間。
var replay_dash_entered_marker := false # 再演DASH中に着地点へ入ったか。
var tracking_replay_dash := false # 着地結果確定まで再演DASHを監視するか。
var attention_pulse: Node # 現在使用できる罠を示す発光部品。
var pending_landing_hit := false # ヒットストップ後に確定する命中結果。
var pending_landing_event: Dictionary = {} # ヒットストップ後に通知するDamageEvent。
var waiting_for_landing_feedback := false # 着地結果の続行待ちか。
var impact_feedback_enabled := false # 着地後にPresenterの続行通知を待つか。

@onready var device_sprite: Sprite2D = $DeviceSprite # 天井装置表示。
@onready var rock_sprite: Sprite2D = $RockSprite # 装置内の岩表示。
@onready var marker_sprite: Sprite2D = $LandingMarker # 着地点警告表示。

func _ready() -> void:
	attention_pulse = GimmickAttentionPulseScript.new()
	add_child(attention_pulse)
	attention_pulse.setup([device_sprite, marker_sprite] as Array[CanvasItem])

# 対象Bossを設定してカウントダウンを開始する。
func arm(target_boss: Node) -> void:
	boss = target_boss
	active = true
	resolved = false
	timer = countdown_time
	replay_dash_entered_marker = false
	tracking_replay_dash = true
	visible = true
	rock_sprite.visible = true
	rock_sprite.position = Vector2.ZERO
	marker_sprite.visible = true
	device_sprite.texture = load("res://assets/boss/gimmicks/frames/timed_dropper_01.png")
	attention_pulse.set_active(true)

# Encounterの状態遷移に応じて注目表示だけを切り替える。
func set_attention_active(value: bool) -> void:
	attention_pulse.set_active(value and active and visible)

# 警告段階と再演DASHの着地点進入を更新する。
func _process(delta: float) -> void:
	if tracking_replay_dash and boss != null and boss.is_executing_replay(&"dash") and _boss_is_near_marker():
		replay_dash_entered_marker = true
	if not active or resolved:
		return
	timer -= delta
	if timer <= countdown_time * 0.34:
		marker_sprite.texture = load("res://assets/boss/gimmicks/frames/landing_marker_02.png")
	elif timer <= countdown_time * 0.67:
		marker_sprite.texture = load("res://assets/boss/gimmicks/frames/landing_marker_01.png")
	if timer <= 0.0:
		_drop()

# 岩を警告地点へ落とす。
func _drop() -> void:
	active = false
	resolved = true
	attention_pulse.set_active(false)
	device_sprite.texture = load("res://assets/boss/gimmicks/frames/timed_dropper_03.png")
	fall_started.emit()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(rock_sprite, "position", landing_offset, fall_time)
	tween.tween_callback(_resolve_landing)

# 再演DASHで着地点へ運ばれ、落下時にも範囲内なら命中扱いにする。
func _resolve_landing() -> void:
	tracking_replay_dash = false
	attention_pulse.set_active(false)
	pending_landing_hit = replay_dash_entered_marker and _boss_is_near_marker()
	pending_landing_event = {
		"event_id": "%s_%d" % [trap_id, Time.get_ticks_msec()],
		"source": &"REBITE_REPLAY",
		"trap_id": trap_id,
		"rock_id": rock_id,
		"damage": 1,
	}
	marker_sprite.visible = false
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

# Bossが現在の着地点横幅に入っているか返す。
func _boss_is_near_marker() -> bool:
	return boss != null and absf(boss.global_position.x - marker_sprite.global_position.x) <= landing_tolerance_x

# 再利用岩へ状態を引き継ぐ時に落下演出側の岩を隠す。
func handoff_rock_actor() -> void:
	rock_sprite.visible = false

# 未起動状態へ戻す。
func reset_gimmick() -> void:
	active = false
	resolved = false
	timer = 0.0
	replay_dash_entered_marker = false
	tracking_replay_dash = false
	waiting_for_landing_feedback = false
	pending_landing_event.clear()
	visible = true
	rock_sprite.visible = true
	rock_sprite.position = Vector2.ZERO
	marker_sprite.visible = false
	marker_sprite.texture = load("res://assets/boss/gimmicks/frames/landing_marker_00.png")
	device_sprite.texture = load("res://assets/boss/gimmicks/frames/timed_dropper_00.png")
