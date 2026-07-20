# 2026-07-21: クリア後リザルトのK噛み選択フローを確認する。
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://stage/Stage1.tscn") as PackedScene
	var stage := packed.instantiate()
	root.add_child(stage)
	await process_frame

	stage.complete_stage("STAGE CLEAR")
	await create_timer(0.25).timeout
	assert(stage.stage_result_layer != null)
	assert(stage.stage_result_choices.size() == 2)
	assert(stage.stage_result_selected_index == 1)

	var replay_event := InputEventAction.new()
	replay_event.action = &"replay"
	replay_event.pressed = true
	stage.handle_stage_result_input(replay_event)
	await process_frame
	assert(stage.stage_result_layer != null)
	assert(not stage.stage_result_moving)

	var move_left_event := InputEventAction.new()
	move_left_event.action = &"move_left"
	move_left_event.pressed = true
	stage.handle_stage_result_input(move_left_event)
	await process_frame
	assert(stage.stage_result_selected_index == 0)

	var bite_event := InputEventAction.new()
	bite_event.action = &"bite"
	bite_event.pressed = true
	stage.handle_stage_result_input(bite_event)
	await process_frame
	assert(stage.stage_result_moving)

	print("STAGE_RESULT_FLOW_CHECK_OK")
	stage.queue_free()
	await process_frame
	quit(0)
