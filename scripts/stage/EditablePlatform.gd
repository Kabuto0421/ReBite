# 2026-06-13: ステージ編集用の足場ブロック。
@tool
class_name EditablePlatform
extends Node2D

const TileGroupBuilderScript := preload("res://scripts/stage/TileGroupBuilder.gd")

@export var size := Vector2(128, 32)

const TILE_SIZE := 32

var _last_size := Vector2.ZERO

func _ready() -> void:
	_last_size = size
	queue_redraw()
	if not Engine.is_editor_hint():
		_build_collision()
		_build_tiles()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and _last_size != size:
		_last_size = size
		queue_redraw()

func _draw() -> void:
	TileGroupBuilderScript.draw_preview(self, [Rect2(Vector2.ZERO, size)])

func _build_collision() -> void:
	TileGroupBuilderScript.build_static_collision(self, [Rect2(Vector2.ZERO, size)])

func _build_tiles() -> void:
	TileGroupBuilderScript.build_visuals(self, [Rect2(Vector2.ZERO, size)])
