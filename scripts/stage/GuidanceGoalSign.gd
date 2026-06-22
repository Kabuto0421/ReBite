# 2026-06-16: 背景に薄く置けるGOAL方向サイン。
@tool
class_name GuidanceGoalSign
extends Node2D

enum SignType { UP, RIGHT, LEFT, DOWN }

const TEXTURE_PATHS := {
	SignType.UP: "res://assets/guidance/goal_sign_up.png",
	SignType.RIGHT: "res://assets/guidance/goal_sign_right.png",
	SignType.LEFT: "res://assets/guidance/goal_sign_left.png",
	SignType.DOWN: "res://assets/guidance/goal_sign_down.png",
}

@export var sign_type := SignType.UP: # 表示するGOALサインの種類。
	set(value):
		sign_type = value
		_refresh()
@export_range(0.0, 1.0, 0.01) var opacity := 1.0: # サイン全体の透明度。
	set(value):
		opacity = value
		_refresh()
@export var sprite_scale := Vector2.ONE: # サイン画像の表示倍率。
	set(value):
		sprite_scale = value
		_refresh()

var _sprite: Sprite2D # 実際にサイン画像を表示するSprite。

# エディタと実行時の表示を初期化する。
func _ready() -> void:
	_ensure_sprite()
	_refresh()

# 子Spriteを用意する。
func _ensure_sprite() -> void:
	if _sprite != null:
		return
	_sprite = get_node_or_null("Sprite") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		add_child(_sprite)

# 現在のInspector値を表示へ反映する。
func _refresh() -> void:
	if not is_inside_tree():
		return
	_ensure_sprite()
	_sprite.texture = _load_texture(TEXTURE_PATHS.get(sign_type, TEXTURE_PATHS[SignType.UP]))
	_sprite.modulate = Color(1.0, 1.0, 1.0, opacity)
	_sprite.scale = sprite_scale

# PNGをエディタでも読み込めるTextureへ変換する。
func _load_texture(path: String) -> Texture2D:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Failed to load image: %s" % path)
		return null
	return ImageTexture.create_from_image(image)
