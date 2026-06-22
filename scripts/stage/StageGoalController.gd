# 2026-06-13: GoalAreaによるステージクリア判定を管理する。
class_name StageGoalController
extends Node

signal goal_reached # プレイヤーが有効な状態でゴールに入った時に通知する。

var goal_area: Area2D # 監視対象のゴール領域。
var player: Node # ゴール判定対象のプレイヤー。

# ゴール領域を探して接触イベントを接続する。
func setup(stage: Node, goal_area_path: NodePath, target_player: Node) -> Area2D:
	player = target_player
	goal_area = stage.get_node_or_null(goal_area_path) as Area2D
	if goal_area != null and not goal_area.body_entered.is_connected(_on_goal_body_entered):
		goal_area.body_entered.connect(_on_goal_body_entered)
	return goal_area

# すでに重なっている場合のゴール判定を確認する。
func process_update(stage_cleared: bool) -> void:
	if goal_area == null or player == null or stage_cleared:
		return
	for body in goal_area.get_overlapping_bodies():
		_try_complete_goal(body)

# GoalArea接触時の判定入口。
func _on_goal_body_entered(body: Node) -> void:
	_try_complete_goal(body)

# プレイヤーが噛み演出中でなければゴール到達を通知する。
func _try_complete_goal(body: Node) -> void:
	if body != player:
		return
	if player.has_method("set_bite_invulnerable") and player.bite_invulnerable:
		return
	goal_reached.emit()
