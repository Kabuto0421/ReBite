# 2026-06-23: SMASH衝撃時だけカメラが揺れ、DASHでは揺れないことを確認する。
extends SceneTree

const BossActionRequestScript := preload("res://scripts/boss/core/BossActionRequest.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	var scene: Node = load("res://stage/Stage10.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.boss_intro._finish()
	await process_frame
	var boss: Node = scene.boss
	var feedback: Node = scene.boss_camera_feedback
	var shake_count := [0]
	feedback.shake_requested.connect(func(_strength: float, _duration: float): shake_count[0] += 1)

	var smash_request := BossActionRequestScript.new(&"smash", Vector2.RIGHT, &"NATURAL", boss.global_position)
	boss.state_machine.change_state(&"SmashExecute", smash_request)
	var camera_moved := false
	for _frame in 24:
		await physics_frame
		camera_moved = camera_moved or scene.camera.offset.length() > 0.01
	assert(shake_count[0] == 1)
	assert(camera_moved)

	shake_count[0] = 0
	var dash_request := BossActionRequestScript.new(&"dash", Vector2.RIGHT, &"NATURAL", boss.global_position)
	boss.state_machine.change_state(&"DashExecute", dash_request)
	for _frame in 8:
		await physics_frame
	assert(shake_count[0] == 0)

	print("BOSS_SMASH_CAMERA_CHECK_OK")
	scene.queue_free()
	await process_frame
	AudioServer.set_bus_mute(0, false)
	quit(0)
