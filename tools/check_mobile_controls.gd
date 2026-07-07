# 2026-07-07: スマホ操作UIの構築と既存Input actionへの変換を確認する。
extends SceneTree

const MobileControlsScript := preload("res://scripts/ui/MobileControls.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var controls: Node = MobileControlsScript.new()
	controls.force_visible = true
	root.add_child(controls)
	await process_frame
	await process_frame

	assert(controls.visible)
	assert(controls.get_node("MovePadBase") is TextureRect)
	assert(controls.get_node("MovePadKnob") is TextureRect)
	assert(controls.get_node("JumpButton") is TextureButton)
	assert(controls.get_node("BiteButton") is TextureButton)
	assert(controls.get_node("ReplayButton") is TextureButton)

	controls._set_move_axis_from_position(controls.move_origin + Vector2(controls.move_radius, 0.0))
	controls._process(0.016)
	assert(Input.is_action_pressed("move_right"))
	assert(not Input.is_action_pressed("move_left"))

	controls._set_move_axis_from_position(controls.move_origin - Vector2(controls.move_radius, 0.0))
	controls._process(0.016)
	assert(Input.is_action_pressed("move_left"))
	assert(not Input.is_action_pressed("move_right"))

	controls.move_axis = 0.0
	controls._process(0.016)
	assert(not Input.is_action_pressed("move_left"))
	assert(not Input.is_action_pressed("move_right"))

	print("MOBILE_CONTROLS_CHECK_OK")
	controls.queue_free()
	await process_frame
	quit(0)
