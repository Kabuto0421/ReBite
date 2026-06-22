# 2026-06-13: Stage2の確認画像を撮る。
extends SceneTree

const OUTPUT_DIR := "res://../../outputs/visual-checks/stage2"
const STAGE_SCENE := "res://stage/Stage2.tscn"

var scene: Node

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_prepare_output_dir()
	var packed_scene: PackedScene = load(STAGE_SCENE)
	scene = packed_scene.instantiate()
	root.add_child(scene)

	await _settle_frames(12)
	scene.camera_cinematic = true
	scene.camera.global_position = Vector2(600, 260)
	scene.camera.zoom = Vector2(1.0, 1.0)
	await _settle_frames(3)
	await _capture("01_stage2_wall_layout")

	var skull = scene.get_node("SkullMonster")
	skull.commit_dash_record(Vector2.RIGHT)
	skull.state_machine.change_state(&"Recover", null)
	await _settle_frames(8)
	scene.camera.global_position = Vector2(600, 260)
	scene.camera.zoom = Vector2(1.0, 1.0)
	await _settle_frames(3)
	await _capture("02_stage2_right_tag_window")

	print("STAGE2_CAPTURE_OK %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	if scene != null:
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

func _settle_frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame

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
