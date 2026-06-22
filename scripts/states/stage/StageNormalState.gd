# 2026-06-13: 通常時のステージカメラ追従状態。
extends "res://scripts/core/State.gd"

func enter(_payload: Variant = null) -> void:
	owner_node.camera_cinematic = false
	owner_node.spike_impact_freeze_active = false

func process_update(_delta: float) -> void:
	if owner_node.player != null and owner_node.camera != null:
		owner_node.camera.global_position = owner_node.player.global_position + owner_node.normal_camera_offset
