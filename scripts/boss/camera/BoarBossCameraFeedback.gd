# 2026-06-23: BoarのSMASH衝撃だけをStageカメラ演出へ接続する。
class_name BoarBossCameraFeedback
extends Node

signal shake_requested(strength: float, duration: float) # テストや他演出連携用に揺れ要求を通知する。

@export_range(0.0, 20.0, 0.5) var smash_shake_strength := 6.0 # SMASH衝撃時の揺れ幅。
@export_range(0.0, 0.5, 0.01) var smash_shake_duration := 0.10 # SMASH衝撃時の揺れ時間。

var stage: Node # カメラ演出を所有するStage10。

# StageとBossのSMASH衝撃イベントを接続する。
func setup(stage_node: Node, boss: Node) -> void:
	stage = stage_node
	if not boss.smash_impact_started.is_connected(_on_smash_impact_started):
		boss.smash_impact_started.connect(_on_smash_impact_started)

# 衝撃波判定が出た瞬間だけカメラを揺らす。
func _on_smash_impact_started(_request: RefCounted) -> void:
	shake_requested.emit(smash_shake_strength, smash_shake_duration)
	if stage != null and stage.has_method("shake_camera_while_paused"):
		stage.shake_camera_while_paused(smash_shake_strength, smash_shake_duration)
