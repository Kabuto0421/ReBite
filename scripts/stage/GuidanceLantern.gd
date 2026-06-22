# 2026-06-16:
# 8フレームで明滅しながら、左右に揺れる誘導用シアンランタン。

@tool
class_name GuidanceLantern
extends Node2D


const SHEET_PATH := "res://assets/guidance/guidance_lantern_cyan_8x32.png"
const FRAME_COUNT := 8
const FRAME_SIZE := Vector2i(32, 32)

# 元画像のフレームを再生する順番。
# 末尾でループして、1の次に0へ戻る。
const FRAME_ORDER := [
	0, 1, 2, 3, 4, 5, 6, 7,
	6, 5, 4, 3, 2, 1
]


# 点灯アニメーションを再生するかどうか。
@export var active := true:
	set(value):
		active = value
		_refresh()


# 明滅アニメーションの再生速度。
@export_range(0.0, 16.0, 0.1) var animation_fps := 8.0:
	set(value):
		animation_fps = value
		_refresh()


# アニメーション停止時に表示するフレーム。
@export_range(0, FRAME_COUNT - 1, 1) var editor_frame := 4:
	set(value):
		editor_frame = value
		_refresh()


# ランタン全体の透明度。
@export_range(0.0, 1.0, 0.01) var opacity := 0.9:
	set(value):
		opacity = value
		_refresh()


# ランタン画像の表示倍率。
@export var sprite_scale := Vector2.ONE:
	set(value):
		sprite_scale = value
		_refresh()


# 左右の揺れを有効にするかどうか。
@export var sway_enabled := true:
	set(value):
		sway_enabled = value
		_refresh()


# 左右に揺れる最大角度。
@export_range(0.0, 45.0, 0.1) var sway_angle := 8.0:
	set(value):
		sway_angle = value
		_refresh()


# 1秒間に何往復するか。
@export_range(0.0, 5.0, 0.01) var sway_speed := 0.4:
	set(value):
		sway_speed = value
		_refresh()


# 揺れに合わせて上下へ動かす量。
@export_range(0.0, 8.0, 0.1) var vertical_sway := 0.5:
	set(value):
		vertical_sway = value
		_refresh()


# ランタンのアニメーション表示。
var _sprite: AnimatedSprite2D

# 揺れの経過時間。
var _sway_time := 0.0


# エディタと実行時の表示を初期化する。
func _ready() -> void:
	_ensure_sprite()
	_rebuild_frames()
	_refresh()


# 毎フレーム、ランタンを左右に揺らす。
func _process(delta: float) -> void:
	if _sprite == null:
		return

	if not sway_enabled:
		_sprite.rotation = 0.0
		_sprite.position = Vector2.ZERO
		return

	_sway_time += delta

	var wave := _sway_time * TAU * sway_speed
	var angle_degrees := sin(wave) * sway_angle

	# ランタンを左右へ回転させる。
	_sprite.rotation = deg_to_rad(angle_degrees)

	# 揺れに合わせて、わずかに下方向へ動かす。
	_sprite.position.x = 0.0
	_sprite.position.y = abs(sin(wave)) * vertical_sway


# 子AnimatedSprite2Dを用意する。
func _ensure_sprite() -> void:
	if _sprite != null:
		return

	_sprite = get_node_or_null("Sprite") as AnimatedSprite2D

	if _sprite == null:
		_sprite = AnimatedSprite2D.new()
		_sprite.name = "Sprite"
		add_child(_sprite)


# スプライトシートから往復アニメーションを作る。
func _rebuild_frames() -> void:
	_ensure_sprite()

	var sheet := _load_texture(SHEET_PATH)

	if sheet == null:
		return

	var frames := SpriteFrames.new()

	frames.add_animation(&"pulse")
	frames.set_animation_loop(&"pulse", true)
	frames.set_animation_speed(&"pulse", animation_fps)

	# FRAME_ORDERで指定した順番にフレームを登録する。
	for source_frame_index in FRAME_ORDER:
		var atlas := AtlasTexture.new()

		atlas.atlas = sheet
		atlas.region = Rect2(
			Vector2(
				source_frame_index * FRAME_SIZE.x,
				0
			),
			Vector2(
				FRAME_SIZE.x,
				FRAME_SIZE.y
			)
		)

		frames.add_frame(&"pulse", atlas)

	_sprite.sprite_frames = frames
	_sprite.animation = &"pulse"


# 現在のInspector値を表示へ反映する。
func _refresh() -> void:
	if not is_inside_tree():
		return

	_ensure_sprite()

	if _sprite.sprite_frames == null:
		_rebuild_frames()
	elif _sprite.sprite_frames.has_animation(&"pulse"):
		_sprite.sprite_frames.set_animation_speed(
			&"pulse",
			animation_fps
		)

	# 色は変更せず、透明度だけを設定する。
	_sprite.modulate = Color(
		1.0,
		1.0,
		1.0,
		opacity
	)

	_sprite.scale = sprite_scale

	# 画像の上端中央付近を回転の支点にする。
	_sprite.centered = true
	_sprite.offset = Vector2(
		0.0,
		FRAME_SIZE.y * 0.5
	)

	if active:
		_sprite.play(&"pulse")
	else:
		_sprite.stop()

		# 停止時は元画像のeditor_frameを直接表示する。
		_sprite.frame = _find_animation_frame(editor_frame)

	if not sway_enabled:
		_sprite.rotation = 0.0
		_sprite.position = Vector2.ZERO


# 元画像のフレーム番号に対応する、

# 元画像のフレーム番号に対応する、
# アニメーション内の最初のフレーム番号を探す。
func _find_animation_frame(source_frame_index: int) -> int:
	var clamped_index: int = clampi(
		source_frame_index,
		0,
		FRAME_COUNT - 1
	)

	for animation_frame_index: int in FRAME_ORDER.size():
		if FRAME_ORDER[animation_frame_index] == clamped_index:
			return animation_frame_index

	return 0


# PNGをエディタでも読み込めるTextureへ変換する。
func _load_texture(path: String) -> Texture2D:
	var image := Image.new()

	var error := image.load(
		ProjectSettings.globalize_path(path)
	)

	if error != OK:
		push_error(
			"Failed to load image: %s" % path
		)
		return null

	return ImageTexture.create_from_image(image)
