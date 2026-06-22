# 2026-06-13: ゴール判定と編集時の見た目を管理する。
@tool
class_name GoalArea
extends Area2D

@export_group("Goal Hitbox")
@export var hitbox_size := Vector2(96, 56):
	set(value):
		hitbox_size = Vector2(max(value.x, 8.0), max(value.y, 8.0))
		_sync_children()

@export var hitbox_offset := Vector2.ZERO:
	set(value):
		hitbox_offset = value
		_sync_children()

@export_group("Goal Visual")
@export var label_text := "GOAL":
	set(value):
		label_text = value
		_sync_children()

@export var fill_color := Color(0.95, 0.76, 0.2, 0.45):
	set(value):
		fill_color = value
		queue_redraw()

@export var outline_color := Color(1.0, 0.92, 0.62, 0.95):
	set(value):
		outline_color = value
		queue_redraw()

@export var show_visual := true:
	set(value):
		show_visual = value
		_sync_children()


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	_sync_children()


func _draw() -> void:
	if not show_visual:
		return
	var rect := Rect2(hitbox_offset, hitbox_size)
	draw_rect(rect, fill_color, true)
	draw_rect(rect, outline_color, false, 2.0)


func get_hitbox_rect_global() -> Rect2:
	return Rect2(global_position + hitbox_offset, hitbox_size)


func _sync_children() -> void:
	queue_redraw()
	var shape_node := _get_collision_shape()
	if shape_node != null:
		var rectangle := shape_node.shape as RectangleShape2D
		if rectangle == null:
			rectangle = RectangleShape2D.new()
			shape_node.shape = rectangle
		rectangle.size = hitbox_size
		shape_node.position = hitbox_offset + hitbox_size * 0.5

	var label := _get_label()
	if label != null:
		label.visible = show_visual
		label.text = label_text
		label.offset_left = hitbox_offset.x
		label.offset_top = hitbox_offset.y + max(0.0, (hitbox_size.y - 32.0) * 0.5)
		label.offset_right = hitbox_offset.x + hitbox_size.x
		label.offset_bottom = label.offset_top + 32.0


func _get_collision_shape() -> CollisionShape2D:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null or not is_inside_tree():
		return shape_node

	shape_node = CollisionShape2D.new()
	shape_node.name = "CollisionShape2D"
	add_child(shape_node)
	_assign_editor_owner(shape_node)
	return shape_node


func _get_label() -> Label:
	var label := get_node_or_null("GoalLabel") as Label
	if label != null or not is_inside_tree():
		return label

	label = Label.new()
	label.name = "GoalLabel"
	label.z_index = 1
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1, 0.92, 0.62, 1))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)
	_assign_editor_owner(label)
	return label


func _assign_editor_owner(node: Node) -> void:
	if not Engine.is_editor_hint() or get_tree() == null:
		return
	var scene_root := get_tree().edited_scene_root
	if scene_root != null:
		node.owner = scene_root
