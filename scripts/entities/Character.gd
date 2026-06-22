# 2026-06-13: プレイヤーと敵が共有する基本キャラクター処理。
extends CharacterBody2D

@export var gravity := 1050.0 # このキャラクターにかかる重力。

var spawn_position := Vector2.ZERO # リスポーン先の初期位置。

@onready var sprite: AnimatedSprite2D = $Sprite # 表示とアニメーションを担当するSprite。
@onready var state_machine: Node = $StateMachine # キャラクターの状態遷移を管理する。

# 現在位置をリスポーン位置として記録する。
func remember_spawn_position() -> void:
	spawn_position = global_position

# 空中にいる間だけ重力を加える。
func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

# 指定アニメーションが存在する時だけ再生する。
func play_animation(animation_name: StringName) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)

# 現在のアニメーションを止める。
func pause_animation() -> void:
	sprite.pause()

# 停止中のアニメーションを再開する。
func resume_animation() -> void:
	sprite.play()

# 針ヒット演出用の停止ポーズを作る。
func pose_spike_impact_hold(direction: Vector2) -> void:
	velocity = Vector2.ZERO
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"dead"):
		sprite.play(&"dead")
		var frame_count := sprite.sprite_frames.get_frame_count(&"dead")
		var hold_frame: int = mini(3, max(0, frame_count - 1))
		sprite.set_frame_and_progress(hold_frame, 0.0)
	sprite.pause()
	sprite.rotation = clamp(direction.x * 0.18, -0.18, 0.18)
	sprite.scale *= Vector2(0.92, 1.08)

# 現在の状態名を返す。
func current_state_name() -> StringName:
	if state_machine.current_state == null:
		return &""
	return state_machine.current_state.name
