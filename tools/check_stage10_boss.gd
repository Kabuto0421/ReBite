# 2026-06-22: Stage10のボスイントロと3ヒット耐久を確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed_scene: PackedScene = load("res://stage/Stage10.tscn")
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame

	var boss = scene.get_node("BoarBoss")
	assert(scene.boss == boss)
	assert(boss.scale == Vector2(1.5, 1.5))
	assert(boss.max_hits == 3)
	assert(boss.current_hits == 3)
	assert(boss.state_machine.states.has(&"BossHit"))
	assert(paused)
	assert(scene.boss_intro.title_label.text == "BOSS_BOAR")
	assert(scene.boss_intro.command_label.text == "ボスを倒せ！！")
	assert(scene.stage_hud.objective_label.text == "目標：ボスを倒す (0/3)")

	scene.boss_intro._finish()
	await _settle_frames(20)
	assert(not paused)
	assert(scene.stage_hud.stage_info_label.modulate.a > 0.99)
	assert(scene.stage_hud.objective_label.modulate.a > 0.99)

	boss.die()
	assert(boss.current_hits == 2)
	assert(boss.current_state_name() == &"BossHit")
	assert(scene.stage_hud.objective_label.text == "目標：ボスを倒す (1/3)")
	assert(not scene.stage_cleared)
	await _settle_frames(50)
	assert(boss.current_state_name() != &"BossHit")

	boss.die()
	assert(boss.current_hits == 1)
	assert(scene.stage_hud.objective_label.text == "目標：ボスを倒す (2/3)")
	assert(not scene.stage_cleared)
	await _settle_frames(50)
	assert(boss.current_state_name() != &"BossHit")

	boss.die()
	assert(boss.current_hits == 0)
	assert(boss.current_state_name() == &"Dying")
	assert(scene.stage_hud.objective_label.text == "目標：ボスを倒す (3/3)")
	await _settle_frames(110)
	assert(scene.stage_cleared)

	print("STAGE10_BOSS_CHECK_OK")
	root.remove_child(scene)
	scene.queue_free()
	await process_frame
	quit(0)

func _settle_frames(count: int) -> void:
	for i in count:
		await process_frame
		await physics_frame
