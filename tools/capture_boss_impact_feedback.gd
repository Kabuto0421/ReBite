# 2026-06-23: Stage10の4種Impact停止フレームを画像確認する。
extends SceneTree

const OUTPUT_DIR := "res://../../outputs/visual-checks/stage10"
const ActionRecordScript := preload("res://scripts/core/ActionRecord.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	AudioServer.set_bus_mute(0, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var scene: Node = load("res://stage/Stage10.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.boss_intro._finish()
	await process_frame
	var boss: Node = scene.boss
	var battle: Node = scene.boss_battle
	var feedback: Node = scene.boss_impact_feedback
	var rock: Node = scene.get_node("Gimmicks/RockA")
	var stopper: Node = scene.get_node("Gimmicks/StopperTrap")
	var falling: Node = scene.get_node("Gimmicks/FallingRockTrap")
	var wall: Node = scene.get_node("Gimmicks/FinalWall")
	boss.set_physics_process(false)
	battle._on_initial_trap_resolved(&"falling_rock", false, &"rock_a", {})
	battle._on_initial_trap_resolved(&"timed_drop", false, &"rock_b", {})

	var smash_record := ActionRecordScript.new(&"smash", rock.socket_offset.normalized(), Vector2.ZERO, 0.2, &"REBITE_REPLAY")
	rock.receive_memory_action_push(boss, smash_record)
	await _capture("08_rock_smash_impact")
	await _wait_for_impact_end(feedback, &"rock_smash")
	for _frame in 30:
		if feedback.active_impact_id == &"socket_lock":
			break
		await process_frame
	await _capture("09_socket_lock_impact")
	await _wait_for_impact_end(feedback, &"socket_lock")

	if falling.trap_resolved.is_connected(battle._on_initial_trap_resolved):
		falling.trap_resolved.disconnect(battle._on_initial_trap_resolved)
	falling.rock_sprite.visible = true
	falling.rock_sprite.position += falling.landing_offset
	boss.global_position += Vector2(400, 0)
	falling._resolve_landing()
	await _capture("10_rock_landing_impact")
	await _wait_for_impact_end(feedback, &"rock_landing")

	wall.expose()
	var dash_record := ActionRecordScript.new(&"dash", Vector2.RIGHT, Vector2.ZERO, 0.2, &"REBITE_REPLAY")
	wall.receive_memory_action_push(boss, dash_record)
	await _capture("11_final_wall_impact")
	await _wait_for_impact_end(feedback, &"final_wall")

	print("BOSS_IMPACT_CAPTURE_OK %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	scene.queue_free()
	await process_frame
	AudioServer.set_bus_mute(0, false)
	quit(0)

func _capture(file_name: String) -> void:
	await process_frame
	var image := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUTPUT_DIR.path_join("%s.png" % file_name))
	assert(image.save_png(path) == OK)

func _wait_for_impact_end(feedback: Node, impact_id: StringName) -> void:
	for _frame in 30:
		if feedback.active_impact_id != impact_id:
			return
		await process_frame
