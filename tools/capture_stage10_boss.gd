# 2026-06-22: Stage10のボスイントロとアリーナ確認画像を撮る。
extends SceneTree

const OUTPUT_DIR := "res://../../outputs/visual-checks/stage10"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed_scene: PackedScene = load("res://stage/Stage10.tscn")
	var scene: Node = packed_scene.instantiate()
	scene.boss_intro_enter_time = 0.05
	scene.boss_intro_hold_time = 10.0
	root.add_child(scene)
	await create_timer(0.18).timeout
	await _capture("01_boss_banner")
	scene.boss_intro.command_label.modulate.a = 1.0
	await _capture("02_boss_command")
	scene.boss_intro._finish()
	await create_timer(0.35).timeout
	await _capture("03_boss_arena")
	print("STAGE10_BOSS_CAPTURE_OK %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit(0)

func _capture(file_name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("%s.png" % file_name))
	assert(image.save_png(path) == OK)
