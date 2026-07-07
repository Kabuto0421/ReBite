# 2026-07-07: BoarにSMASH記憶を作らせるための視覚ターゲット。
class_name TauntStake
extends Node2D

@export var enabled := true # 将来の検知処理で有効な標的として扱うか。

# Boar向けの標的グループへ登録する。
func _ready() -> void:
	add_to_group(&"taunt_stake")
