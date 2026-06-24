# 2026-06-22: 岩で固定後、再演DASH激突を環境ダメージへ変えるストッパー。
class_name StopperTrap
extends AnimatableBody2D

const GimmickAttentionPulseScript := preload("res://scripts/boss/gimmicks/GimmickAttentionPulse.gd")

signal impact(event: Dictionary, rock: Node) # 有効なストッパー激突を通知する。
signal rock_locked(rock: Node) # 岩固定後に次の注目対象へ切り替える。

var active := false # RockRecoveryで利用可能か。
var locked_rock: Node # 現在固定に使っている岩。
var socket_tween: Tween # 衝突後のSocket表示を戻すTween。
var attention_pulse: Node # 岩固定後のDASH対象を示す発光部品。

@onready var sprite: Sprite2D = $Sprite # ストッパー状態表示。
@onready var socket_sprite: Sprite2D = $SocketSprite # 岩の固定穴状態表示。
@onready var socket_glow: Sprite2D = $SocketGlow # 空Socketを示すシアン発光。
@onready var collision_shape: CollisionShape2D = $CollisionShape2D # DASH検知形状。

func _ready() -> void:
	attention_pulse = GimmickAttentionPulseScript.new()
	add_child(attention_pulse)
	attention_pulse.setup([sprite] as Array[CanvasItem])

# 空Socketだけを緩く明滅させて設置位置を示す。
func _process(_delta: float) -> void:
	if not active or locked_rock != null:
		socket_glow.visible = false
		return
	socket_glow.visible = true
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.07
	socket_glow.scale = Vector2.ONE * 2.7 * pulse

# RockRecoveryでストッパーを展開する。
func activate() -> void:
	active = true
	visible = true
	sprite.texture = load("res://assets/boss/gimmicks/frames/stopper_01.png")
	if locked_rock == null:
		socket_sprite.texture = load("res://assets/boss/gimmicks/frames/rock_socket_00.png")
		socket_glow.visible = true
	collision_shape.set_deferred("disabled", false)
	attention_pulse.set_active(false)

# Socketへ入った岩でストッパーを固定する。
func lock_with_rock(rock: Node) -> void:
	if not active or rock == null:
		return
	if locked_rock != null:
		if rock.has_method("return_home_from_socket"):
			rock.return_home_from_socket()
		return
	locked_rock = rock
	sprite.texture = load("res://assets/boss/gimmicks/frames/stopper_02.png")
	socket_sprite.texture = load("res://assets/boss/gimmicks/frames/rock_socket_01.png")
	socket_glow.visible = false
	attention_pulse.set_active(true)
	rock_locked.emit(rock)

# 再演DASHだけを有効な激突として扱う。
func receive_memory_action_push(_source: Node, record: Resource) -> bool:
	if not active or locked_rock == null or record == null:
		return false
	if record.action_name != &"dash" or record.source != &"REBITE_REPLAY":
		return false
	var event := {
		"event_id": "stopper_%d" % Time.get_ticks_msec(),
		"source": &"REBITE_REPLAY",
		"trap_id": &"stopper",
		"rock_id": locked_rock.rock_id,
		"damage": 1,
	}
	sprite.texture = load("res://assets/boss/gimmicks/frames/stopper_03.png")
	attention_pulse.set_active(false)
	var used_rock := locked_rock
	locked_rock = null
	impact.emit(event, used_rock)
	socket_sprite.texture = load("res://assets/boss/gimmicks/frames/rock_socket_02.png")
	socket_glow.visible = false
	if socket_tween != null and socket_tween.is_valid():
		socket_tween.kill()
	socket_tween = create_tween()
	socket_tween.tween_interval(0.24)
	socket_tween.tween_callback(func():
		if active and locked_rock == null:
			socket_sprite.texture = load("res://assets/boss/gimmicks/frames/rock_socket_00.png")
			socket_glow.visible = true
	)
	return true

# 折り畳み初期状態へ戻す。
func reset_gimmick() -> void:
	active = false
	locked_rock = null
	attention_pulse.set_active(false)
	if socket_tween != null and socket_tween.is_valid():
		socket_tween.kill()
	socket_tween = null
	visible = false
	sprite.texture = load("res://assets/boss/gimmicks/frames/stopper_00.png")
	socket_sprite.texture = load("res://assets/boss/gimmicks/frames/rock_socket_00.png")
	socket_glow.visible = true
	collision_shape.set_deferred("disabled", true)
