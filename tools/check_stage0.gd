# 2026-07-07: Stage0のチュートリアル構成が生成されることを確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://stage/Stage0.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	assert(scene.stage_display_name == "STAGE 0")
	assert(scene.final_scene_path == "res://stage/Stage1.tscn")
	assert(scene.bgm_path == "res://assets/bgm/rebite_shadow_bite.ogg")
	assert(scene.get_node("Player") is Player)
	assert(scene.get_node("PracticeSkullDropTarget") is TutorialSkullDropTarget)
	assert(scene.get_node("PracticeGate") != null)
	assert(scene.get_node_or_null("PracticeHoleCover") == null)
	assert(scene.get_node("FinalShadowTrigger") is Area2D)
	assert(scene.get_node("ShadowGuide") is ShadowGuide)

	var target: TutorialSkullDropTarget = scene.get_node("PracticeSkullDropTarget")
	target.set_available(true)
	assert(target.is_biteable())
	assert(target.last_record.action_name == &"dash")
	assert(target.last_record.direction == Vector2.RIGHT)
	assert(absf(scene.get_node("Player").global_position.y - 362.0) < 0.1)
	assert(absf(target.global_position.y - 360.0) < 0.1)

	print("STAGE0_CHECK_OK")
	scene.queue_free()
	await process_frame
	quit(0)
