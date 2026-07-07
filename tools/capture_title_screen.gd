# 2026-07-06: タイトル画面の配置確認用スクリーンショットを保存する。
extends SceneTree

const OUTPUT_DIR := "res://../../outputs/visual-checks/title_screen"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scene: Node = load("res://stage/TitleScreen.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await _capture("01_title_default")
	scene.selected_index = 1
	scene._update_selection(false)
	await process_frame
	await _capture("02_title_settings_selected")
	scene._open_settings_panel()
	await process_frame
	await _capture("03_title_settings_panel")
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	print("TITLE_SCREEN_CAPTURE_OK %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)

func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("%s.png" % file_name))
	assert(image.save_png(path) == OK)
