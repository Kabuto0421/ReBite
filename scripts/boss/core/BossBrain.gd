# 2026-06-22: 主人公との距離からBossBoarの次攻撃を選ぶ。
class_name BossBrain
extends Node

const BossActionRequestScript := preload("res://scripts/boss/core/BossActionRequest.gd")

@export var smash_range := 150.0 # この距離以内ならSMASHを選ぶ。

var boss: Node # 行動するBossBoar。
var player: Node # 狙うPlayer。

# 判断対象を設定する。
func setup(owner_boss: Node, target_player: Node) -> void:
	boss = owner_boss
	player = target_player

# 現在距離から通常攻撃要求を作る。
func choose_action() -> RefCounted:
	if boss == null or player == null:
		return BossActionRequestScript.new(&"dash", Vector2.LEFT)
	var delta: Vector2 = player.global_position - boss.global_position
	var direction := Vector2.RIGHT if delta.x > 0.0 else Vector2.LEFT
	var action_id: StringName = &"smash" if absf(delta.x) <= smash_range else &"dash"
	return BossActionRequestScript.new(action_id, direction, &"NATURAL", player.global_position)
