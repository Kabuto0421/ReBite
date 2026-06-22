# 2026-06-13: ステージ内の敵一覧と撃破数を管理する。
class_name StageEnemyTracker
extends Node

signal enemy_defeated(defeated: int, total: int)
signal all_enemies_defeated

var enemies: Array[Node] = []
var defeated_enemies := 0

func setup(stage: Node) -> void:
	enemies.clear()
	defeated_enemies = 0
	for child in stage.get_children():
		if child.has_method("receive_bite") and child.has_signal("died"):
			enemies.append(child)
			if not child.died.is_connected(_on_enemy_died):
				child.died.connect(_on_enemy_died)

func first_enemy() -> Node:
	return enemies[0] if not enemies.is_empty() else null

func remaining_active_enemy_count() -> int:
	var count := 0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("current_state_name") and enemy.current_state_name() == &"Dying":
			continue
		count += 1
	return count

func _on_enemy_died() -> void:
	defeated_enemies += 1
	if defeated_enemies < enemies.size():
		enemy_defeated.emit(defeated_enemies, enemies.size())
		return
	all_enemies_defeated.emit()
