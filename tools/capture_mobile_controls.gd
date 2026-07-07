# 2026-07-07: スマホ操作UIを強制表示した確認画像を保存する。
extends SceneTree

const OUTPUT_DIR := "res://../../outputs/visual-checks/mobile_controls"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://stage/Stage1.tscn").instantiate()
	scene.mobile_controls_force_visible = true
	root.add_child(scene)
	await process_frame
	await process_frame
	await _capture("stage1_mobile_controls")
	scene.queue_free()
	await process_frame
	print("MOBILE_CONTROLS_CAPTURE_OK %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)

func _capture(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var image := root.get_texture().get_image()
	image.save_png("%s/%s.png" % [ProjectSettings.globalize_path(OUTPUT_DIR), name])
