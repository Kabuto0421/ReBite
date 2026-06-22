# 2026-06-13: HopMonsterで動かす乗れる足場。
@tool
class_name RidePlatform
extends AnimatableBody2D

const TileGroupBuilderScript := preload("res://scripts/stage/TileGroupBuilder.gd")

@export var target_path: NodePath
@export var offset := Vector2(-64, -92)
@export var size := Vector2(128, 24)

const TILE_SIZE := 32

var _target: Node2D
var _last_size := Vector2.ZERO

func _ready() -> void:
	_last_size = size
	queue_redraw()
	if not Engine.is_editor_hint():
		_target = get_node_or_null(target_path) as Node2D
		sync_to_physics = true
		_build_collision()
		_build_tiles()
		_follow_target()

func _physics_process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		_follow_target()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and _last_size != size:
		_last_size = size
		queue_redraw()

func _draw() -> void:
	TileGroupBuilderScript.draw_preview(self, [Rect2(Vector2.ZERO, size)], Color(0.24, 0.19, 0.42), Color(0.72, 0.46, 0.9))

func _follow_target() -> void:
	if _target == null:
		return
	global_position = _target.global_position + offset

func _build_collision() -> void:
	var shape_node := CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	shape_node.position = size * 0.5
	add_child(shape_node)

func _build_tiles() -> void:
	TileGroupBuilderScript.build_visuals(self, [Rect2(Vector2.ZERO, size)], Color(0.92, 0.74, 1.0))
