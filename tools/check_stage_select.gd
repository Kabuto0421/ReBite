# 2026-07-07: ステージ選択画面がStage0からStage10まで扱うことを確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://stage/StageSelect.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	assert(scene.stage_paths.size() == 11)
	assert(scene.stage_paths[0].ends_with("Stage0.tscn"))
	assert(scene.stage_paths[9].ends_with("Stage9.tscn"))
	assert(scene.stage_paths[10].ends_with("Stage10.tscn"))
	assert(scene.boxes.size() == 11)
	assert(scene.boxes[0].position.y == scene.BOX_Y)
	assert(scene.boxes[5].position.y == scene.BOX_Y + scene.BOX_ROW_GAP)
	assert(scene.boxes[10].position.y == scene.BOX_Y + scene.BOX_ROW_GAP * 2.0)
	assert(scene.boxes[0].position.x == scene.boxes[5].position.x)
	assert(scene.boxes[4].position.x > scene.boxes[0].position.x)

	print("STAGE_SELECT_CHECK_OK")
	scene.queue_free()
	await process_frame
	quit(0)
