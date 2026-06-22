# 2026-06-13: ステージカメラの生成と演出を管理する。
class_name StageCameraRig
extends Node

var camera: Camera2D
var base_zoom := Vector2.ONE

func setup(stage: Node, initial_zoom: Vector2) -> void:
	base_zoom = initial_zoom
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.enabled = true
	camera.zoom = base_zoom
	stage.add_child(camera)

func follow_player(player: Node, offset: Vector2) -> void:
	if player != null and camera != null:
		camera.global_position = player.global_position + offset

func play_bite_focus(stage: Node, target: Node, on_finished: Callable) -> void:
	if camera == null:
		if on_finished.is_valid():
			on_finished.call()
		return
	var focus_position: Vector2 = target.global_position
	if target.has_method("memory_tag_global_position"):
		focus_position = target.memory_tag_global_position()

	var tween := stage.create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(camera, "global_position", focus_position + Vector2(20, 24), 0.22)
	tween.parallel().tween_property(camera, "zoom", Vector2(2.25, 2.25), 0.22)
	tween.tween_interval(0.50)
	tween.tween_property(camera, "zoom", base_zoom, 0.28)
	tween.tween_callback(on_finished)

func shake(stage: Node, strength: float, duration: float, use_pause_process: bool) -> void:
	if camera == null:
		return
	var tween := stage.create_tween()
	if use_pause_process:
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for i in 8:
		var offset := Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		tween.tween_property(camera, "offset", offset, duration / 8.0)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.04)

