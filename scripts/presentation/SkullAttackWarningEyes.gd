# 2026-06-23: SkullMonsterの攻撃予告中だけ眼窩位置へ赤い両目を表示する。
class_name SkullAttackWarningEyes
extends Node2D

const IDLE_EYE_CENTERS := [
	Vector2(-0.5, -5.0),
	Vector2(3.5, -5.0),
	Vector2(1.5, -4.0),
	Vector2(-2.5, -5.0),
] # Idle各フレームの両眼中央位置。

const TELEGRAPH_EYE_CENTERS := [
	Vector2(-5.5, -8.0),
] # Telegraph静止フレームの両眼中央位置。

const DASH_EYE_CENTERS := [
	Vector2(-0.5, -5.0),
	Vector2(-0.5, -6.0),
	Vector2(-5.5, -8.0),
	Vector2(0.5, -3.0),
] # DASH各フレームの両眼中央位置。

@export var eye_spacing := 9.0 # 左右の目の中心間隔。
@export var eye_size := Vector2(2.0, 2.0) # 赤い中心ピクセルの大きさ。
@export var glow_color := Color(1.0, 0.08, 0.04, 0.28) # 目の周囲へ重ねる赤い光。
@export var core_color := Color(1.0, 0.18, 0.08, 1.0) # 目の中心色。

var pulse_tween: Tween # 発光の明滅を繰り返すTween。

# 初期状態では発光を隠す。
func _ready() -> void:
	visible = false
	var animated_sprite := get_parent() as AnimatedSprite2D
	if animated_sprite != null and not animated_sprite.frame_changed.is_connected(_sync_to_frame):
		animated_sprite.frame_changed.connect(_sync_to_frame)
	if animated_sprite != null and not animated_sprite.animation_changed.is_connected(_sync_to_frame):
		animated_sprite.animation_changed.connect(_sync_to_frame)
	_sync_to_frame()
	queue_redraw()

# 攻撃予告に合わせて発光を開始・終了する。
func set_active(active: bool) -> void:
	if active == visible:
		return
	_kill_pulse()
	visible = active
	modulate = Color.WHITE
	scale = Vector2.ONE
	if not active:
		return
	_sync_to_frame()
	pulse_tween = create_tween().set_loops()
	pulse_tween.set_trans(Tween.TRANS_SINE)
	pulse_tween.set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(self, "modulate", Color(1.0, 0.52, 0.42, 0.72), 0.08)
	pulse_tween.parallel().tween_property(self, "scale", Vector2.ONE * 1.12, 0.08)
	pulse_tween.tween_property(self, "modulate", Color.WHITE, 0.08)
	pulse_tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.08)

# 左右の眼窩へ四角い赤目と小さな光を描く。
func _draw() -> void:
	for direction in [-1.0, 1.0]:
		var center := Vector2(direction * eye_spacing * 0.5, 0.0)
		draw_rect(Rect2(center - Vector2(2.0, 1.5), Vector2(4.0, 3.0)), glow_color)
		draw_rect(Rect2(center - eye_size * 0.5, eye_size), core_color)

# Idleアニメーションの頭部移動へ赤目を追従させる。
func _sync_to_frame() -> void:
	var animated_sprite := get_parent() as AnimatedSprite2D
	if animated_sprite == null:
		return
	var centers: Array = IDLE_EYE_CENTERS
	if animated_sprite.animation == &"telegraph":
		centers = TELEGRAPH_EYE_CENTERS
	elif animated_sprite.animation == &"dash":
		centers = DASH_EYE_CENTERS
	elif animated_sprite.animation != &"idle":
		return
	var frame_index: int = clampi(animated_sprite.frame, 0, centers.size() - 1)
	var center: Vector2 = centers[frame_index]
	center.x *= -1.0 if animated_sprite.flip_h else 1.0
	position = center

# Spriteの左右反転直後に眼窩位置を再計算する。
func sync_to_sprite() -> void:
	_sync_to_frame()

# 既存の明滅Tweenを停止する。
func _kill_pulse() -> void:
	if pulse_tween != null and pulse_tween.is_valid():
		pulse_tween.kill()
	pulse_tween = null
