# 2026-06-13: 複数SkullMonsterの連鎖ステージ。
extends "res://scripts/stage/StageBase.gd"

func _build_world() -> void:
	var background := ColorRect.new()
	background.color = Color(0.07, 0.075, 0.09)
	background.size = Vector2(3800, 1500)
	background.position = Vector2(-1300, -560)
	background.z_index = -20
	add_child(background)
