# 2026-06-13: 針ヒット演出の確認画像を撮る。
extends SceneTree

const OUTPUT_DIR := "res://../../outputs/visual-checks/spike-impact"

var scene: Node
var enemy: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_prepare_output_dir()
	var packed_scene: PackedScene = load("res://stage/Stage1.tscn")
	scene = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	enemy = scene.get_node("SkullMonster")
	scene.camera.global_position = enemy.global_position + Vector2(80, -64)
	scene.camera.zoom = scene.camera_base_zoom
	scene.camera_cinematic = true
	await _capture("01_before_impact")

	var impact_position := Vector2(466, 330)
	enemy.global_position = impact_position + Vector2(0, 28)
	scene.handle_spike_body_entered(enemy, impact_position)
	await _settle_seconds(scene.spike_impact_hold_time * 0.5)
	await _capture("02_stab_hold")
	await _settle_seconds(scene.spike_impact_hold_time * 0.5 + 0.03)
	await _capture("03_death_burst")
	await _settle_seconds(0.18)
	await _capture("04_impact_aftershock")

	print("SPIKE_IMPACT_CAPTURE_OK %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit(0)

func _prepare_output_dir() -> void:
	var absolute_dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	for file_name in DirAccess.get_files_at(absolute_dir):
		if file_name.ends_with(".png"):
			DirAccess.remove_absolute(absolute_dir.path_join(file_name))

func _settle_seconds(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout

func _capture(name: String) -> void:
	await process_frame
	var texture := root.get_texture()
	if texture == null:
		push_error("Viewport texture is unavailable. Run this capture script without --headless.")
		quit(1)
		return
	var image := texture.get_image()
	if image == null:
		push_error("Viewport image is unavailable. Run this capture script without --headless.")
		quit(1)
		return
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("%s.png" % name))
	var error := image.save_png(path)
	if error != OK:
		push_error("Failed to save capture: %s" % path)
