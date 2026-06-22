# 2026-06-22: 開始命令と常駐目標HUDの確認画像を撮る。
extends SceneTree

const OUTPUT_DIR := "res://../../outputs/visual-checks/stage_briefing"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scene := await _load_stage("res://stage/Stage2.tscn", 10.0)
	await _capture("01_center_command")
	scene.stage_hud.briefing_overlay.visible = false
	scene.stage_hud.stage_info_label.modulate.a = 1.0
	scene.stage_hud.objective_label.modulate.a = 1.0
	await process_frame
	await _capture("02_persistent_hud")
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	print("STAGE_BRIEFING_CAPTURE_OK %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)

func _load_stage(path: String, hold_time: float) -> Node:
	var packed_scene: PackedScene = load(path)
	var scene: Node = packed_scene.instantiate()
	scene.stage_briefing_hold_time = hold_time
	root.add_child(scene)
	await process_frame
	return scene

func _capture(file_name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("%s.png" % file_name))
	assert(image.save_png(path) == OK)
