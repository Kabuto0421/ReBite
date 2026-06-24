# 2026-06-23: Stage10の4種Impactが停止中に結果を保留し、解除後に続行することを確認する。
extends SceneTree

const ActionRecordScript := preload("res://scripts/core/ActionRecord.gd")

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
	var battle: Node = scene.boss_battle
	var feedback: Node = scene.boss_impact_feedback
	var rock: Node = scene.get_node("Gimmicks/RockA")
	var stopper: Node = scene.get_node("Gimmicks/StopperTrap")
	var falling: Node = scene.get_node("Gimmicks/FallingRockTrap")
	var wall: Node = scene.get_node("Gimmicks/FinalWall")
	boss.set_physics_process(false)

	# RockRecoveryへ進め、SMASH接触中は岩が移動しないことを確認する。
	battle._on_initial_trap_resolved(&"falling_rock", false, &"rock_a", {})
	battle._on_initial_trap_resolved(&"timed_drop", false, &"rock_b", {})
	var rock_home: Vector2 = rock.global_position
	var smash_record := ActionRecordScript.new(&"smash", rock.socket_offset.normalized(), Vector2.ZERO, 0.2, &"REBITE_REPLAY")
	assert(rock.receive_memory_action_push(boss, smash_record))
	assert(paused)
	assert(feedback.active_impact_id == &"rock_smash")
	assert(rock.global_position == rock_home)
	assert(feedback.active_contact_fx.texture.resource_path.ends_with("destruction_fx_05.png"))
	assert(feedback.active_contact_fx.modulate == feedback.smash_color)
	await _wait_for_impact_end(feedback, &"rock_smash")
	assert(not paused)
	assert(rock.socket_tween != null and rock.socket_tween.is_valid())

	# 移動完了時はSocket固定が別の短いImpactとして見える。
	for _frame in 30:
		if feedback.active_impact_id == &"socket_lock":
			break
		await process_frame
	assert(paused)
	assert(feedback.active_impact_id == &"socket_lock")
	assert(stopper.locked_rock == rock)
	assert(feedback.active_contact_fx.texture.resource_path.ends_with("destruction_fx_00.png"))
	assert(feedback.active_contact_fx.modulate == feedback.socket_color)
	await _wait_for_impact_end(feedback, &"socket_lock")
	assert(not paused)

	# 着地中はtrap_resolvedを保留し、解除後にだけ通知する。
	if falling.trap_resolved.is_connected(battle._on_initial_trap_resolved):
		falling.trap_resolved.disconnect(battle._on_initial_trap_resolved)
	var landing_results := [0]
	falling.trap_resolved.connect(func(_trap_id: StringName, _hit: bool, _rock_id: StringName, _event: Dictionary): landing_results[0] += 1)
	falling.rock_sprite.visible = true
	boss.global_position += Vector2(400, 0)
	falling._resolve_landing()
	assert(paused)
	assert(feedback.active_impact_id == &"rock_landing")
	assert(landing_results[0] == 0)
	assert(feedback.active_contact_fx.texture.resource_path.ends_with("destruction_fx_01.png"))
	assert(feedback.active_contact_fx.modulate == feedback.rock_color)
	await _wait_for_impact_end(feedback, &"rock_landing")
	assert(not paused)
	assert(landing_results[0] == 1)

	# 最終壁では接触中にHPを減らさず、解除後にダメージを確定する。
	wall.expose()
	var hp_before_wall: int = boss.current_hp
	var dash_record := ActionRecordScript.new(&"dash", Vector2.RIGHT, Vector2.ZERO, 0.2, &"REBITE_REPLAY")
	assert(wall.receive_memory_action_push(boss, dash_record))
	assert(paused)
	assert(feedback.active_impact_id == &"final_wall")
	assert(boss.current_hp == hp_before_wall)
	assert(feedback.active_contact_fx.texture.resource_path.ends_with("destruction_fx_05.png"))
	assert(feedback.active_contact_fx.modulate == feedback.wall_color)
	await _wait_for_impact_end(feedback, &"final_wall")
	assert(not paused)
	assert(boss.current_hp == hp_before_wall - 1)

	print("BOSS_IMPACT_FEEDBACK_CHECK_OK")
	scene.queue_free()
	await process_frame
	AudioServer.set_bus_mute(0, false)
	quit(0)

func _wait_for_impact_end(feedback: Node, impact_id: StringName) -> void:
	for _frame in 30:
		if feedback.active_impact_id != impact_id:
			return
		await process_frame
	assert(false, "Impact did not finish: %s" % impact_id)
