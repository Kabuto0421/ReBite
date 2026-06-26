# 2026-06-25: MemoryEnemyで起動する同期ゲート。
class_name ReBiteGateRig
extends Node2D

signal activation_started(source: Node) # 動力源によってゲートが起動したことを通知する。
signal activation_finished(source: Node) # 20tickサイクルが終了したことを通知する。

const BASE_FRAME_BY_TICK: Array[int] = [0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 9, 10, 11, 12, 13, 14, 15, 0]
const SWITCH_FRAME_BY_TICK: Array[int] = [0, 0, 0, 1, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
const GATE_BODY_Y_BY_TICK: Array[float] = [5, 5, 5, 5, 0, -6, -12, -18, -25, -32, -39, -39, -39, -32, -25, -18, -12, -6, 0, 5]
const GATE_BODY_X := 7.0
const TICK_COUNT := 20
const DEFAULT_TICK_RATE := 12.0
const FRAME_SIZE := Vector2i(56, 48)

enum GateState { CLOSED, CYCLING }

@export_file("*.png") var base_sheet_path := "res://assets/props/gate/base_unique_sheet.png" # Baseの16コマ素材。
@export_file("*.png") var switch_sheet_path := "res://assets/props/gate/switch_unique_sheet.png" # Switchの4コマ素材。
@export_file("*.png") var gate_texture_path := "res://assets/props/gate/gate_static.png" # 上下移動するGate静止画像。
@export_range(1.0, 48.0, 0.5) var tick_rate := DEFAULT_TICK_RATE # 20tickタイムラインを進める速さ。
@export var switch_enabled := true # 内蔵SwitchHitboxで起動するかどうか。
@export var switch_trigger_group := &"memory_enemy" # SwitchHitboxが受け付けるbody group名。

var gate_state := GateState.CLOSED # 現在のゲート状態。
var is_running := false # 20tickサイクル中かどうか。
var _current_tick := 0 # 現在適用しているタイムラインtick。
var _tick_elapsed := 0.0 # 次tickまでの経過時間。
var _activation_source: Node # 現在の起動元。

@onready var base_sprite: AnimatedSprite2D = $Base # ゲート土台の表示。
@onready var switch_sprite: AnimatedSprite2D = $Switch # 押し板スイッチの表示。
@onready var switch_hitbox: Area2D = $SwitchHitbox # MemoryEnemyだけを検知する押し板判定。
@onready var gate_body: AnimatableBody2D = $GateBody # GateSpriteとGateCollisionをまとめて上下移動する本体。
@onready var gate_sprite: Sprite2D = $GateBody/GateSprite # ゲートの静止画像。

# 素材と判定を初期化し、MemoryEnemy接触で起動できるようにする。
func _ready() -> void:
	_build_sprite_frames()
	gate_sprite.texture = load(gate_texture_path)
	gate_body.sync_to_physics = true
	switch_hitbox.body_entered.connect(_on_switch_body_entered)
	_apply_tick(0)
	set_physics_process(false)

# 物理同期されたGateBodyを12FPS相当のtickで動かす。
func _physics_process(delta: float) -> void:
	if gate_state != GateState.CYCLING:
		return
	_tick_elapsed += delta
	if _tick_elapsed < _tick_interval():
		return
	_tick_elapsed -= _tick_interval()
	_current_tick += 1
	if _current_tick >= TICK_COUNT:
		_change_state(GateState.CLOSED)
		return
	_apply_tick(_current_tick)

# 外部イベントからもゲートサイクルを開始できる入口。
func activate(source: Node = null) -> bool:
	if gate_state != GateState.CLOSED:
		return false
	_activation_source = source
	_change_state(GateState.CYCLING)
	return true

# ゲートが現在起動可能か返す。
func can_activate() -> bool:
	return gate_state == GateState.CLOSED

# 指定tickの厳密な素材フレームとGateBody位置を適用する。
func _apply_tick(tick: int) -> void:
	var index := clampi(tick, 0, TICK_COUNT - 1)
	base_sprite.frame = BASE_FRAME_BY_TICK[index]
	switch_sprite.frame = SWITCH_FRAME_BY_TICK[index]
	if Engine.is_in_physics_frame() or not gate_body.sync_to_physics:
		gate_body.position = Vector2(GATE_BODY_X, GATE_BODY_Y_BY_TICK[index])

# SwitchHitboxへMemoryEnemy本体が触れた時だけ起動する。
func _on_switch_body_entered(body: Node) -> void:
	if not switch_enabled or not can_activate():
		return
	if body != null and body.is_in_group(switch_trigger_group):
		activate(body)

# BaseとSwitchは有効コマ数が違うため、それぞれ個別のSpriteFramesを作る。
func _build_sprite_frames() -> void:
	base_sprite.sprite_frames = _sprite_frames_from_sheet(base_sheet_path, &"default", 16)
	base_sprite.animation = &"default"
	base_sprite.pause()
	switch_sprite.sprite_frames = _sprite_frames_from_sheet(switch_sheet_path, &"default", 4)
	switch_sprite.animation = &"default"
	switch_sprite.pause()

# 横一列シートから指定コマ数ぶんのAtlasTextureフレームを作る。
func _sprite_frames_from_sheet(path: String, animation_name: StringName, frame_count: int) -> SpriteFrames:
	var texture := load(path) as Texture2D
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	frames.add_animation(animation_name)
	frames.set_animation_loop(animation_name, false)
	frames.set_animation_speed(animation_name, tick_rate)
	if texture == null:
		push_error("Failed to load gate sprite sheet: %s" % path)
		return frames
	for index in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(index * FRAME_SIZE.x, 0), FRAME_SIZE)
		frames.add_frame(animation_name, atlas)
	return frames

# 状態遷移の入口を一箇所に集め、起動/終了時の副作用を閉じ込める。
func _change_state(next_state: int) -> void:
	if gate_state == next_state:
		return
	gate_state = next_state
	is_running = gate_state == GateState.CYCLING
	match gate_state:
		GateState.CLOSED:
			_current_tick = 0
			_tick_elapsed = 0.0
			_apply_tick(0)
			set_physics_process(false)
			activation_finished.emit(_activation_source)
			_activation_source = null
		GateState.CYCLING:
			_current_tick = 0
			_tick_elapsed = 0.0
			_apply_tick(0)
			set_physics_process(true)
			activation_started.emit(_activation_source)

# tick_rateから1tickの秒数を返す。
func _tick_interval() -> float:
	return 1.0 / maxf(tick_rate, 0.001)
