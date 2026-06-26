# 2026-06-13: プレイヤーの空中操作状態。
extends "res://scripts/core/State.gd"

func enter(_payload: Variant = null) -> void:
	owner_node.play_animation(&"walk")

func physics_update(delta: float) -> void:
	owner_node.apply_gravity(delta)
	owner_node.apply_air_horizontal_input(delta)
	var landing_speed: float = owner_node.velocity.y
	owner_node.move_and_slide()

	if owner_node.is_on_floor():
		owner_node.refresh_coyote_window()
		owner_node.play_landing_feedback(landing_speed)
		if not owner_node.try_consume_buffered_jump():
			transition_requested.emit(&"Ground", null)

func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		owner_node.buffer_jump()
		owner_node.try_consume_buffered_jump()
	elif event.is_action_pressed("bite"):
		transition_requested.emit(&"BiteWindup", owner_node.prepare_bite_context())
