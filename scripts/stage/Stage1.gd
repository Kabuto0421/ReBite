# 2026-06-13: Stage1の地形と初期ステージ構成。
extends "res://scripts/stage/StageBase.gd"

func _build_world() -> void:
	var background := ColorRect.new()
	background.color = Color(0.07, 0.075, 0.09)
	background.size = Vector2(3600, 1400)
	background.position = Vector2(-1200, -520)
	background.z_index = -20
	add_child(background)

	_add_spikes(Rect2(430, 328, 72, 32))
