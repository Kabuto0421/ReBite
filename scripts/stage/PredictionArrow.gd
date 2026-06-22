# 2026-06-13: 記憶行動の予測矢印を描画する。
class_name PredictionArrow
extends Node2D

var start_position: Vector2 = Vector2.ZERO
var end_position: Vector2 = Vector2.ZERO
var arrow_color: Color = Color(1.0, 0.76, 0.24, 0.9)

func show_path(from: Vector2, to: Vector2) -> void:
	start_position = from
	end_position = to
	visible = true
	queue_redraw()

func hide_path() -> void:
	visible = false

func _draw() -> void:
	if not visible:
		return
	var delta: Vector2 = end_position - start_position
	if delta.length() < 8.0:
		return

	var direction: Vector2 = delta.normalized()
	var normal: Vector2 = Vector2(-direction.y, direction.x)
	var length: float = delta.length()
	var dash_count: int = max(3, int(length / 28.0))
	for i in dash_count:
		var t0: float = float(i) / float(dash_count)
		var t1: float = min(t0 + 0.55 / float(dash_count), 1.0)
		var p0: Vector2 = start_position.lerp(end_position, t0)
		var p1: Vector2 = start_position.lerp(end_position, t1)
		draw_line(p0, p1, arrow_color, 4.0)
		draw_line(p0 + Vector2(0, 2), p1 + Vector2(0, 2), Color(0.08, 0.04, 0.12, 0.75), 2.0)

	var tip: Vector2 = end_position
	var wing_a: Vector2 = tip - direction * 18.0 + normal * 10.0
	var wing_b: Vector2 = tip - direction * 18.0 - normal * 10.0
	draw_colored_polygon(PackedVector2Array([tip, wing_a, wing_b]), arrow_color)
	draw_line(wing_a, wing_b, Color(0.08, 0.04, 0.12, 0.85), 2.0)
