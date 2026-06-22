# 2026-06-13: 敵が針に刺さる瞬間演出の状態。
extends "res://scripts/core/State.gd"

var body: Node
var impact_position := Vector2.ZERO
var use_camera_impact := true
var hold_tween: Tween
var return_tween: Tween

func enter(payload: Variant = null) -> void:
	var data := payload as Dictionary
	if data == null:
		transition_requested.emit(&"Normal", null)
		return

	body = data.get("body") as Node
	impact_position = data.get("impact_position", Vector2.ZERO)
	use_camera_impact = data.get("use_camera_impact", true)
	if body == null or not is_instance_valid(body):
		transition_requested.emit(&"Normal", null)
		return

	owner_node.camera_cinematic = use_camera_impact
	owner_node.spike_impact_freeze_active = true
	owner_node.get_tree().paused = true
	owner_node.pose_spike_impact_body(body, impact_position)
	_start_impact_hold()

func exit() -> void:
	if hold_tween != null and hold_tween.is_valid():
		hold_tween.kill()
	if return_tween != null and return_tween.is_valid():
		return_tween.kill()
	hold_tween = null
	return_tween = null

func _start_impact_hold() -> void:
	var camera: Camera2D = owner_node.camera
	if use_camera_impact and camera == null:
		_finish_hold()
		return

	if use_camera_impact:
		var focus_position := _impact_focus_position()
		camera.global_position = focus_position
		camera.zoom = owner_node.camera_base_zoom * owner_node.spike_impact_zoom_multiplier
		owner_node.shake_camera(owner_node.spike_impact_shake_strength, 0.06)

	hold_tween = owner_node.create_spike_impact_tween()
	hold_tween.tween_interval(owner_node.spike_impact_hold_time)
	hold_tween.tween_callback(_finish_hold)

func _impact_focus_position() -> Vector2:
	if not is_instance_valid(body):
		return impact_position
	return impact_position.lerp(body.global_position, 0.55) + Vector2(0, -18)

func _finish_hold() -> void:
	owner_node.spawn_spike_impact_burst(impact_position)
	if is_instance_valid(body) and body.has_method("die"):
		body.die()
	owner_node.end_spike_impact_freeze()
	if use_camera_impact:
		owner_node.shake_camera(owner_node.spike_impact_aftershock_strength, 0.12)
		_start_camera_return()
	else:
		transition_requested.emit(&"Normal", null)

func _start_camera_return() -> void:
	return_tween = owner_node.create_tween()
	return_tween.set_trans(Tween.TRANS_QUART)
	return_tween.set_ease(Tween.EASE_OUT)
	return_tween.tween_interval(0.10)
	return_tween.tween_property(owner_node.camera, "zoom", owner_node.camera_base_zoom, 0.28)
	return_tween.tween_callback(func():
		transition_requested.emit(&"Normal", null)
	)
