# 2026-07-07: Stage0の初期演出と練習タグ表示を画像確認する。
extends SceneTree

const OUTPUT_DIR := "res://../../outputs/visual-checks/stage0"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scene: Node = load("res://stage/Stage0.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await _capture("01_initial_demo")
	await create_timer(1.75).timeout
	await _capture("02_shadow_jump_demo")
	await create_timer(2.35).timeout
	await _capture("03_practice_tag")
	var target: TutorialSkullDropTarget = scene.get_node("PracticeSkullDropTarget")
	target.begin_committed_bite(scene.player, target.last_record)
	await create_timer(2.15).timeout
	await _capture("04_skull_drop_hole_closed")
	scene.final_scene_path = "res://stage/Stage0.tscn"
	scene.player.global_position = Vector2(1068, 362)
	scene._play_final_shadow_bite()
	await create_timer(0.82).timeout
	await _capture("05_final_dash")
	await create_timer(0.42).timeout
	await _capture("06_final_fall")
	await create_timer(0.22).timeout
	await _capture("07_final_camera_out")
	await create_timer(0.34).timeout
	await _capture("08_final_deep_fall")
	await create_timer(0.34).timeout
	await _capture("09_final_scream_hold")
	scene.queue_free()
	await process_frame
	print("STAGE0_CAPTURE_OK %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)

func _capture(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("%s.png" % file_name))
	assert(image.save_png(path) == OK)
