# 2026-06-14: HopMonsterを足場にして上段からSkullMonsterを処理するステージ。
extends "res://scripts/stage/StageBase.gd"

func _build_world() -> void:
	var background := ColorRect.new()
	background.color = Color(0.052, 0.06, 0.082)
	background.size = Vector2(4200, 1800)
	background.position = Vector2(-1300, -620)
	background.z_index = -20
	add_child(background)
