# 2026-06-13: 通常カメラの追従位置を確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed_scene: PackedScene = load("res://stage/Stage1.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await _settle_frames(3)

	var expected_position: Vector2 = scene.player.global_position + scene.normal_camera_offset
	assert(scene.camera.global_position.distance_to(expected_position) < 0.01)

	print("NORMAL_CAMERA_OFFSET_CHECK_OK")
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit(0)

func _settle_frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame
