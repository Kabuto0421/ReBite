# 2026-06-13: HopMonsterの跳躍開始速度を確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed_scene: PackedScene = load("res://stage/Stage4.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	await physics_frame

	var hop = scene.get_node("HopMonster")
	hop.state_machine.change_state(&"Hop", null)
	await physics_frame
	assert(hop.velocity.y == hop.last_record.velocity.y)

	hop.state_machine.change_state(&"Recover", null)
	hop.commit_hop_record()
	await _settle_frames(2)
	var record = hop.last_record
	hop.state_machine.change_state(&"Recalled", record)
	await _settle_seconds(hop.recall_start_delay + 0.02)
	assert(hop.velocity.y == record.velocity.y)

	print("HOP_LAUNCH_VELOCITY_CHECK_OK")
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit(0)

func _settle_frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame

func _settle_seconds(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await process_frame
		await physics_frame
		elapsed += 1.0 / 60.0
