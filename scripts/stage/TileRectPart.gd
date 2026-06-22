# 2026-06-13: タイルグループ内の1矩形を表す編集用ノード。
@tool
class_name TileRectPart
extends Node2D

@export var rect_name := "Rect" # 矩形の用途や名前。
@export var size := Vector2.ZERO # この矩形の幅と高さ。
@export var preview_color := Color(0.33, 0.13, 0.45, 0.72) # エディタ上のプレビュー色。

var _last_size := Vector2.ZERO # エディタ更新検知用のサイズ。
var _last_color := Color.TRANSPARENT # エディタ更新検知用の色。
var _last_rotation := 0.0 # エディタ更新検知用の回転角度。

# エディタ上で初期プレビューを表示する。
func _ready() -> void:
	_last_size = size
	_last_color = preview_color
	_last_rotation = rotation
	queue_redraw()

# エディタで値が変わったら再描画する。
func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if _last_size != size or _last_color != preview_color or not is_equal_approx(_last_rotation, rotation):
		_last_size = size
		_last_color = preview_color
		_last_rotation = rotation
		queue_redraw()
		if get_parent() is CanvasItem:
			(get_parent() as CanvasItem).queue_redraw()

# この子ノードから親グループ用のRect2を作る。
func to_rect() -> Rect2:
	return Rect2(position, size)

# 位置、サイズ、回転を保持したタイル生成用データを返す。
func to_tile_part() -> Dictionary:
	return {
		"name": rect_name,
		"position": position,
		"size": size,
		"rotation": rotation,
	}

# 2Dビュー上に矩形プレビューを描く。
func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), preview_color, true)
	draw_rect(Rect2(Vector2.ZERO, size).grow(-2.0), Color(1.0, 0.82, 0.55), false, 2.0)
