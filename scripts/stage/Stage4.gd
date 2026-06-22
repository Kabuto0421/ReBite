# 2026-06-13: HopMonsterを足場として使う縦移動ステージ。
extends "res://scripts/stage/StageBase.gd"

func _build_world() -> void:
	var background := ColorRect.new()
	background.color = Color(0.055, 0.064, 0.082)
	background.size = Vector2(3800, 4000)
	background.position = Vector2(-1300, -560)
	background.z_index = -20
	add_child(background)
