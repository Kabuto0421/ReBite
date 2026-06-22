# 2026-06-22: 開始命令と常駐目標HUDの切り替えを確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	await _check_defeat_stage("res://stage/Stage1.tscn", "敵を倒せ！", "目標：敵を倒す (0/1)")
	await _check_defeat_stage("res://stage/Stage2.tscn", "敵を全員倒せ！", "目標：敵を全員倒す (0/3)")
	await _check_goal_stage()
	print("STAGE_BRIEFING_HUD_CHECK_OK")
	quit(0)

func _check_defeat_stage(path: String, command: String, objective: String) -> void:
	var scene := await _load_stage(path)
	var hud = scene.stage_hud
	assert(hud.briefing_overlay.visible)
	assert(hud.briefing_command_label.text == command)
	assert(hud.objective_label.text == objective)
	assert(is_equal_approx(hud.objective_label.modulate.a, 0.0))
	await _settle_seconds(scene.stage_briefing_hold_time + scene.stage_briefing_transition_time + 0.2)
	assert(not hud.briefing_overlay.visible)
	assert(hud.stage_info_label.modulate.a > 0.99)
	assert(hud.objective_label.modulate.a > 0.99)
	await _remove_stage(scene)

func _check_goal_stage() -> void:
	var scene := await _load_stage("res://stage/Stage4.tscn")
	var hud = scene.stage_hud
	assert(hud.briefing_command_label.text == "ゴールしろ！")
	assert(hud.objective_label.text == "目標：ゴールに到達する")
	scene._on_all_enemies_defeated()
	assert(not scene.stage_cleared)
	await _remove_stage(scene)

func _load_stage(path: String) -> Node:
	var packed_scene: PackedScene = load(path)
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	await process_frame
	return scene

func _remove_stage(scene: Node) -> void:
	root.remove_child(scene)
	scene.queue_free()
	await process_frame

func _settle_seconds(seconds: float) -> void:
	await create_timer(seconds).timeout
