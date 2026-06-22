# 2026-06-13: 複数矩形で作れる通常タイル地形。
@tool
class_name EditableTileGroup
extends Node2D

const TileGroupBuilderScript := preload("res://scripts/stage/TileGroupBuilder.gd")

@export var tile_modulate := Color.WHITE # タイル表示色。

var _last_parts_hash := 0 # エディタ更新検知用の子矩形ハッシュ。

# エディタプレビューと実行時地形を準備する。
func _ready() -> void:
	_last_parts_hash = _parts_hash()
	queue_redraw()
	if not Engine.is_editor_hint():
		_build_runtime_tiles()

# エディタで矩形が変わったら再描画する。
func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and _last_parts_hash != _parts_hash():
		_last_parts_hash = _parts_hash()
		queue_redraw()

# エディタ上のタイル形状を描く。
func _draw() -> void:
	if Engine.is_editor_hint():
		TileGroupBuilderScript.draw_preview(self, get_tile_parts())

# 実行時の見た目と衝突を生成する。
func _build_runtime_tiles() -> void:
	var parts := get_tile_parts()
	TileGroupBuilderScript.build_static_collision(self, parts)
	TileGroupBuilderScript.build_visuals(self, parts, tile_modulate)

# 子TileRectPartから位置、サイズ、回転を保持した一覧を集める。
func get_tile_parts() -> Array:
	var parts: Array = []
	for child in get_children():
		if child.has_method("to_tile_part"):
			var part: Dictionary = child.to_tile_part()
			if TileGroupBuilderScript.is_valid_part(part):
				parts.append(part)
		elif child.has_method("to_rect"):
			var rect: Rect2 = child.to_rect()
			if TileGroupBuilderScript.is_valid_rect(rect):
				parts.append(rect)
	return parts

# 子TileRectPartからタイル矩形一覧を集める。
func get_tile_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for child in get_children():
		if child.has_method("to_rect"):
			var rect: Rect2 = child.to_rect()
			if rect.size.x > 0.0 and rect.size.y > 0.0:
				rects.append(rect)
	return rects

# 子矩形の状態をまとめてハッシュ化する。
func _parts_hash() -> int:
	var values: Array = []
	for child in get_children():
		if child.has_method("to_tile_part"):
			values.append(child.name)
			values.append(child.to_tile_part())
		elif child.has_method("to_rect"):
			values.append(child.name)
			values.append(child.to_rect())
	return hash(values)
