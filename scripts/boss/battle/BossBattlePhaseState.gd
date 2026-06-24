# 2026-06-22: ボス戦のフェーズ開始をBattle基底へ通知する共通状態。
class_name BossBattlePhaseState
extends "res://scripts/core/State.gd"

@export var phase_id: StringName # ボス戦が識別するフェーズID。

# フェーズへ入ったことをボス戦管理へ通知する。
func enter(payload: Variant = null) -> void:
	owner_node.on_phase_entered(phase_id, payload)
