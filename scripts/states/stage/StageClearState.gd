# 2026-07-07: ステージクリア後のリザルト表示と選択入力を扱う状態。
extends "res://scripts/core/State.gd"

# リザルトUIを表示する。
func enter(payload: Variant = null) -> void:
	owner_node.show_stage_result(payload if payload is Dictionary else {})

# リザルトUIを閉じる。
func exit() -> void:
	owner_node.hide_stage_result()

# REPLAY/NEXT選択入力をStageへ渡す。
func handle_input(event: InputEvent) -> void:
	owner_node.handle_stage_result_input(event)
